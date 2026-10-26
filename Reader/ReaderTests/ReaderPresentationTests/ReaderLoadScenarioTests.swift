#if DEBUG
import Foundation
import Testing
import ReaderDomain
import ReaderPersistence
import ReaderUI

@MainActor
struct ReaderLoadScenarioTests {
    @Test("Stored load preserves paging and 31-day-old deletion with unchanged surviving originals",
          arguments: [1_000, 10_000])
    func loadScenarioPreservesStoredCoverage(articleCount: Int) async throws {
        let referenceDate = Date(timeIntervalSince1970: 1_792_800_000)
        let scenario = try ReaderLoadScenario.make(articleCount: articleCount, referenceDate: referenceDate)
        let store = try ReaderStore(inMemory: true)
        try await store.saveAccount(scenario.account)
        let clock = ContinuousClock()
        let ingestionStart = clock.now
        try await store.applyRefresh(scenario.snapshot)
        var timings = [LoadOperationTiming(operation: "applyRefresh", milliseconds: Self.milliseconds(ingestionStart.duration(to: clock.now)))]
        let originals = scenario.snapshot.articles
        var storedKeys: [ArticleKey] = []
        while storedKeys.count < articleCount {
            let page = try await store.articles(ArticleQuery(offset: storedKeys.count, limit: 1_000))
            if page.isEmpty { break }
            storedKeys.append(contentsOf: page.map(\.id))
        }
        #expect(storedKeys.count == articleCount)
        let completeCoverage = storedKeys.elementsEqual(originals.map(\.id))
        #expect(completeCoverage, "Every stored key must retain the scenario order")
        #expect(try await store.articles(ArticleQuery(offset: articleCount, limit: 1)).isEmpty)

        let feed = try #require(scenario.snapshot.feeds.dropFirst(23).first)
        let folder = try #require(scenario.snapshot.folders.first)
        let folderFeeds = Set(scenario.snapshot.feeds.filter { $0.folderIDs.contains(folder.remoteID) }.map(\.id.remoteID))
        let queries: [(name: String, sidebar: String?, search: String, sources: [ArticleSnapshot])] = [
            ("all", nil, "", originals),
            ("unread", "unread", "", originals.filter { scenario.snapshot.unreadIDs.contains($0.id.remoteID) }),
            ("starred", "starred", "", originals.filter { scenario.snapshot.starredIDs.contains($0.id.remoteID) }),
            ("feed", feed.id.id, "", originals.filter { $0.feedID == feed.id.remoteID }),
            ("folder", folder.id, "", originals.filter { folderFeeds.contains($0.feedID) }),
            ("body search", nil, "load-needle", originals.filter { $0.text.contains("load-needle") })
        ]
        let services = ReaderServices(repository: store)
        let session = ReaderSession(services: services)
        for query in queries {
            session.sidebarSelection = query.sidebar
            session.search = query.search
            let reloadStart = clock.now
            await session.reload(resetLimit: true)
            timings.append(LoadOperationTiming(operation: "reload-\(query.name)", milliseconds: Self.milliseconds(reloadStart.duration(to: clock.now))))
            try #require(session.errorMessage == nil)
            #expect(session.feeds.count == scenario.snapshot.feeds.count)
            #expect(session.folders.count == scenario.snapshot.folders.count)
            #expect(session.unreadCounts.total == scenario.snapshot.unreadIDs.count)
            #expect(session.unreadCounts.byAccount == [scenario.account.id: scenario.snapshot.unreadIDs.count])
            #expect(session.articles.map(\.id) == Array(query.sources.prefix(200)).map(\.id), "First page: \(query.name)")
            #expect(session.rows.count == min(200, query.sources.count))
            if query.sources.count > 200 {
                let loadMoreStart = clock.now
                await session.loadMore()
                timings.append(LoadOperationTiming(operation: "loadMore-\(query.name)", milliseconds: Self.milliseconds(loadMoreStart.duration(to: clock.now))))
                #expect(session.articles.map(\.id) == Array(query.sources.prefix(400)).map(\.id), "Second page: \(query.name)")
                #expect(session.rows.count == min(400, query.sources.count))
            }
        }
        #expect(try await store.pendingChanges(accountID: scenario.account.id).isEmpty)
        #expect(services.credentials == nil)
        #expect(services.client == nil)
        let report = LoadTimingReport(articleCount: articleCount, operations: timings)
        let data = try JSONEncoder().encode(report)
        Attachment.record(data, named: "Synthetic load session timings - \(articleCount) articles.json")
        // Keep fixture arithmetic and deletion semantics in code; UI checks only the native wiring.
        let removedFeed = "feed/20"
        let subject = try #require(originals.first { $0.id.remoteID == "item/120" })
        let subjectAge = referenceDate.timeIntervalSince(subject.dateArrived)
        #expect(subject.feedID == removedFeed)
        #expect(!subject.read && !subject.starred)
        #expect(subjectAge >= 31 * 24 * 60 * 60 && subjectAge < 32 * 24 * 60 * 60)
        let expectedSurvivors = originals.filter { $0.feedID != removedFeed || $0.starred }
        var deletion = scenario.snapshot
        deletion.feeds.removeAll { $0.id.remoteID == removedFeed }
        deletion.articles = []
        try await store.applyRefresh(deletion)
        session.sidebarSelection = "unread"
        session.search = "Load article 120."
        await session.reload(resetLimit: true)
        let retainedUnread = originals.filter { !$0.read && ($0.feedID != removedFeed || $0.starred) }
        let remainingFolderFeeds = Set(deletion.feeds.filter { $0.folderIDs.contains(folder.remoteID) }.map(\.id.remoteID))
        let expectedFolderUnread = retainedUnread.filter { remainingFolderFeeds.contains($0.feedID) }.count
        #expect(session.articles.isEmpty)
        #expect(session.rows.isEmpty)
        #expect(session.unreadCounts.total == retainedUnread.count)
        #expect(session.unreadCounts.byAccount == [scenario.account.id: retainedUnread.count])
        #expect(session.unreadCounts.byFolder[folder.id] == expectedFolderUnread)
        #expect(try await store.article(subject.id) == nil)
        var survivors: [ArticleSnapshot] = []
        while survivors.count < expectedSurvivors.count {
            let page = try await store.articles(ArticleQuery(offset: survivors.count, limit: 1_000))
            if page.isEmpty { break }
            survivors.append(contentsOf: page)
        }
        let unchangedRemainingContent = survivors.elementsEqual(expectedSurvivors)
        #expect(unchangedRemainingContent, "Every surviving original must keep its whole pre-deletion snapshot.")
        #expect(try await store.pendingChanges(accountID: scenario.account.id).isEmpty)
        if articleCount == 10_000 {
            #expect(retainedUnread.count == 7_430)
            #expect(expectedFolderUnread == 525)
        }

    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1_000_000_000_000_000
    }
}

nonisolated private struct LoadOperationTiming: Encodable, Sendable {
    let operation: String
    let milliseconds: Double
}

nonisolated private struct LoadTimingReport: Encodable, Sendable {
    let articleCount: Int
    let operations: [LoadOperationTiming]
    let store = "in-memory synthetic SwiftData"
    let measurement = "single observation per operation with ContinuousClock; no regression budget"
    let reloadScope = "ReaderSession reload including metadata, query and row construction; no app rendering"
}
#endif
