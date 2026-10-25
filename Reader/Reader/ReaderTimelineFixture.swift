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
    @ObservationIgnored private let store: ReaderStore
    @ObservationIgnored private var prepared = false

    init(store: ReaderStore) { self.store = store }

    func observe() async {
        guard !prepared else { return }
        prepared = true
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
        }
        .font(.caption)
        .padding(8)
        .task { await fixture.observe() }
    }
}
#endif
