import Foundation
import Network
import WebKit
import Synchronization
import Testing
import ReaderDomain
@testable import ReaderContent
@testable import ReaderUI

struct HTMLParsingTests {
    @Test("Ordinary HTML5 void elements and browser recovery preserve article content",
          .timeLimit(.minutes(1)), arguments: [0, 1, 2, 3, 4])
    func ordinaryHTML5FormsRemainReadable(kind: Int) async throws {
        let marker = String(repeating: "Native HTML article remains readable. ", count: 40)
        let heading = "<h1>Caf&eacute; costs &euro;2.99</h1>"
        let link = "<a href='../offer'>View offer</a>"
        let html: String
        switch kind {
        case 0:
            html = "<html><head><meta charset=utf-8><link rel=stylesheet href='reader-resource://blocked/style'></head><body><input disabled><article>" +
                heading + "<p>" + marker + link + "<br>Final line<img src='reader-resource://blocked/image' alt='Illustration'></p></article></body></html>"
        case 1:
            html = "<html><body><article>" + heading + "<p>" + marker + link + "<p>Second paragraph<br>Final line<table><tr><td>Table cell"
        case 2:
            html = "<article>" + heading + "<p>" + marker + link + "</p></article>"
        case 3:
            html = "<article data-note='a > b'>" + heading + "<p class=story>" + marker + "<a href=../offer>View offer</a></p></article>"
        default:
            html = "<article>" + heading + "<p>" + marker + "<b><i>Nested content</b> still readable</i>" + link + "</article>"
        }
        let result = try await ArticleContentService().extract(html: html, baseURL: #require(URL(string: "https://html.reader.invalid/articles/source")))
        #expect(result.text.contains("Native HTML article remains readable."))
        #expect(result.text.contains("Café"))
        #expect(result.text.contains("€2.99"))
        #expect(result.html.contains("https://html.reader.invalid/offer"))
    }
}

@MainActor
struct HTMLIsolationTests {
    @Test("Extraction page scripts stay disabled without relying on CSP", .timeLimit(.minutes(1)))
    func pageScriptsStayDisabledWithoutCSP() async throws {
        var configuration = WebPage.Configuration()
        configuration.defaultNavigationPreferences.allowsContentJavaScript = true
        let page = ArticleHTMLParser.makePage(configuration: configuration)
        defer { page.stopLoading() }
        for try await _ in page.load(html: "<body><p>Saved content</p><script>document.body.dataset.executed='yes'</script></body>") { }
        let executed = try await page.callJavaScript("return document.body.dataset.executed || 'no';") as? String
        #expect(executed == "no")
    }

    @Test("Inert extraction blocks resources and preserves the trusted source base", .timeLimit(.minutes(1)))
    func resourcesStayBlockedAndBaseStaysTrusted() async throws {
        let resources = HTMLResourceTrap()
        var configuration = WebPage.Configuration()
        configuration.urlSchemeHandlers[try #require(URLScheme("reader-resource"))] = resources
        let control = WebPage(configuration: configuration)
        for try await _ in control.load(html: "<body><img src=\"reader-resource://control/image\"></body>") { }
        #expect(resources.requests.withLock { $0.contains("reader-resource://control/image") }, "The unrestricted native resource handler must load the control image.")
        control.stopLoading()
        resources.requests.withLock { $0.removeAll() }
        let page = ArticleHTMLParser.makePage(configuration: configuration)
        defer { page.stopLoading() }
        for try await _ in page.load(html: "<body><img src=\"reader-resource://blocked/raw-image\"></body>") { }
        #expect(resources.requests.withLock { $0.isEmpty }, Comment(rawValue: "Unexpected raw resource requests: " + resources.requests.withLock { $0.joined(separator: ", ") }))
        let marker = String(repeating: "Isolated native article remains readable. ", count: 40)
        let html = """
        <html><head><base href="reader-resource://untrusted/">
        <link rel="stylesheet" href="reader-resource://blocked/style">
        <style>@import url("reader-resource://blocked/import"); body { background:url("reader-resource://blocked/background") }</style>
        <script src="reader-resource://blocked/script"></script>
        <meta http-equiv="refresh" content="0;url=reader-resource://blocked/refresh"></head><body>
        <script>document.body.dataset.executed='yes'</script>
        <article><h1>Isolated article</h1><p>\(marker)<a href="../offer">View offer</a></p>
        <img src="reader-resource://blocked/image" onerror="document.body.dataset.executed='yes'">
        <video src="reader-resource://blocked/video"></video>
        <iframe src="reader-resource://blocked/frame"></iframe>
        <object data="reader-resource://blocked/object"></object>
        <form action="reader-resource://blocked/form"><input autofocus></form>
        </article></body></html>
        """
        let result = try await ArticleHTMLParser.parse(html: html, baseURL: #require(URL(string: "https://isolated.reader.invalid/articles/source")),
                                                       readability: ArticleHTMLParser.readabilitySource(), page: page)
        #expect(result.text.contains("Isolated native article remains readable."))
        #expect(result.html.contains("https://isolated.reader.invalid/offer"))
        #expect(resources.requests.withLock { $0.isEmpty })
        let executed = try await page.callJavaScript("return document.body.dataset.executed || 'no';") as? String
        #expect(executed == "no")
    }

    @Test("The extraction navigation policy rejects an otherwise loadable external request", .timeLimit(.minutes(1)))
    func externalNavigationCannotLeaveTheLocalDocument() async throws {
        let resources = HTMLResourceTrap()
        var configuration = WebPage.Configuration()
        configuration.urlSchemeHandlers[try #require(URLScheme("reader-resource"))] = resources
        let decisions = HTMLNavigationEvents()
        configuration.websiteDataStore = .nonPersistent()
        let page = WebPage(configuration: configuration, navigationDecider: ObservedArticleNavigation(events: decisions))
        defer { page.stopLoading() }
        for try await _ in page.load(html: "<body><p>Local initial document</p></body>") { }
        let url = try #require(URL(string: "reader-resource://outside/document"))
        let navigation = Task {
            do { for try await _ in page.load(URLRequest(url: url)) { } } catch { }
        }
        defer { navigation.cancel(); page.stopLoading() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while decisions.policies.withLock({ $0[url.absoluteString] }) == nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(decisions.policies.withLock { $0[url.absoluteString] } == WKNavigationActionPolicy.cancel.rawValue)
        #expect(resources.requests.withLock { $0.isEmpty })
        let text = try await page.callJavaScript("return document.body.textContent;") as? String
        #expect(text == "Local initial document")
    }
}

@MainActor
struct HTMLLifetimeTests {
    enum Outcome: CaseIterable, Sendable { case success, empty, cancelledBeforeLoad, cancelledDuringNavigation }

    @Test("Native extraction pages release after outcomes and cancelled loading", .timeLimit(.minutes(1)), arguments: Outcome.allCases)
    func nativeExtractionGraphsRelease(outcome: Outcome) async throws {
        let graph = try await exercise(outcome)
        #expect(try await waitUntil { graph.released })
    }

    private func exercise(_ outcome: Outcome) async throws -> WeakHTMLGraph {
        let gate = RequestGate()
        let resources = HTMLResourceTrap()
        var configuration = WebPage.Configuration()
        configuration.urlSchemeHandlers[try #require(URLScheme("reader-resource"))] = resources
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultNavigationPreferences.allowsContentJavaScript = false
        let page = outcome == .cancelledDuringNavigation
            ? WebPage(configuration: configuration, navigationDecider: HeldArticleNavigation(gate: gate))
            : ArticleHTMLParser.makePage(configuration: configuration)
        let graph = WeakHTMLGraph(page: page, resources: resources, gate: gate)
        let completed = HTMLCompletion()
        let html = outcome == .empty ? "<html><body></body></html>" :
            "<article><p>" + String(repeating: "Native lifetime article remains readable. ", count: 40) + "</p></article>"
        let request = Task {
            do {
                let result = try await ArticleHTMLParser.parse(html: html, baseURL: #require(URL(string: "https://lifetime.reader.invalid/source")),
                                                               readability: ArticleHTMLParser.readabilitySource(), page: page)
                completed.result = .success(result)
            } catch { completed.result = .failure(error) }
        }
        defer { request.cancel(); page.stopLoading(); Task { await gate.open() } }
        if outcome == .cancelledBeforeLoad { request.cancel() }
        if outcome == .cancelledDuringNavigation {
            try await gate.waitUntilEntered()
            request.cancel()
            let ended = try await waitUntil { completed.result != nil }
            #expect(ended, "Cancellation must return before the native navigation decision gate opens.")
            if !ended { await gate.open() }
        }
        await request.value
        let result = try #require(completed.result)
        switch outcome {
        case .success: #expect(try result.get().text.contains("Native lifetime article remains readable."))
        case .empty:
            #expect { try result.get() } throws: { error in
                guard let error = error as? ReaderError, case .unavailable = error else { return false }
                return true
            }
        case .cancelledBeforeLoad, .cancelledDuringNavigation:
            #expect(throws: CancellationError.self) { try result.get() }
        }
        #expect(resources.requests.withLock { $0.isEmpty })
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

private final class HTMLResourceTrap: URLSchemeHandler, Sendable {
    let requests = Mutex<[String]>([])
    func reply(for request: URLRequest) -> AsyncThrowingStream<URLSchemeTaskResult, any Error> {
        requests.withLock { $0.append(request.url?.absoluteString ?? "") }
        return AsyncThrowingStream { continuation in
            guard let url = request.url else { continuation.finish(throwing: ReaderError.invalidURL); return }
            let data = Data("<html><body><p>Escaped external document</p></body></html>".utf8)
            continuation.yield(.response(URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8")))
            continuation.yield(.data(data))
            continuation.finish()
        }
    }
}

private final class HTMLNavigationEvents: Sendable {
    let policies = Mutex<[String: Int]>([:])
}

private struct ObservedArticleNavigation: WebPage.NavigationDeciding {
    let events: HTMLNavigationEvents
    @MainActor
    func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        let policy = await ReaderWebNavigationPolicy().decidePolicy(for: action, preferences: &preferences)
        events.policies.withLock { $0[action.request.url?.absoluteString ?? ""] = policy.rawValue }
        return policy
    }
}

private struct HeldArticleNavigation: WebPage.NavigationDeciding {
    let gate: RequestGate
    @MainActor
    func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        do { try await gate.pause() } catch { return .cancel }
        return await ReaderWebNavigationPolicy().decidePolicy(for: action, preferences: &preferences)
    }
}

@MainActor
private final class HTMLCompletion { var result: Result<ExtractedContent, any Error>? }

@MainActor
private final class WeakHTMLGraph {
    weak var page: WebPage?
    weak var resources: HTMLResourceTrap?
    weak var gate: RequestGate?
    init(page: WebPage, resources: HTMLResourceTrap, gate: RequestGate) { self.page = page; self.resources = resources; self.gate = gate }
    var released: Bool { page == nil && resources == nil && gate == nil }
}

@MainActor
struct HTMLHTTPIsolationTests {
    @Test("The real HTTP transport downloads only the document while all article subresources remain blocked", .timeLimit(.minutes(1)))
    func extractionRequestsOnlyTheHTMLDocument() async throws {
        let server = try HTMLHTTPServer()
        defer { server.stop() }
        let base = try await server.start()
        let control = WebPage()
        defer { control.stopLoading() }
        for try await _ in control.load(html: "<img src='" + base.appendingPathComponent("image").absoluteString + "'>") { }
        #expect(server.paths.withLock { $0 == ["/image"] }, "An unrestricted WebKit page must reach this actual HTTP server.")
        server.paths.withLock { $0.removeAll() }
        let result = try await ArticleContentService().extract(url: base.appendingPathComponent("article"))
        #expect(result.text.contains("Only the downloaded HTML supplies the article."))
        #expect(server.paths.withLock { $0 == ["/article"] }, Comment(rawValue: server.paths.withLock { $0.joined(separator: ", ") }))
        #expect(!result.html.contains("<img"))
        #expect(!result.html.contains("<style"))
        #expect(!result.html.contains("<script"))
        let display = ReaderArticleDocument.makePage()
        defer { display.stopLoading() }
        let raw = "<h1>Saved article</h1><style>@import url('" + base.appendingPathComponent("style").absoluteString +
            "');</style><img src='" + base.appendingPathComponent("image").absoluteString +
            "'><iframe src='" + base.appendingPathComponent("frame").absoluteString + "'></iframe>"
        let article = ArticleSnapshot(id: ArticleKey(accountID: UUID(), remoteID: "http-fixture"), feedID: "feed",
                                      title: "Saved HTTP article", html: raw, url: base.appendingPathComponent("article"))
        try await ReaderArticleDocument.load(article, into: display)
        #expect(try await display.callJavaScript("return document.body.textContent;") as? String == "Saved article")
        #expect(server.paths.withLock { $0 == ["/article"] })
    }

    @Test("HTTP redirects remain document-only and redirect loops stop after five hops", .timeLimit(.minutes(1)),
          arguments: [false, true])
    func boundedHTTPRedirects(loop: Bool) async throws {
        let server = try HTMLHTTPServer()
        defer { server.stop() }
        let base = try await server.start()
        let service = ArticleContentService()
        if loop {
            await #expect(throws: ReaderError.invalidResponse) { try await service.extract(url: base.appendingPathComponent("loop")) }
            #expect(server.paths.withLock { $0 == Array(repeating: "/loop", count: 6) })
        } else {
            let result = try await service.extract(url: base.appendingPathComponent("redirect"))
            #expect(result.text.contains("Only the downloaded HTML supplies the article."))
            #expect(server.paths.withLock { $0 == ["/redirect", "/article"] })
        }
    }
}

private final class HTMLHTTPServer: Sendable {
    let paths = Mutex<[String]>([])
    private let listener: NWListener
    private let connections = Mutex<[NWConnection]>([])
    private let queue = DispatchQueue(label: "Reader.HTMLHTTPIsolation")
    private let failure = Mutex<String?>(nil)
    private let ready = Mutex(false)

    init() throws { listener = try NWListener(using: .tcp, on: .any) }

    func start() async throws -> URL {
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state { self?.failure.withLock { $0 = error.localizedDescription } }
            if case .ready = state { self?.ready.withLock { $0 = true } }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.start(queue: queue)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !ready.withLock({ $0 }) {
            if let error = failure.withLock({ $0 }) { throw ReaderError.unavailable(error) }
            guard ContinuousClock.now < deadline else { throw URLError(.timedOut) }
            try await Task.sleep(for: .milliseconds(10))
        }
        let port = try #require(listener.port)
        return try #require(URL(string: "http://127.0.0.1:" + String(port.rawValue)))
    }

    func stop() {
        listener.cancel()
        connections.withLock { values in values.forEach { $0.cancel() }; values.removeAll() }
    }

    private func accept(_ connection: NWConnection) {
        connections.withLock { $0.append(connection) }
        connection.start(queue: queue)
        receive(connection, accumulated: Data())
    }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            var request = accumulated
            if let data { request.append(data) }
            guard request.count <= 32_768, error == nil else { connection.cancel(); return }
            if let text = String(data: request, encoding: .utf8), text.contains("\r\n\r\n") {
                let path = text.components(separatedBy: " ").dropFirst().first ?? "/"
                self.paths.withLock { $0.append(path) }
                self.respond(connection, path: path)
            } else if !complete { self.receive(connection, accumulated: request) } else { connection.cancel() }
        }
    }

    private func respond(_ connection: NWConnection, path: String) {
        if path == "/redirect" || path == "/loop" {
            let destination = path == "/loop" ? "/loop" : "/article"
            let response = Data("HTTP/1.1 302 Found\r\nLocation: \(destination)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)
            connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
            return
        }
        let body: Data
        let mime: String
        if path == "/image" {
            body = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a0uoAAAAASUVORK5CYII=")!
            mime = "image/png"
        } else {
            let marker = String(repeating: "Only the downloaded HTML supplies the article. ", count: 40)
            body = Data("""
            <html><head><meta charset=utf-8><link rel=stylesheet href='/style'>
            <style>@import url('/import');body{background:url('/background')}</style><script src='/script'></script></head>
            <body><article><h1>HTTP isolation</h1><p>\(marker)</p><img src='/image' alt='Blocked illustration'>
            <iframe src='/frame'></iframe><video autoplay src='/media'></video><object data='/object'></object></article></body></html>
            """.utf8)
            mime = "text/html; charset=utf-8"
        }
        var response = Data("HTTP/1.1 200 OK\r\nContent-Type: \(mime)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }
}
