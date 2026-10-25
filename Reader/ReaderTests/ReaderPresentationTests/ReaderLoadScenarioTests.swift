#if DEBUG
import Foundation
import Testing
import ReaderDomain
import ReaderPersistence
import ReaderUI

@MainActor
struct ReaderLoadScenarioTests {
    @Test("The synthetic load survives storage and shipping query/pagination transitions",
          arguments: [1_000, 10_000])
    func loadScenarioPreservesStoredCoverage(articleCount: Int) async throws {
        let scenario = try ReaderLoadScenario.make(articleCount: articleCount)
        let store = try ReaderStore(inMemory: true)
        try await store.saveAccount(scenario.account)
        try await store.applyRefresh(scenario.snapshot)
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
            await session.reload(resetLimit: true)
            try #require(session.errorMessage == nil)
            #expect(session.feeds.count == scenario.snapshot.feeds.count)
            #expect(session.folders.count == scenario.snapshot.folders.count)
            #expect(session.articles.map(\.id) == Array(query.sources.prefix(200)).map(\.id), "First page: \(query.name)")
            #expect(session.rows.count == min(200, query.sources.count))
            if query.sources.count > 200 {
                await session.loadMore()
                #expect(session.articles.map(\.id) == Array(query.sources.prefix(400)).map(\.id), "Second page: \(query.name)")
                #expect(session.rows.count == min(400, query.sources.count))
            }
        }
        #expect(try await store.pendingChanges(accountID: scenario.account.id).isEmpty)
        #expect(services.credentials == nil)
        #expect(services.client == nil)
    }
}
#endif
