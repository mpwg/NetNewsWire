import Foundation
import Testing
import ReaderDomain
import ReaderPersistence
@testable import ReaderUI

@MainActor
struct ReaderSessionTests {
    private func fixture(count: Int = 3) async throws -> (ReaderStore, ReaderServices, FeedSnapshot, [ArticleSnapshot]) {
        let store = try ReaderStore(inMemory: true)
        let account = ReaderAccount(serverURL: try #require(URL(string: "https://example.test/api/greader.php")), username: "reader")
        try await store.saveAccount(account)
        let feed = FeedSnapshot(id: FeedKey(accountID: account.id, remoteID: "feed/1"), title: "Testfeed", url: account.serverURL)
        let articles = (0..<count).map { index in
            ArticleSnapshot(id: ArticleKey(accountID: account.id, remoteID: "\(index)"), feedID: feed.id.remoteID,
                            title: "Article \(index)", text: "Content \(index)", dateArrived: Date(timeIntervalSince1970: Double(index)))
        }
        try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: [feed], folders: [], articles: articles,
                                                    unreadIDs: Set(articles.map(\.id.remoteID)), starredIDs: []))
        return (store, ReaderServices(repository: store), feed, articles)
    }

    @Test("Sessions own independent selection and search state") func sessionsOwnIndependentSelectionAndSearchState() async throws {
        let (_, services, feed, _) = try await fixture()
        let a = ReaderSession(services: services)
        let b = ReaderSession(services: services)
        a.sidebarSelection = feed.id.id
        a.search = "Article 1"
        b.sidebarSelection = "all"
        await a.reload()
        await b.reload()
        #expect(a.articles.count == 1)
        #expect(b.articles.count == 3)
        #expect(b.search.isEmpty)
        a.showingAccount = true
        #expect(!b.showingAccount)
    }

    @Test("Opening a digest does not change original article status") func openingADigestDoesNotChangeOriginalArticleStatus() async throws {
        let (store, services, feed, articles) = try await fixture()
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                    sections: [], sources: articles.map(\.id))
        try await store.saveDigest(digest)
        let session = ReaderSession(services: services)
        await session.reload()
        session.selection = .digest(digest.id)
        await session.loadSources(digest)
        #expect(try await store.articles(ArticleQuery(unreadOnly: true)).count == 3)
        #expect(try await store.pendingChanges(accountID: feed.id.accountID).isEmpty)
    }

    @Test("Unprocessed originals remain visible in digest mode") func unprocessedOriginalsRemainVisibleInDigestMode() async throws {
        let (store, services, feed, articles) = try await fixture()
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest))
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                    sections: [], sources: [articles[0].id])
        try await store.saveDigest(digest)
        let session = ReaderSession(services: services)
        await session.reload()
        #expect(session.rows.count == 3)
        #expect(session.rows.contains { $0.id == .article(articles[1].id) })
        #expect(session.rows.contains { $0.id == .article(articles[2].id) })
    }

    @Test("Sources outside the loaded page remain accessible") func sourcesOutsideTheLoadedPageRemainAccessible() async throws {
        let (store, services, feed, articles) = try await fixture(count: 350)
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                    sections: [], sources: articles.map(\.id))
        try await store.saveDigest(digest)
        let session = ReaderSession(services: services)
        await session.reload()
        #expect(session.articles.count == 200)
        await session.loadSources(digest)
        #expect(session.sourceArticles.count == 350)
        session.selection = .article(articles[0].id)
        await session.loadSelectedArticle()
        #expect(session.selectedArticle?.id == articles[0].id)
    }

    @Test("Marking the displayed revision read leaves new sources unread") func markingTheDisplayedRevisionReadLeavesNewSourcesUnread() async throws {
        let (store, services, feed, articles) = try await fixture()
        let displayed = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                       sections: [], sources: [articles[0].id])
        var updated = displayed
        updated.sources = articles.map(\.id)
        updated.revision = UUID()
        try await store.saveDigest(updated)
        let session = ReaderSession(services: services)
        await session.setStatus(displayed.sources, field: .read, value: true)
        let unread = try await store.articles(ArticleQuery(unreadOnly: true))
        #expect(Set(unread.map(\.id)) == Set([articles[1].id, articles[2].id]))
    }

    @Test("Pagination reaches more than one thousand articles") func paginationReachesMoreThanOneThousandArticles() async throws {
        let (_, services, _, _) = try await fixture(count: 1_210)
        let session = ReaderSession(services: services)
        await session.reload()
        for _ in 0..<6 { await session.loadMore() }
        #expect(session.articles.count == 1_210)
        #expect(!session.canLoadMore)
    }

    @Test("Late responses from A and B do not overwrite C") func lateResponsesFromAAndBDoNotOverwriteC() async throws {
        let (store, _, feed, _) = try await fixture()
        let gate = QueryGate(accountID: feed.id.accountID)
        defer { Task { for search in ["A", "B", "C"] { await gate.release(search) } } }
        let repository = ScriptedRepository(base: store) { query in try await gate.response(query.search) }
        let session = ReaderSession(services: ReaderServices(repository: repository))
        session.search = "A"
        let a = Task { await session.reload() }
        try await gate.waitUntilStarted("A")
        session.search = "B"
        let b = Task { await session.reload() }
        try await gate.waitUntilStarted("B")
        session.search = "C"
        let c = Task { await session.reload() }
        try await gate.waitUntilStarted("C")
        await gate.release("C")
        await c.value
        #expect(session.articles.first?.title == "C")
        await gate.release("B")
        await gate.release("A")
        await a.value
        await b.value
        #expect(session.articles.first?.title == "C")
        #expect(session.rows.first?.title == "C")
    }

    @Test("Different sidebar and search inputs never share a task identity", arguments: [false, true])
    func differentQueryInputsHaveDistinctTaskIdentities(separatorCollision: Bool) async throws {
        let (_, services, feed, _) = try await fixture()
        let session = ReaderSession(services: services)
        if separatorCollision {
            session.sidebarSelection = feed.id.id + "|nested"
            session.search = "term"
        }
        let first = session.queryIdentity
        session.sidebarSelection = separatorCollision ? feed.id.id : "unread"
        session.search = separatorCollision ? "nested|term" : ""
        #expect(session.queryIdentity != first)
        #expect(Set([first, session.queryIdentity]).count == 2)
    }

    @Test("The first Unread selection has a new task identity and filters persisted read state")
    func firstUnreadSelectionFiltersPersistedReadState() async throws {
        let (store, services, _, articles) = try await fixture()
        try await store.setStatus([articles[0].id], field: .read, value: true)
        let session = ReaderSession(services: services)
        await session.reload()
        #expect(session.rows.count == 3)
        let allIdentity = session.queryIdentity
        session.sidebarSelection = "unread"
        try #require(session.queryIdentity != allIdentity, "SwiftUI must start a new query task for the first Unread selection.")
        await session.reload(resetLimit: true)
        #expect(session.articles.count == 2)
        #expect(session.rows.count == 2)
        #expect(session.rows.allSatisfy { $0.unread })
        #expect(!session.rows.contains { $0.id == .article(articles[0].id) })
    }

    @Test("Multiple selections show no arbitrary primary detail and remain window-local")
    func multipleSelectionsHaveNoArbitraryPrimaryDetail() async throws {
        let (_, services, _, articles) = try await fixture()
        let session = ReaderSession(services: services)
        let otherWindow = ReaderSession(services: services)
        await session.reload()
        session.timelineSelection = [.article(articles[0].id)]
        #expect(session.selection == .article(articles[0].id))
        session.timelineSelection.insert(.article(articles[1].id))
        #expect(session.selection == nil)
        #expect(session.selectedArticle == nil)
        #expect(otherWindow.timelineSelection.isEmpty)
        session.timelineSelection.remove(.article(articles[0].id))
        #expect(session.selectedArticle?.id == articles[1].id)
        session.selection = .article(articles[2].id)
        #expect(session.timelineSelection == [.article(articles[2].id)])
        session.selection = nil
        #expect(session.timelineSelection.isEmpty)
    }

    @Test("Selection follows published filters and removes rows that leave the current result", arguments: [false, true])
    func selectionReconcilesWithPublishedResults(changesQuery: Bool) async throws {
        let (store, services, _, articles) = try await fixture()
        let session = ReaderSession(services: services)
        session.sidebarSelection = "unread"
        await session.reload()
        session.timelineSelection = [.article(articles[0].id), .article(articles[1].id)]
        try await store.setStatus([articles[0].id], field: .read, value: true)
        if changesQuery { session.search = "Article 1" }
        await session.reload()
        #expect(session.timelineSelection == (changesQuery ? [] : [.article(articles[1].id)]))
        #expect(Set(session.rows.map(\.id)).isSuperset(of: session.timelineSelection))
    }

    enum BulkAction: CaseIterable, Sendable {
        case markRead, markUnread, star, unstar
        var field: StatusField { self == .star || self == .unstar ? .starred : .read }
        var value: Bool { self == .markRead || self == .star }
    }

    @Test("Bulk actions commit only the captured selected article keys", arguments: BulkAction.allCases)
    func bulkActionsUseCapturedSelection(action: BulkAction) async throws {
        let (store, services, feed, articles) = try await fixture()
        try await store.setStatus(articles.map(\.id), field: action.field, value: !action.value)
        let session = ReaderSession(services: services)
        await session.reload()
        session.timelineSelection = [.article(articles[0].id), .article(articles[1].id)]
        let target = session.statusTarget(for: session.timelineSelection)
        session.timelineSelection = [.article(articles[2].id)]
        await session.setStatus(target, field: action.field, value: action.value)
        let saved = try await store.articles(ArticleQuery())
        for article in saved {
            let value = action.field == .read ? article.read : article.starred
            #expect(value == (article.id == articles[2].id ? !action.value : action.value))
        }
        let pending = try await store.pendingChanges(accountID: feed.id.accountID)
        #expect(pending.count == 3)
        #expect(session.errorMessage == nil)
    }

    @Test("Mixed digest selection freezes source revisions, deduplicates keys and rejects star actions")
    func mixedSelectionPreservesDigestRevision() async throws {
        let (store, services, feed, articles) = try await fixture()
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest))
        let original = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                      sections: [], sources: [articles[0].id])
        try await store.saveDigest(original)
        let session = ReaderSession(services: services)
        session.sidebarSelection = feed.id.id
        await session.reload()
        session.timelineSelection = [.digest(original.id), .article(articles[0].id)]
        var updated = original
        updated.revision = UUID()
        updated.sources = articles.map(\.id)
        try await store.saveDigest(updated)
        await session.reload()
        session.timelineSelection.insert(.article(articles[1].id))
        let target = session.statusTarget(for: session.timelineSelection)
        #expect(Set(target.keys) == Set([articles[0].id, articles[1].id]))
        #expect(target.keys.count == 2)
        #expect(!target.canStar)
        await session.setStatus(target, field: .starred, value: true)
        #expect(try await store.pendingChanges(accountID: feed.id.accountID).isEmpty)
        await session.setStatus(target, field: .read, value: true)
        #expect(try await store.articles(ArticleQuery(unreadOnly: true)).map(\.id) == [articles[2].id])
        session.timelineSelection = [.digest(original.id)]
        #expect(session.selectedDigest?.revision == original.revision)
        session.openLatestDigest()
        #expect(session.statusTarget(for: session.timelineSelection).keys.count == 3)
    }

    @Test("Preparing selection actions performs no repository lookups")
    func selectionActionPreparationDoesNotQueryArticles() async throws {
        let (store, _, feed, articles) = try await fixture()
        let lookups = SessionLookupCount()
        let repository = ScriptedRepository(base: store, articleLookup: { key in
            await lookups.record()
            return try await store.article(key)
        }, query: { query in
            await lookups.record()
            return try await store.articles(query)
        })
        let session = ReaderSession(services: ReaderServices(repository: repository))
        await session.reload()
        let before = await lookups.count
        session.timelineSelection = [.article(articles[0].id), .article(articles[1].id)]
        for _ in 0..<20 {
            let target = session.statusTarget(for: session.timelineSelection)
            #expect(target.keys.count == 2)
            #expect(target.canStar)
            #expect(session.feedForStatusAction(session.timelineSelection)?.id == feed.id)
        }
        #expect(session.feedForStatusAction([]) == nil)
        #expect(session.feedForStatusAction([.digest("missing")]) == nil)
        #expect(await lookups.count == before)
    }

    enum DetailOutcome: CaseIterable, Sendable { case newerSuccess, olderError, cancelled, selectionRoundTrip }

    @Test("Late detail work cannot replace a newer result or revive a cancelled selection",
          .timeLimit(.minutes(1)), arguments: DetailOutcome.allCases)
    func lateDetailWorkCannotReplaceCurrentState(outcome: DetailOutcome) async throws {
        let (store, _, _, articles) = try await fixture()
        let gate = RequestGate()
        let replies = DetailReplies(original: articles[0], gate: gate, olderError: outcome == .olderError)
        let repository = ScriptedRepository(base: store, articleLookup: { try await replies.article($0) },
                                              query: { try await store.articles($0) })
        let session = ReaderSession(services: ReaderServices(repository: repository))
        session.selection = .article(articles[0].id)
        let old = Task { await session.loadSelectedArticle() }
        defer { old.cancel(); Task { await gate.open() } }
        try await gate.waitUntilEntered()
        switch outcome {
        case .newerSuccess, .olderError:
            await session.loadSelectedArticle()
            #expect(session.selectedArticle?.title == "Newest detail")
        case .cancelled:
            old.cancel()
        case .selectionRoundTrip:
            session.selection = .article(articles[1].id)
            session.selection = .article(articles[0].id)
        }
        await gate.open()
        await old.value
        if outcome == .newerSuccess || outcome == .olderError {
            #expect(session.selectedArticle?.title == "Newest detail")
        } else {
            #expect(session.detailArticle == nil)
            #expect(session.selectedArticle == nil)
        }
        #expect(session.errorMessage == nil)
    }

    @Test("Overlapping database pages do not produce duplicate rows") func overlappingDatabasePagesDoNotProduceDuplicateRows() async throws {
        let (store, _, _, _) = try await fixture(count: 450)
        let repository = ScriptedRepository(base: store) { query in
            var page = try await store.articles(query)
            if query.offset == 0, let first = page.first { page[page.count - 1] = first }
            return page
        }
        let session = ReaderSession(services: ReaderServices(repository: repository))
        await session.reload()
        await session.loadMore()
        #expect(session.articles.count == 400)
        #expect(Set(session.rows.map(\.id)).count == session.rows.count)
    }

    @Test("Refresh replaces the displayed digest revision only on request") func refreshReplacesTheDisplayedDigestRevisionOnlyOnRequest() async throws {
        let (store, services, feed, articles) = try await fixture()
        let original = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna", sections: [], sources: [articles[0].id])
        try await store.saveDigest(original)
        let session = ReaderSession(services: services)
        await session.reload()
        session.selection = .digest(original.id)
        var updated = original
        updated.revision = UUID()
        updated.sources = articles.map(\.id)
        try await store.saveDigest(updated)
        await session.reload()
        #expect(session.selectedDigest?.revision == original.revision)
        #expect(session.selectedDigest?.sources.count == 1)
        session.openLatestDigest()
        #expect(session.selectedDigest?.revision == updated.revision)
    }

    @Test("Bundled originals do not displace normal feeds from the first page") func bundledOriginalsDoNotDisplaceNormalFeedsFromTheFirstPage() async throws {
        let (store, services, feed, articles) = try await fixture(count: 251)
        let normal = FeedSnapshot(id: FeedKey(accountID: feed.id.accountID, remoteID: "normal"), title: "Normal", url: feed.url)
        var oldest = articles[0]
        oldest.feedID = normal.id.remoteID
        var input = articles
        input[0] = oldest
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: [feed, normal], folders: [], articles: input,
                                                    unreadIDs: Set(input.map(\.id.remoteID)), starredIDs: []))
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest))
        try await store.saveDigest(DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna", sections: [],
                                                  sources: Array(articles.dropFirst().map(\.id))))
        let session = ReaderSession(services: services)
        await session.reload()
        #expect(session.rows.contains { $0.id == .article(oldest.id) })
        #expect(session.rows.count == 2)
    }
}

private actor SessionLookupCount {
    private(set) var count = 0
    func record() { count += 1 }
}

private actor QueryGate {
    let accountID: UUID
    private var gates: [String: RequestGate] = [:]

    init(accountID: UUID) { self.accountID = accountID }

    func response(_ search: String) async throws -> [ArticleSnapshot] {
        try await gate(for: search).pause()
        return [ArticleSnapshot(id: ArticleKey(accountID: accountID, remoteID: search),
                                feedID: "feed/1", title: search)]
    }

    func waitUntilStarted(_ search: String) async throws {
        try await gate(for: search).waitUntilEntered()
    }

    func release(_ search: String) async { await gate(for: search).open() }

    private func gate(for search: String) -> RequestGate {
        if let gate = gates[search] { return gate }
        let gate = RequestGate()
        gates[search] = gate
        return gate
    }
}

private actor DetailReplies {
    let original: ArticleSnapshot
    let gate: RequestGate
    let olderError: Bool
    private var calls = 0

    init(original: ArticleSnapshot, gate: RequestGate, olderError: Bool) {
        self.original = original; self.gate = gate; self.olderError = olderError
    }

    func article(_ key: ArticleKey) async throws -> ArticleSnapshot? {
        calls += 1
        if calls == 1 {
            // A store query already in flight can finish after its caller is cancelled.
            let gate = gate
            try await Task.detached { try await gate.pause() }.value
            if olderError { throw ReaderError.server(500) }
            return original
        }
        var newest = original
        newest.title = "Newest detail"
        return newest
    }
}

private actor ScriptedRepository: ReaderRepository {
    let base: any ReaderRepository
    let query: @Sendable (ArticleQuery) async throws -> [ArticleSnapshot]
    let articleLookup: (@Sendable (ArticleKey) async throws -> ArticleSnapshot?)?
    init(base: any ReaderRepository, articleLookup: (@Sendable (ArticleKey) async throws -> ArticleSnapshot?)? = nil,
         query: @escaping @Sendable (ArticleQuery) async throws -> [ArticleSnapshot]) {
        self.base = base; self.query = query; self.articleLookup = articleLookup
    }
    func accounts() async throws -> [ReaderAccount] { try await base.accounts() }
    func saveAccount(_ account: ReaderAccount) async throws { try await base.saveAccount(account) }
    func feeds() async throws -> [FeedSnapshot] { try await base.feeds() }
    func folders() async throws -> [FolderSnapshot] { try await base.folders() }
    func articles(_ query: ArticleQuery) async throws -> [ArticleSnapshot] { try await self.query(query) }
    func article(_ key: ArticleKey) async throws -> ArticleSnapshot? {
        if let articleLookup { return try await articleLookup(key) }
        return try await base.article(key)
    }
    func applyRefresh(_ snapshot: RefreshSnapshot) async throws { try await base.applyRefresh(snapshot) }
    func setStatus(_ keys: [ArticleKey], field: StatusField, value: Bool) async throws { try await base.setStatus(keys, field: field, value: value) }
    func pendingChanges(accountID: UUID) async throws -> [PendingChange] { try await base.pendingChanges(accountID: accountID) }
    func acknowledge(_ changes: [PendingChange]) async throws { try await base.acknowledge(changes) }
    func preferences() async throws -> [FeedPreferences] { try await base.preferences() }
    func savePreferences(_ preferences: FeedPreferences) async throws { try await base.savePreferences(preferences) }
    func digests() async throws -> [DigestSnapshot] { try await base.digests() }
    func saveDigest(_ digest: DigestSnapshot) async throws { try await base.saveDigest(digest) }
    func updateContent(_ key: ArticleKey, html: String, text: String) async throws { try await base.updateContent(key, html: html, text: text) }
}
