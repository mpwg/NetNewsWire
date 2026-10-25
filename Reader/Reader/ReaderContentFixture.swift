#if DEBUG && os(macOS)
import SwiftUI
import Observation
import Synchronization
import ReaderDomain
import ReaderPersistence
import ReaderContent

/// Native app scenario with saved content and a controlled extraction transport.
@MainActor @Observable
final class ReaderContentFixture {
    private(set) var phase = "preparing"
    private(set) var stats = ReaderContentStats()
    @ObservationIgnored let content: ArticleContentService
    @ObservationIgnored private let store: ReaderStore
    @ObservationIgnored private let server = ReaderContentServer()
    @ObservationIgnored private var prepared = false

    init(store: ReaderStore) {
        self.store = store
        let server = server
        ReaderFixtureURLProtocol.handler.withLock { $0 = { try await server.respond($0) } }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReaderFixtureURLProtocol.self]
        configuration.urlCache = nil
        content = ArticleContentService(session: URLSession(configuration: configuration))
    }

    func prepare() async {
        guard !prepared else { return }
        prepared = true
        await server.observe { [weak self] in self?.stats = $0 }
        do {
            guard let base = URL(string: "https://content.reader.invalid") else { throw ReaderError.invalidURL }
            let account = ReaderAccount(serverURL: base, username: "content-fixture")
            let feed = FeedSnapshot(id: FeedKey(accountID: account.id, remoteID: "content"), title: "Content fixture", url: base)
            try await store.saveAccount(account)
            let articles = ["A", "B"].enumerated().map { index, marker in
                ArticleSnapshot(id: ArticleKey(accountID: account.id, remoteID: marker.lowercased()), feedID: feed.id.remoteID,
                                title: "Saved article " + marker,
                                html: "<h1>Saved native article " + marker + "</h1><p>Saved feed content remains readable.</p>",
                                text: "Saved native article " + marker,
                                url: base.appendingPathComponent(marker.lowercased()),
                                dateArrived: Date(timeIntervalSince1970: Double(2 - index)))
            }
            try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: [feed], folders: [], articles: articles,
                                                        unreadIDs: ["a", "b"], starredIDs: []))
            phase = "ready"
        } catch { phase = "failed: \(error.localizedDescription)" }
    }
}

struct ReaderContentPanel: View {
    let fixture: ReaderContentFixture
    var body: some View {
        HStack {
            Text(verbatim: fixture.phase).accessibilityIdentifier("contentFixturePhase")
            Text(verbatim: "\(fixture.stats.requests)").accessibilityIdentifier("contentRequests")
            Text(verbatim: "\(fixture.stats.active)").accessibilityIdentifier("contentActive")
            Text(verbatim: "\(fixture.stats.cancelled)").accessibilityIdentifier("contentCancelled")
        }
        .font(.caption)
        .padding(8)
        .task { await fixture.prepare() }
    }
}

nonisolated struct ReaderContentStats: Sendable, Equatable {
    var requests = 0
    var active = 0
    var cancelled = 0
}

private actor ReaderContentServer {
    private var stats = ReaderContentStats()
    private var observer: (@MainActor @Sendable (ReaderContentStats) -> Void)?

    func observe(_ observer: @escaping @MainActor @Sendable (ReaderContentStats) -> Void) { self.observer = observer }

    func respond(_ request: URLRequest) async throws -> (Int, String, Data) {
        guard request.url?.host == "content.reader.invalid" else { throw ReaderError.invalidURL }
        stats.requests += 1
        stats.active += 1
        await observer?(stats)
        do {
            let response: (Int, String, Data)
            if request.url?.path == "/a" {
                try await Task.sleep(for: .seconds(30))
                response = (200, "text/html", Data("<article><p>Late article A</p></article>".utf8))
            } else { response = (403, "text/html", Data("Access denied".utf8)) }
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
}
#endif
