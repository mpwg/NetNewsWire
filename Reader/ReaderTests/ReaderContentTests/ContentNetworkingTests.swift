import Foundation
import Synchronization
import Testing
import ReaderContent
import ReaderDomain

struct ContentNetworkingTests {
    @Test("HTTP 403 remains an explicit full-text error") func http403RemainsAnExplicitFullTextError() async throws {
        let fixture = try ContentNetworkFixture()
        await fixture.server.setResponse(status: 403, data: Data("Access denied".utf8))
        await #expect(throws: ReaderError.server(403)) { try await fixture.service.extract(url: fixture.url) }
        #expect(await fixture.server.requestCount == 1)
    }

    @Test("Network timeouts propagate to the caller") func networkTimeoutsPropagateToTheCaller() async throws {
        let fixture = try ContentNetworkFixture()
        await fixture.server.setTimeout()
        let error = await #expect(throws: URLError.self) { try await fixture.service.extract(url: fixture.url) }
        #expect(error?.code == .timedOut)
        #expect(await fixture.server.requestCount == 1)
    }

    @Test("The same URL returns updated content after a source change") func theSameURLReturnsUpdatedContentAfterASourceChange() async throws {
        let fixture = try ContentNetworkFixture()
        await fixture.server.setResponse(status: 200, data: Self.article(marker: "Initial offer version"))
        let first = try await fixture.service.extract(url: fixture.url)
        await fixture.server.setResponse(status: 200, data: Self.article(marker: "Updated offer version"))
        let second = try await fixture.service.extract(url: fixture.url)
        #expect(first.text.contains("Initial offer version"))
        #expect(second.text.contains("Updated offer version"))
        #expect(!second.text.contains("Initial offer version"))
        #expect(first != second)
        #expect(await fixture.server.requestCount == 2)
    }

    @Test("Extracted full text resolves relative links against the document URL") func extractedFullTextResolvesRelativeLinksAgainstTheDocumentURL() async throws {
        let fixture = try ContentNetworkFixture()
        await fixture.server.setResponse(status: 200, data: Self.article(marker: "Austrian offers"))
        let result = try await fixture.service.extract(url: fixture.url)
        let expectedLink = try #require(URL(string: "/offers/reader", relativeTo: fixture.url)?.absoluteURL.absoluteString)
        #expect(result.html.contains(expectedLink))
        #expect(result.text.contains("View offer"))
    }

    @Test("Oversized HTML responses are rejected before extraction") func oversizedHTMLResponsesAreRejectedBeforeExtraction() async throws {
        let fixture = try ContentNetworkFixture()
        await fixture.server.setResponse(status: 200, data: Data(repeating: 120, count: 4_000_001))
        await #expect(throws: ReaderError.invalidResponse) { try await fixture.service.extract(url: fixture.url) }
        #expect(await fixture.server.requestCount == 1)
    }

    private static func article(marker: String) -> Data {
        let text = String(repeating: "\(marker): Fresh apples cost EUR 2.99 at the retailer today. ", count: 50)
        return Data("<html><head><title>\(marker)</title></head><body><article><h1>\(marker)</h1><p>\(text)</p><p><a href='/offers/reader'>View offer</a></p></article></body></html>".utf8)
    }
}

private final class ContentNetworkFixture: @unchecked Sendable {
    let server = ContentScriptServer()
    let service: ArticleContentService
    let url: URL
    private let host: String
    private let session: URLSession

    init() throws {
        host = UUID().uuidString.lowercased() + ".test"
        url = try #require(URL(string: "https://" + host + "/2026/10/beitrag"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ContentScriptURLProtocol.self]
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
        service = ArticleContentService(session: session)
        let server = server
        ContentScriptURLProtocol.register(host: host) { request in try await server.respond(request) }
    }

    deinit {
        session.invalidateAndCancel()
        ContentScriptURLProtocol.unregister(host: host)
    }
}

private struct ContentScriptResponse: Sendable {
    let status: Int
    let data: Data
}

private actor ContentScriptServer {
    private var response = ContentScriptResponse(status: 200, data: Data())
    private var timeout = false
    var requestCount = 0

    func setResponse(status: Int, data: Data) {
        response = ContentScriptResponse(status: status, data: data)
        timeout = false
    }

    func setTimeout() { timeout = true }

    func respond(_ request: URLRequest) throws -> ContentScriptResponse {
        requestCount += 1
        if timeout { throw URLError(.timedOut) }
        return response
    }
}

private final class ContentScriptURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async throws -> ContentScriptResponse
    private static let handlers = Mutex<[String: Handler]>([:])
    private let runningTask = Mutex<Task<Void, Never>?>(nil)

    static func register(host: String, handler: @escaping Handler) { handlers.withLock { $0[host] = handler } }
    static func unregister(host: String) { handlers.withLock { $0[host] = nil } }
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handler = Self.handlers.withLock { $0[request.url?.host ?? ""] }
        let request = request
        let task = Task {
            do {
                guard let handler, let url = request.url else { throw ReaderError.invalidResponse }
                let result = try await handler(request)
                try Task.checkCancellation()
                guard let response = HTTPURLResponse(url: url, statusCode: result.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/html; charset=utf-8", "Content-Length": String(result.data.count)]) else {
                    throw ReaderError.invalidResponse
                }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: result.data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
        runningTask.withLock { $0 = task }
    }

    override func stopLoading() { runningTask.withLock { $0?.cancel(); $0 = nil } }
}

struct ContentStreamingTests {
    enum Rejection: CaseIterable, Sendable { case forbidden, declaredOversized, unknownOversized, underreportedOversized }

    @Test("Rejected headers and streamed overflow cancel before the server finishes",
          .timeLimit(.minutes(1)), arguments: Rejection.allCases)
    func rejectedDownloadsEndBeforeServerCompletion(rejection: Rejection) async throws {
        let graph = try await exerciseRejection(rejection)
        #expect(try await waitUntil { graph.released })
    }

    @Test("An exactly four-million-byte streamed article remains extractable", .timeLimit(.minutes(1)))
    func exactStreamedLimitRemainsExtractable() async throws {
        let fixture = try ContentStreamFixture(rejection: nil)
        await fixture.plan.headerGate.open()
        await fixture.plan.endGate.open()
        let result = try await fixture.service.extract(url: fixture.url)
        #expect(result.text.contains("An article at the exact download limit"))
        #expect(fixture.plan.progress.withLock { $0.bytes } == 4_000_000)
        #expect(fixture.plan.progress.withLock { $0.finished })
    }

    @Test("Cancelling a bounded request releases headers and partial-body waits",
          .timeLimit(.minutes(1)), arguments: [false, true])
    func cancellationEndsBeforeServerCompletion(afterBody: Bool) async throws {
        let graph = try await exerciseCancellation(afterBody: afterBody)
        #expect(try await waitUntil { graph.released })
    }

    private func exerciseCancellation(afterBody: Bool) async throws -> WeakContentStreamGraph {
        let fixture = try ContentStreamFixture(rejection: nil)
        let graph = WeakContentStreamGraph(fixture)
        let completed = Mutex(false)
        let request = Task { [service = fixture.service, url = fixture.url] in
            let result: Result<ExtractedContent, any Error>
            do { result = .success(try await service.extract(url: url)) } catch { result = .failure(error) }
            completed.withLock { $0 = true }
            return result
        }
        defer { request.cancel(); Task { await fixture.plan.headerGate.open(); await fixture.plan.endGate.open() } }
        if afterBody {
            await fixture.plan.headerGate.open()
            try await fixture.plan.endGate.waitUntilEntered()
        } else { try await fixture.plan.headerGate.waitUntilEntered() }
        #expect(fixture.plan.progress.withLock { $0.bytes } == (afterBody ? 4_000_000 : 0))
        request.cancel()
        try #require(try await waitUntil { completed.withLock { $0 } })
        let result = await request.value
        #expect(throws: CancellationError.self) { try result.get() }
        #expect(try await waitUntil { fixture.plan.progress.withLock { $0.stopped } })
        #expect(!fixture.plan.progress.withLock { $0.finished })
        return graph
    }

    private func exerciseRejection(_ rejection: Rejection) async throws -> WeakContentStreamGraph {
        let fixture = try ContentStreamFixture(rejection: rejection)
        let graph = WeakContentStreamGraph(fixture)
        let completed = Mutex(false)
        let request = Task { [service = fixture.service, url = fixture.url] in
            let result: Result<ExtractedContent, any Error>
            do { result = .success(try await service.extract(url: url)) } catch { result = .failure(error) }
            completed.withLock { $0 = true }
            return result
        }
        defer { request.cancel(); Task { await fixture.plan.headerGate.open(); await fixture.plan.endGate.open() } }
        if rejection == .forbidden || rejection == .declaredOversized {
            try await fixture.plan.headerGate.waitUntilEntered()
        } else {
            await fixture.plan.headerGate.open()
            try await fixture.plan.endGate.waitUntilEntered()
            #expect(fixture.plan.progress.withLock { $0.bytes } == 4_000_001)
        }
        try #require(try await waitUntil { completed.withLock { $0 } }, "Download must settle while the server's completion gate stays closed.")
        let result = await request.value
        let expected: ReaderError = rejection == .forbidden ? .server(403) : .invalidResponse
        #expect(throws: expected) { try result.get() }
        #expect(try await waitUntil { fixture.plan.progress.withLock { $0.stopped } })
        #expect(!fixture.plan.progress.withLock { $0.finished })
        return graph
    }

    private func waitUntil(_ condition: () -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition() {
            if ContinuousClock.now >= deadline { return false }
            try await Task.sleep(for: .milliseconds(10))
        }
        return true
    }
}

private final class ContentStreamFixture: Sendable {
    let plan: ContentStreamPlan
    let service: ArticleContentService
    let session: URLSession
    let url: URL

    init(rejection: ContentStreamingTests.Rejection?) throws {
        url = try #require(URL(string: "https://" + UUID().uuidString.lowercased() + ".content-stream.test/article"))
        plan = ContentStreamPlan(rejection: rejection)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ContentStreamURLProtocol.self]
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
        service = ArticleContentService(session: session)
        ContentStreamURLProtocol.plans.withLock { $0[url.absoluteString] = plan }
    }

    deinit {
        session.invalidateAndCancel()
        ContentStreamURLProtocol.plans.withLock { $0[url.absoluteString] = nil }
    }
}

private final class ContentStreamPlan: Sendable {
    struct Progress { var bytes = 0; var stopped = false; var finished = false }
    let progress = Mutex(Progress())
    let headerGate = RequestGate()
    let endGate = RequestGate()
    let status: Int
    let headers: [String: String]
    let chunks: [Data]

    init(rejection: ContentStreamingTests.Rejection?) {
        status = rejection == .forbidden ? 403 : 200
        var headers = ["Content-Type": "text/html; charset=utf-8"]
        if rejection == .declaredOversized { headers["Content-Length"] = "4000001" }
        if rejection == .underreportedOversized { headers["Content-Length"] = "4000000" }
        self.headers = headers
        if rejection == .forbidden || rejection == .declaredOversized {
            chunks = []
        } else if rejection != nil {
            chunks = Array(repeating: Data(repeating: 120, count: 1_000_000), count: 4) + [Data([120])]
        } else {
            var article = Data("<html><body><article><p>An article at the exact download limit remains readable.</p></article></body></html>".utf8)
            article.append(Data(repeating: 32, count: 4_000_000 - article.count))
            chunks = stride(from: 0, to: article.count, by: 1_000_000).map { article.subdata(in: $0..<min($0 + 1_000_000, article.count)) }
        }
    }
}

private final class ContentStreamURLProtocol: URLProtocol, @unchecked Sendable {
    static let plans = Mutex<[String: ContentStreamPlan]>([:])
    private struct State { var task: Task<Void, Never>?; var plan: ContentStreamPlan?; var stopped = false }
    private let state = Mutex(State())

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let plan = Self.plans.withLock({ $0[url.absoluteString] }) else {
            client?.urlProtocol(self, didFailWithError: ReaderError.invalidResponse)
            return
        }
        state.withLock { $0.plan = plan }
        let task = Task { @Sendable [self, plan, url] in
            do {
                let response = try #require(HTTPURLResponse(url: url, statusCode: plan.status, httpVersion: "HTTP/1.1", headerFields: plan.headers))
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                try await plan.headerGate.pause()
                for chunk in plan.chunks {
                    try Task.checkCancellation()
                    client?.urlProtocol(self, didLoad: chunk)
                    plan.progress.withLock { $0.bytes += chunk.count }
                }
                try await plan.endGate.pause()
                try Task.checkCancellation()
                plan.progress.withLock { $0.finished = true }
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
        state.withLock { if $0.stopped { task.cancel() } else { $0.task = task } }
    }

    override func stopLoading() {
        let owned = state.withLock { value in
            value.stopped = true
            let owned = (value.task, value.plan)
            value.task = nil; value.plan = nil
            return owned
        }
        owned.1?.progress.withLock { $0.stopped = true }
        owned.0?.cancel()
    }
}

private final class WeakContentStreamGraph {
    weak var service: ArticleContentService?
    weak var session: URLSession?
    weak var plan: ContentStreamPlan?
    init(_ fixture: ContentStreamFixture) { service = fixture.service; session = fixture.session; plan = fixture.plan }
    var released: Bool { service == nil && session == nil && plan == nil }
}
