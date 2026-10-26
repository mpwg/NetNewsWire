#if DEBUG && os(macOS)
import SwiftUI
import Observation
import ReaderDomain
import ReaderPersistence

/// Isolated native UI scenario; never opens a persistent store or contacts FreshRSS.
@MainActor @Observable
final class ReaderTimelineFixture {
    private(set) var phase = "preparing"
    private(set) var pendingReadCount = 0
    private(set) var queryStats = ReaderTimelineQueryStats()
    @ObservationIgnored let repository: ReaderTimelineRepository
    @ObservationIgnored private let store: ReaderStore
    @ObservationIgnored private var prepared = false

    init(store: ReaderStore) {
        self.store = store
        repository = ReaderTimelineRepository(store: store)
    }

    func observe() async {
        guard !prepared else { return }
        prepared = true
        await repository.observe { [weak self] in self?.queryStats = $0 }
        do {
            guard let url = URL(string: "https://timeline.reader.invalid") else { throw ReaderError.invalidURL }
            let account = ReaderAccount(serverURL: url, username: "timeline-fixture")
            let feed = FeedSnapshot(id: FeedKey(accountID: account.id, remoteID: "timeline"),
                                    title: "Timeline fixture", url: url)
            try await store.saveAccount(account)
            let articles = (0..<300).map { index in
                ArticleSnapshot(id: ArticleKey(accountID: account.id, remoteID: "\(index)"),
                                feedID: feed.id.remoteID, title: "Timeline article \(index)",
                                html: "<h1>Representative content</h1><p>" + String(repeating: "A longer article remains readable. ", count: 100) + "</p>",
                                text: "Representative content for keyboard selection and bulk actions.",
                                dateArrived: Date(timeIntervalSince1970: Double(index)))
            }
            try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: [feed], folders: [],
                                                        articles: articles, unreadIDs: Set(articles.map(\.id.remoteID)), starredIDs: []))
            phase = "ready"
            let changes = await store.changes()
            for await _ in changes {
                guard !Task.isCancelled else { return }
                let pending = try await store.pendingChanges(accountID: account.id)
                pendingReadCount = pending.filter { $0.field == .read && $0.value }.count
            }
        } catch is CancellationError {
        } catch { phase = "failed: \(error.localizedDescription)" }
    }
}

struct ReaderTimelinePanel: View {
    let fixture: ReaderTimelineFixture
    var body: some View {
        HStack {
            Text(verbatim: fixture.phase).accessibilityIdentifier("timelineFixturePhase")
            Text(verbatim: "\(fixture.pendingReadCount)").accessibilityIdentifier("timelinePendingReadCount")
            Button { Task { await fixture.repository.holdQueries() } } label: { Text(verbatim: "Hold queries") }
                .accessibilityIdentifier("holdTimelineQueries")
            Button { Task { await fixture.repository.releaseQueries() } } label: { Text(verbatim: "Release queries") }
                .accessibilityIdentifier("releaseTimelineQueries")
            Text(verbatim: "\(fixture.queryStats.lookups)").accessibilityIdentifier("timelineQueryCount")
            Text(verbatim: "\(fixture.queryStats.held)").accessibilityIdentifier("timelineHeldQueries")
            Text(verbatim: "\(fixture.queryStats.feedReadCalls)").accessibilityIdentifier("timelineFeedReadCalls")
        }
        .font(.caption)
        .padding(8)
        .task { await fixture.observe() }
    }
}
nonisolated struct ReaderTimelineQueryStats: Equatable, Sendable {
    var lookups = 0
    var held = 0
    var feedReadCalls = 0
}

/// Observes shipping repository calls; the gate delays actual list requests without blocking MainActor.
actor ReaderTimelineRepository: ReaderRepository {
    private let store: ReaderStore
    private var holdsQueries = false
    private var waiters: [UUID: AsyncStream<Void>.Continuation] = [:]
    private var stats = ReaderTimelineQueryStats()
    private var observer: (@MainActor @Sendable (ReaderTimelineQueryStats) -> Void)?

    init(store: ReaderStore) { self.store = store }

    func observe(_ observer: @escaping @MainActor @Sendable (ReaderTimelineQueryStats) -> Void) async {
        self.observer = observer
        await publish()
    }

    func holdQueries() { holdsQueries = true }
    func releaseQueries() {
        holdsQueries = false
        for continuation in waiters.values { continuation.finish() }
    }

    private func publish() async {
        stats.held = waiters.count
        await observer?(stats)
    }

    func articles(_ query: ArticleQuery) async throws -> [ArticleSnapshot] {
        stats.lookups += 1
        if holdsQueries {
            let id = UUID()
            let (stream, continuation) = AsyncStream<Void>.makeStream()
            waiters[id] = continuation
            await publish()
            for await _ in stream { break }
            waiters[id] = nil
        }
        await publish()
        try Task.checkCancellation()
        return try await store.articles(query)
    }

    func article(_ key: ArticleKey) async throws -> ArticleSnapshot? {
        stats.lookups += 1
        await publish()
        return try await store.article(key)
    }

    func markFeedRead(_ feed: FeedKey) async throws -> [ArticleKey] {
        stats.feedReadCalls += 1
        await publish()
        return try await store.markFeedRead(feed)
    }

    func accounts() async throws -> [ReaderAccount] { try await store.accounts() }
    func saveAccount(_ account: ReaderAccount) async throws { try await store.saveAccount(account) }
    func feeds() async throws -> [FeedSnapshot] { try await store.feeds() }
    func folders() async throws -> [FolderSnapshot] { try await store.folders() }
    func unreadCounts() async throws -> [FeedKey: Int] { try await store.unreadCounts() }
    func currentRevision() async -> UInt64 { await store.currentRevision() }
    func changes() async -> AsyncStream<UInt64> { await store.changes() }
    func applyRefresh(_ snapshot: RefreshSnapshot) async throws { try await store.applyRefresh(snapshot) }
    func setStatus(_ keys: [ArticleKey], field: StatusField, value: Bool) async throws { try await store.setStatus(keys, field: field, value: value) }
    func pendingChanges(accountID: UUID) async throws -> [PendingChange] { try await store.pendingChanges(accountID: accountID) }
    func acknowledge(_ changes: [PendingChange]) async throws { try await store.acknowledge(changes) }
    func preferences() async throws -> [FeedPreferences] { try await store.preferences() }
    func savePreferences(_ preferences: FeedPreferences) async throws { try await store.savePreferences(preferences) }
    func mergeImportMetadata(feed: FeedKey, homePageURL: URL?, folderPath: [String], feedURL: URL) async throws {
        try await store.mergeImportMetadata(feed: feed, homePageURL: homePageURL, folderPath: folderPath, feedURL: feedURL)
    }
    func digests() async throws -> [DigestSnapshot] { try await store.digests() }
    func saveDigest(_ digest: DigestSnapshot) async throws { try await store.saveDigest(digest) }
    func saveDigest(_ digest: DigestSnapshot, expectedSources: [ArticleSnapshot]) async throws -> Bool {
        try await store.saveDigest(digest, expectedSources: expectedSources)
    }
    func updateContent(_ key: ArticleKey, html: String, text: String) async throws {
        try await store.updateContent(key, html: html, text: text)
    }
    func updateContent(_ source: ArticleSnapshot, html: String, text: String) async throws -> Bool {
        try await store.updateContent(source, html: html, text: text)
    }
}
#endif
