#if DEBUG && os(macOS)
import SwiftUI
import Observation
import ImageIO
import UniformTypeIdentifiers
import Synchronization
import ReaderDomain
import ReaderPersistence
import ReaderSync

/// Explicit UI-test mode only: no real account, Keychain access or external HTTP.
@MainActor @Observable
final class ReaderImageLoadFixture {
    private(set) var phase = "preparing"
    private(set) var stats = ReaderImageLoadStats()
    @ObservationIgnored let images: FeedImageService
    @ObservationIgnored private let store: ReaderStore
    @ObservationIgnored private let server = ReaderImageLoadServer()
    @ObservationIgnored private var account: ReaderAccount?
    @ObservationIgnored private var prepared = false

    init(store: ReaderStore) {
        self.store = store
        let server = server
        ReaderFixtureURLProtocol.handler.withLock { $0 = { try await server.respond($0) } }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReaderFixtureURLProtocol.self]
        configuration.urlCache = nil
        images = FeedImageService(icons: IconService(session: URLSession(configuration: configuration)))
    }

    func prepare() async {
        guard !prepared else { return }
        prepared = true
        await server.observe { [weak self] in self?.stats = $0 }
        do {
            guard let url = URL(string: "https://account.reader-image.invalid") else { throw ReaderError.invalidURL }
            let account = ReaderAccount(serverURL: url, username: "image-load-fixture")
            self.account = account
            try await store.saveAccount(account)
            try await replaceFeeds(withHomepages: false)
            phase = "ready"
        } catch { phase = "failed: \(error.localizedDescription)" }
    }

    func start() async {
        guard phase == "ready" else { return }
        phase = "running"
        do { try await replaceFeeds(withHomepages: true) } catch { phase = "failed: \(error.localizedDescription)" }
    }

    func removeFeeds() async {
        guard let account else { return }
        do {
            try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: [], folders: [],
                                                        articles: [], unreadIDs: [], starredIDs: []))
            phase = "removed"
        } catch { phase = "failed: \(error.localizedDescription)" }
    }

    private func replaceFeeds(withHomepages: Bool) async throws {
        guard let account else { throw ReaderError.invalidResponse }
        let feeds = try (0..<50).map { index in
            guard let home = URL(string: "https://load-\(index).reader-image.invalid/news") else { throw ReaderError.invalidURL }
            return FeedSnapshot(id: FeedKey(accountID: account.id, remoteID: "load-\(index)"),
                                title: "Load feed \(index)", url: home.appendingPathComponent("feed.xml"),
                                homePageURL: withHomepages ? home : nil)
        }
        try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: feeds, folders: [],
                                                    articles: [], unreadIDs: [], starredIDs: []))
    }
}

struct ReaderImageLoadPanel: View {
    let fixture: ReaderImageLoadFixture

    var body: some View {
        HStack {
            Button { Task { await fixture.start() } } label: { Text(verbatim: "Start image load") }
                .disabled(fixture.phase != "ready")
                .accessibilityIdentifier("startImageLoad")
            Button { Task { await fixture.removeFeeds() } } label: { Text(verbatim: "Remove fixture feeds") }
                .disabled(fixture.phase != "running")
                .accessibilityIdentifier("removeImageLoadFeeds")
            Text(verbatim: fixture.phase).accessibilityIdentifier("imageLoadPhase")
            ReaderImageLoadCounters(stats: fixture.stats)
        }
        .font(.caption)
        .padding(8)
        .task { await fixture.prepare() }
    }
}

private struct ReaderImageLoadCounters: View {
    let stats: ReaderImageLoadStats
    var body: some View {
        HStack {
            Text(verbatim: "\(stats.active)").accessibilityIdentifier("imageLoadActive")
            Text(verbatim: "\(stats.delivered)").accessibilityIdentifier("imageLoadDelivered")
            Text(verbatim: "\(stats.cancelled)").accessibilityIdentifier("imageLoadCancelled")
            Text(verbatim: "\(stats.retries)").accessibilityIdentifier("imageLoadRetries")
            Text(verbatim: "\(stats.maximumActive)").accessibilityIdentifier("imageLoadMaximumActive")
        }
    }
}

nonisolated struct ReaderImageLoadStats: Equatable, Sendable {
    var active = 0
    var maximumActive = 0
    var delivered = 0
    var cancelled = 0
    var retries = 0
}

private actor ReaderImageLoadServer {
    private var stats = ReaderImageLoadStats()
    private var observer: (@MainActor @Sendable (ReaderImageLoadStats) -> Void)?
    private var png: Data?

    func observe(_ observer: @escaping @MainActor @Sendable (ReaderImageLoadStats) -> Void) { self.observer = observer }

    func respond(_ request: URLRequest) async throws -> (Int, String, Data) {
        guard let url = request.url, url.host?.hasSuffix(".reader-image.invalid") == true else { throw ReaderError.invalidURL }
        stats.active += 1
        stats.maximumActive = max(stats.maximumActive, stats.active)
        await observer?(stats)
        do {
            let response = try await response(for: url)
            stats.active -= 1
            await observer?(stats)
            return response
        } catch {
            stats.active -= 1
            if Task.isCancelled { stats.cancelled += 1 }
            await observer?(stats)
            throw error
        }
    }

    private func response(for url: URL) async throws -> (Int, String, Data) {
        try await Task.sleep(for: .milliseconds(100))
        switch url.path {
        case "/news":
            let head = "<head><link rel='icon' href='/icon.png'>" + String(repeating: "<!-- metadata padding -->", count: 2500)
            let body = "</head><body>" + String(repeating: "<p>Article body content</p>", count: 5000) + "</body>"
            return (200, "text/html", Data((head + body).utf8))
        case "/icon.png":
            stats.retries += 1
            return (503, "text/plain", Data())
        case "/favicon.ico":
            try await Task.sleep(for: .seconds(4))
            if png == nil { png = try Self.makePNG() }
            try Task.checkCancellation()
            stats.delivered += 1
            return (200, "image/png", png ?? Data())
        default:
            return (404, "text/plain", Data())
        }
    }

    private static func makePNG() throws -> Data {
        guard let context = CGContext(data: nil, width: 4096, height: 4096, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ReaderError.invalidResponse }
        context.setFillColor(CGColor(red: 0.08, green: 0.6, blue: 0.95, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4096, height: 4096))
        let data = NSMutableData()
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw ReaderError.invalidResponse
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ReaderError.invalidResponse }
        return data as Data
    }
}

#endif
