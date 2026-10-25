import Foundation
import CoreGraphics
import ImageIO
import Synchronization
import Testing
import ReaderDomain
@testable import ReaderSync

struct IconServiceTests {
    @Test("Icon candidates preserve relative paths and are scoped to each homepage") func iconCandidatesPreserveRelativePathsAndAreScopedToEachHomepage() throws {
        let base = try #require(URL(string: "https://example.test/news/index"))
        let html = "<link rel='shortcut icon' href='../favicon.png?v=1&amp;s=2'><link rel='stylesheet' href='bad.css'><link rel='ICON' href='https://cdn.test/icon.png'>"
        #expect(IconService.iconCandidates(in: html, relativeTo: base).map(\.absoluteString) == [
            "https://example.test/favicon.png?v=1&s=2", "https://cdn.test/icon.png"
        ])
    }

    @Test("Metadata stops at head boundaries and ignores inert markup", arguments: [
        "<head><link rel='icon' href='/head.png'></head><link rel='icon' href='/body.png'>",
        "<link rel='icon' href='/head.png'><BoDy><link rel='icon' href='/body.png'>",
        "<head><!-- <body><link rel='icon' href='/comment.png'> --><script><body><link rel='icon' href='/script.png'></script><link rel='icon' href='/head.png'></head>",
        "<head><style>/* <body><link rel='icon' href='/style.png'> */</style><link rel='icon' href='/head.png'></head>",
        "<head><link data-note='>' rel='icon' href='/head.png'></head>",
        "<head><template><template><link rel='icon' href='/nested.png'></template><body><link rel='icon' href='/template.png'></template><link rel='icon' href='/head.png'></head>",
        "<head><link rel='icon' href='/head.png'><div><link rel='icon' href='/implicit-body.png'>",
        "<head><link rel='icon' href='/head.png'>Body text<link rel='icon' href='/implicit-body.png'>",
        "<head><noframes><body><link rel='icon' href='/fallback-markup.png'></noframes><link rel='icon' href='/head.png'></head>"
    ])
    func metadataStopsAtHeadBoundariesAndIgnoresInertMarkup(html: String) throws {
        let base = try #require(URL(string: "https://example.test/news"))
        #expect(IconService.iconCandidates(in: html, relativeTo: base).map(\.absoluteString) == ["https://example.test/head.png"])
    }

    @Test("Homepage failures do not prevent independent favicon fallback") func homepageFailuresDoNotPreventIndependentFaviconFallback() async throws {
        let fixture = try IconFixture()
        await fixture.server.setMode(.homepageFailure)
        let icon = try await fixture.service.icon(for: fixture.url("/home"))
        #expect(icon == Data([1, 2, 3]))
        #expect(await fixture.server.paths == ["/home", "/favicon.ico"])
    }

    @Test("Nested homepages keep independent results and transient failures remain retryable", .timeLimit(.minutes(1)))
    func nestedHomepagesKeepIndependentResultsAndTransientFailuresRemainRetryable() async throws {
        let fixture = try IconFixture()
        let gate = RequestGate()
        defer { Task { await gate.open() } }
        await fixture.server.setMode(.transientA)
        await fixture.server.setGate(gate, forPath: "/a.png")
        async let a = fixture.service.icon(for: fixture.url("/a"))
        try await gate.waitUntilEntered()
        let firstB = try await fixture.service.icon(for: fixture.url("/b"))
        #expect(firstB == Data([2]))
        #expect(await fixture.server.paths == ["/a", "/a.png", "/b", "/b.png"])
        await gate.open()
        #expect(try await a == nil)
        await fixture.server.setMode(.normal)
        #expect(try await fixture.service.icon(for: fixture.url("/a")) == Data([1]))
        #expect(try await fixture.service.icon(for: fixture.url("/b")) == Data([2]))
        #expect(await fixture.server.paths.filter { $0 == "/a" }.count == 2)
        #expect(await fixture.server.paths.filter { $0 == "/b" }.count == 1)
    }

    @Test("Incorrect MIME types and oversized image responses are rejected") func incorrectMIMETypesAndOversizedImageResponsesAreRejected() async throws {
        let fixture = try IconFixture(maximumBytes: 128)
        await fixture.server.setMode(.wrongType)
        #expect(try await fixture.service.icon(for: fixture.url("/a")) == nil)
        await fixture.server.setMode(.oversized)
        #expect(try await fixture.service.icon(for: fixture.url("/a")) == nil)
    }

    @Test("Cancelling the final consumer prevents the fallback request", .timeLimit(.minutes(1))) func cancellingTheFinalConsumerPreventsTheFallbackRequest() async throws {
        let fixture = try IconFixture()
        let gate = RequestGate()
        defer { Task { await gate.open() } }
        await fixture.server.setGate(gate)
        let request = Task { try await fixture.service.icon(for: fixture.url("/home")) }
        try await gate.waitUntilEntered()
        request.cancel()
        await gate.open()
        await #expect(throws: (any Error).self) { try await request.value }
        #expect(await fixture.server.paths == ["/home"])
    }

    @Test("A single network slot serializes complete icon jobs", .timeLimit(.minutes(1))) func aSingleNetworkSlotSerializesCompleteIconJobs() async throws {
        let fixture = try IconFixture(maximumConcurrentRequests: 1)
        let gate = RequestGate()
        defer { Task { await gate.open() } }
        await fixture.server.setGate(gate)
        let first = Task { try await fixture.service.icon(for: fixture.url("/home")) }
        try await gate.waitUntilEntered()
        let second = Task { try await fixture.service.icon(for: fixture.url("/a")) }
        await gate.open()
        _ = try await first.value
        #expect(try await second.value == Data([1]))
        #expect(await fixture.server.paths == ["/home", "/favicon.ico", "/a", "/a.png"])
    }
}

struct FeedImageServiceTests {
    @Test("Thumbnails use display pixel bounds and share encoded requests")
    func thumbnailsUsePixelBoundsAndShareEncodedRequests() async throws {
        let fixture = try IconFixture()
        await fixture.server.setMode(.encoded(try Self.png()))
        let images = FeedImageService(icons: fixture.service)
        let small = try #require(try await images.image(for: fixture.url("/a"), maximumPixelSize: 32))
        #expect(small.width == 32 && small.height == 16)
        let same = try #require(try await images.image(for: fixture.url("/a#fragment"), maximumPixelSize: 32))
        #expect(same === small)
        let large = try #require(try await images.image(for: fixture.url("/a"), maximumPixelSize: 64))
        #expect(large.width == 64 && large.height == 32)
        #expect(await fixture.server.paths == ["/a", "/a.png"])
    }

    @Test("Malformed image data remains retryable after decoding fails")
    func malformedImageDataRemainsRetryableAfterDecodingFails() async throws {
        let fixture = try IconFixture()
        let images = FeedImageService(icons: fixture.service)
        #expect(try await images.image(for: fixture.url("/a"), maximumPixelSize: 32) == nil)
        await fixture.server.setMode(.encoded(try Self.png()))
        #expect(try await images.image(for: fixture.url("/a"), maximumPixelSize: 32) != nil)
        #expect(await fixture.server.paths == ["/a", "/a.png", "/a", "/a.png"])
    }

    @Test("Thumbnail dimensions stay bounded for invalid or excessive size requests",
          arguments: [0, -1, Int.max])
    func thumbnailDimensionsStayBounded(requestedPixels: Int) async throws {
        let fixture = try IconFixture()
        await fixture.server.setMode(.encoded(try Self.png()))
        let images = FeedImageService(icons: fixture.service)
        let thumbnail = try #require(try await images.image(for: fixture.url("/a"), maximumPixelSize: requestedPixels))
        let expected = min(256, max(1, requestedPixels))
        #expect(thumbnail.width == expected)
        #expect(thumbnail.height > 0 && thumbnail.height <= expected)
    }

    private static func png() throws -> Data {
        let context = try #require(CGContext(data: nil, width: 512, height: 256, bitsPerComponent: 8,
                                             bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 512, height: 256))
        let image = try #require(context.makeImage())
        let data = try #require(CFDataCreateMutable(nil, 0))
        let destination = try #require(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

private final class IconFixture: @unchecked Sendable {
    let server = IconTestServer()
    let service: IconService
    private let host: String
    private let session: URLSession
    init(maximumBytes: Int = 1_048_576, maximumConcurrentRequests: Int = 2) throws {
        host = UUID().uuidString.lowercased() + ".test"
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [IconURLProtocol.self]
        session = URLSession(configuration: configuration)
        service = IconService(session: session, maximumConcurrentRequests: maximumConcurrentRequests, maximumBytes: maximumBytes)
        let server = server
        IconURLProtocol.register(host: host) { request in try await server.respond(request) }
    }
    func url(_ path: String) throws -> URL { try #require(URL(string: "https://" + host + path)) }
    deinit { session.invalidateAndCancel(); IconURLProtocol.unregister(host: host) }
}

private struct IconResponse: Sendable {
    let status: Int
    let mime: String
    let data: Data
}

private actor IconTestServer {
    enum Mode: Equatable, Sendable { case normal, homepageFailure, transientA, wrongType, oversized, encoded(Data) }
    private var mode: Mode = .normal
    private var gate: RequestGate?
    private var pathGates: [String: RequestGate] = [:]
    var paths: [String] = []
    func setMode(_ mode: Mode) { self.mode = mode }
    func setGate(_ gate: RequestGate) { self.gate = gate }
    func setGate(_ gate: RequestGate, forPath path: String) { pathGates[path] = gate }
    func respond(_ request: URLRequest) async throws -> IconResponse {
        let path = try #require(request.url?.path)
        paths.append(path)
        if let gate = pathGates[path] { try await gate.pause() }
        if path == "/home" {
            if let gate { try await gate.pause() }
            return IconResponse(status: 403, mime: "text/html", data: Data())
        }
        if path == "/a" || path == "/b" {
            let candidate = path + ".png"
            return IconResponse(status: 200, mime: "text/html", data: Data("<link rel='icon' href='\(candidate)'>".utf8))
        }
        if path == "/a.png" {
            switch mode {
            case .encoded(let data): return IconResponse(status: 200, mime: "image/png", data: data)
            case .transientA: return IconResponse(status: 503, mime: "text/plain", data: Data())
            case .wrongType: return IconResponse(status: 200, mime: "text/html", data: Data("<script>bad</script>".utf8))
            case .oversized: return IconResponse(status: 200, mime: "image/png", data: Data(repeating: 0, count: 129))
            default: return IconResponse(status: 200, mime: "image/png", data: Data([1]))
            }
        }
        if path == "/b.png" { return IconResponse(status: 200, mime: "image/png", data: Data([2])) }
        return IconResponse(status: mode == .homepageFailure ? 200 : 404, mime: "image/x-icon", data: Data([1, 2, 3]))
    }
}

private final class IconURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async throws -> IconResponse
    private static let handlers = Mutex<[String: Handler]>([:])
    private let runningTask = Mutex<Task<Void, Never>?>(nil)
    static func register(host: String, handler: @escaping Handler) { handlers.withLock { $0[host] = handler } }
    static func unregister(host: String) { handlers.withLock { $0[host] = nil } }
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let handler = Self.handlers.withLock { $0[request.url?.host ?? ""] }
        let request = request
        let task = Task { @Sendable [self, handler, request] in
            do {
                guard let handler, let url = request.url else { throw ReaderError.invalidResponse }
                let result = try await handler(request)
                try Task.checkCancellation()
                guard let response = HTTPURLResponse(url: url, statusCode: result.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": result.mime, "Content-Length": String(result.data.count)]) else { throw ReaderError.invalidResponse }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: result.data)
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
        runningTask.withLock { $0 = task }
    }
    override func stopLoading() { runningTask.withLock { $0?.cancel(); $0 = nil } }
}
