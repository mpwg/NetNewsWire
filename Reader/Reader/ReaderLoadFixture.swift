#if DEBUG && os(macOS)
import SwiftUI
import Observation
import ReaderDomain
import ReaderPersistence

/// Opt-in native load scenario; uses the caller's isolated in-memory store.
@MainActor @Observable
final class ReaderLoadFixture {
    private(set) var phase = "preparing"
    private(set) var articleCount = 0
    private(set) var feedCount = 0
    private(set) var folderCount = 0
    @ObservationIgnored private let store: ReaderStore
    @ObservationIgnored private var prepared = false

    init(store: ReaderStore) { self.store = store }

    /// Runs only after native measurements; unchanged status sets isolate subscription deletion.
    func removeFolderFeed() async {
        guard phase == "ready" else { return }
        do {
            var snapshot = try ReaderLoadScenario.make().snapshot
            snapshot.feeds.removeAll { $0.id.remoteID == "feed/20" }
            snapshot.articles = []
            try await store.applyRefresh(snapshot)
            phase = "removed"
        } catch { phase = "failed: \(error.localizedDescription)" }
    }

    func prepare() async {
        guard !prepared else { return }
        prepared = true
        do {
            let scenario = try ReaderLoadScenario.make()
            try await store.saveAccount(scenario.account)
            try await store.applyRefresh(scenario.snapshot)
            articleCount = scenario.snapshot.articles.count
            feedCount = scenario.snapshot.feeds.count
            folderCount = scenario.snapshot.folders.count
            phase = "ready"
        } catch { phase = "failed: \(error.localizedDescription)" }
    }
}

struct ReaderLoadPanel: View {
    let fixture: ReaderLoadFixture

    var body: some View {
        HStack {
            Text(verbatim: fixture.phase).accessibilityIdentifier("loadFixturePhase")
            Text(verbatim: "\(fixture.articleCount) articles · \(fixture.feedCount) feeds · \(fixture.folderCount) folders")
                .accessibilityIdentifier("loadFixtureCounts")
            Button { Task { await fixture.removeFolderFeed() } } label: { Text(verbatim: "Remove folder feed") }
                .accessibilityIdentifier("removeLoadFolderFeed")
        }
        .font(.caption)
        .padding(8)
        .task { await fixture.prepare() }
    }
}
#endif
