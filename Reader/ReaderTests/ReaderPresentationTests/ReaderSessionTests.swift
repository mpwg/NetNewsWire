import Foundation
import Testing
import ReaderDomain
import ReaderPersistence
@testable import ReaderUI

@MainActor
struct ReaderSessionTests {

    @Test("Startup publishes valid summaries or warned originals and withholds invalid cached claims",
          arguments: [0, 1, 2, 3, 4, 5, 6, 7, 8], ["all", "unread"])
    func invalidCachedClaimsCannotHideOriginals(kind: Int, sidebar: String) async throws {
        let (store, services, feed, articles) = try await fixture()
        let keys = articles.map(\.id)
        var digest = DigestSnapshot(id: "cached", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                    sections: [DigestSection(title: "Summary", text: "Sourced content", sources: keys)], sources: keys)
        switch kind {
        case 1:
            digest.sections = [DigestSection(title: "Other original articles", text: "", sources: keys)]
            digest.warning = "Summary unavailable."
        case 2: digest.sections[0].title = " \t"
        case 3: digest.sections[0].text = " \n\t"
        case 4: digest.sections[0].sources = [ArticleKey(accountID: feed.id.accountID, remoteID: "not-stored")]
        case 5: digest.sections[0].sources = [keys[0]]
        case 6: digest.sections = []
        case 7: digest.sections[0].title = "https://invented.test"
        case 8: digest.sections[0].text = "HTTPS://invented.test"
        default: break
        }
        try await store.saveDigest(digest)
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest))
        let session = ReaderSession(services: services)
        session.sidebarSelection = sidebar
        await session.reload()
        if kind <= 1 {
            #expect(session.digests.map(\.id) == [digest.id])
            #expect(session.rows.map(\.id) == [.digest(digest.id)])
            #expect(session.errorMessage == nil)
        } else {
            #expect(session.digests.isEmpty)
            #expect(Set(session.rows.map(\.id)) == Set(keys.map(TimelineSelection.article)))
            #expect(session.errorMessage != nil)
        }
        #expect(try await store.articles(ArticleQuery(unreadOnly: true)).count == articles.count)
        #expect(try await store.pendingChanges(accountID: feed.id.accountID).isEmpty)
    }
    @Test("Canonical refresh keeps timeline, detail and search caches consistent",
          .timeLimit(.minutes(1)), arguments: [false, true], [false, true])
    func canonicalRefreshPublishesOneWholeVersion(existingArticle: Bool, reversedVersions: Bool) async throws {
        let (store, services, feed, originals) = try await fixture(count: existingArticle ? 1 : 0)
        let key = ArticleKey(accountID: feed.id.accountID, remoteID: "0")
        let session = ReaderSession(services: services)
        if let original = originals.first {
            try await store.updateContent(original.id, html: "<p>Prior extracted content</p>", text: "Prior extracted content")
        }
        await session.reload()
        session.selection = .article(key)
        await session.loadSelectedArticle()
        if existingArticle {
            #expect(session.selectedArticle?.text == "Prior extracted content")
            #expect(session.detailArticle?.text == "Prior extracted content")
        } else {
            #expect(session.articles.isEmpty)
            #expect(session.selectedArticle == nil)
        }

        let first = ArticleSnapshot(id: key, feedID: feed.id.remoteID, title: "B", html: "<p>Alpha HTML</p>",
                                    text: "Alpha body", url: URL(string: "https://example.invalid/alpha"),
                                    datePublished: Date(timeIntervalSince1970: 120),
                                    dateArrived: Date(timeIntervalSince1970: 200), read: true)
        let second = ArticleSnapshot(id: key, feedID: feed.id.remoteID, title: "A", html: "<p>Beta HTML</p>",
                                     text: "Beta body", url: URL(string: "https://example.invalid/beta"),
                                     datePublished: Date(timeIntervalSince1970: 130),
                                     dateArrived: Date(timeIntervalSince1970: 300), read: true)
        let versions = reversedVersions ? [second, first] : [first, second]
        var expected = try #require(versions.last)
        expected.dateArrived = originals.first?.dateArrived ?? expected.dateArrived
        expected.read = false
        expected.starred = true
        let stream = await store.changes()
        var revisions = stream.makeAsyncIterator()
        let before = try #require(await revisions.next())
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: [feed], folders: [],
                                                    articles: versions, unreadIDs: [key.remoteID], starredIDs: [key.remoteID]))
        #expect(await revisions.next() == before + 1)
        await session.reload()
        session.selection = .article(key)
        await session.loadSelectedArticle()
        #expect(session.articles == [expected])
        #expect(session.selectedArticle == expected)
        #expect(session.detailArticle == expected)
        #expect(session.rows.count == 1)
        #expect(session.rows.first?.id == .article(key))
        #expect(session.rows.first?.title == expected.title)
        #expect(session.rows.first?.subtitle == expected.text)
        #expect(session.rows.first?.date == expected.datePublished)
        #expect(session.rows.first?.unread == true)
        #expect(session.rows.first?.starred == true)
        session.search = expected.text
        await session.reload(resetLimit: true)
        #expect(session.articles == [expected])
        #expect(session.rows.map(\.title) == [expected.title])
        session.search = try #require(versions.first).text
        await session.reload(resetLimit: true)
        #expect(session.articles.isEmpty)
        #expect(session.rows.isEmpty)
        #expect(session.selectedArticle == nil)
        #expect(session.detailArticle == nil)
        #expect(session.errorMessage == nil)
    }

    @Test("Starred presentation follows authoritative orphan read state and clears removed selection",
          arguments: [false, true], [false, true])
    func starredPresentationRetainsUnsubscribedOriginals(keepsOtherSubscription: Bool, serverKeepsUnread: Bool) async throws {
        let (store, services, feed, originals) = try await fixture()
        let otherFeed = FeedSnapshot(id: FeedKey(accountID: feed.id.accountID, remoteID: "feed/remaining"),
                                     title: "Still subscribed", url: feed.url)
        var otherArticle = originals[2]
        otherArticle.feedID = otherFeed.id.remoteID
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: [feed, otherFeed], folders: [],
                                                    articles: [originals[0], originals[1], otherArticle],
                                                    unreadIDs: Set(originals.map(\.id.remoteID)),
                                                    starredIDs: [originals[0].id.remoteID]))
        let session = ReaderSession(services: services)
        await session.reload()
        #expect(session.articles.count == 3)
        session.selection = .article(originals[1].id)
        await session.loadSelectedArticle()
        #expect(session.selectedArticle?.id == originals[1].id)
        let remainingFeeds = keepsOtherSubscription ? [otherFeed] : []
        let remoteUnread: Set<String> = serverKeepsUnread ? [originals[0].id.remoteID, otherArticle.id.remoteID] : [otherArticle.id.remoteID]
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: remainingFeeds, folders: [],
                                                    articles: [], unreadIDs: remoteUnread, starredIDs: []))
        await session.reload()
        let expectedKeys = keepsOtherSubscription ? [originals[0].id, otherArticle.id] : [originals[0].id]
        #expect(Set(session.articles.map(\.id)) == Set(expectedKeys))
        #expect(Set(session.rows.map(\.id)) == Set(expectedKeys.map(TimelineSelection.article)))
        #expect(session.selection == nil)
        #expect(session.detailArticle == nil)
        session.sidebarSelection = "starred"
        await session.reload(resetLimit: true)
        #expect(session.feeds == remainingFeeds)
        #expect(session.articles.map(\.id) == [originals[0].id])
        #expect(session.rows.map(\.id) == [.article(originals[0].id)])
        #expect(session.rows.first?.starred == true)
        #expect(session.rows.first?.unread == serverKeepsUnread)
        #expect(session.unreadCounts.byFeed[feed.id, default: 0] == (serverKeepsUnread ? 1 : 0))
        #expect(session.unreadCounts.total == (serverKeepsUnread ? 1 : 0) + (keepsOtherSubscription ? 1 : 0))
        session.selection = .article(originals[0].id)
        await session.loadSelectedArticle()
        let retained = try #require(try await store.article(originals[0].id))
        #expect(session.selectedArticle == retained)
        #expect(session.detailArticle == retained)
        #expect(retained.starred)
        #expect(retained.read == !serverKeepsUnread)
        #expect(retained.text == originals[0].text)
        session.sidebarSelection = "unread"
        await session.reload(resetLimit: true)
        let expectedUnread = (serverKeepsUnread ? [originals[0].id] : []) + (keepsOtherSubscription ? [otherArticle.id] : [])
        #expect(Set(session.articles.map(\.id)) == Set(expectedUnread))
        #expect(Set(session.rows.map(\.id)) == Set(expectedUnread.map(TimelineSelection.article)))
        #expect(try await store.pendingChanges(accountID: feed.id.accountID).isEmpty)
        #expect(session.errorMessage == nil)
    }

    @Test("Unread totals remain complete across pages, search, accounts and pure deletion",
          .timeLimit(.minutes(1)), arguments: [false, true])
    func unreadCountsFollowCommittedDeletion(searchHasNoResults: Bool) async throws {
        let (store, services, originalFeed, originals) = try await fixture(count: 251)
        var feed = originalFeed
        feed.folderIDs = ["folder", "folder"]
        let folder = FolderSnapshot(accountID: feed.id.accountID, remoteID: "folder", title: "Folder")
        let remaining = FeedSnapshot(id: FeedKey(accountID: feed.id.accountID, remoteID: "feed/remaining"),
                                     title: "Remaining", url: feed.url, folderIDs: ["folder"])
        let other = ArticleSnapshot(id: ArticleKey(accountID: feed.id.accountID, remoteID: "other"),
                                    feedID: remaining.id.remoteID, title: "Other")
        let allUnread = Set(originals.map(\.id.remoteID)).union([other.id.remoteID])
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: [feed, remaining],
                                                    folders: [folder], articles: [other], unreadIDs: allUnread, starredIDs: []))
        let foreign = ReaderAccount(serverURL: feed.url, username: "foreign")
        try await store.saveAccount(foreign)
        let foreignFeed = FeedSnapshot(id: FeedKey(accountID: foreign.id, remoteID: feed.id.remoteID),
                                       title: "Foreign", url: feed.url, folderIDs: ["folder"])
        let foreignFolder = FolderSnapshot(accountID: foreign.id, remoteID: "folder", title: "Foreign folder")
        let foreignArticle = ArticleSnapshot(id: ArticleKey(accountID: foreign.id, remoteID: "0"),
                                             feedID: foreignFeed.id.remoteID, title: "Foreign")
        try await store.applyRefresh(RefreshSnapshot(accountID: foreign.id, feeds: [foreignFeed], folders: [foreignFolder],
                                                    articles: [foreignArticle], unreadIDs: ["0"], starredIDs: []))
        let session = ReaderSession(services: services)
        session.sidebarSelection = "unread"
        if searchHasNoResults { session.search = "no matching fixture" }
        await session.reload()
        #expect(session.articles.count == (searchHasNoResults ? 0 : 200))
        #expect(session.unreadCounts.byFeed == [feed.id: 251, remaining.id: 1, foreignFeed.id: 1])
        #expect(session.unreadCounts.byFolder == [folder.id: 252, foreignFolder.id: 1])
        #expect(session.unreadCounts.byAccount == [feed.id.accountID: 252, foreign.id: 1])
        #expect(session.unreadCounts.total == 253)
        // Keep all status IDs unchanged: deleting the subscription alone removes its unprotected originals.
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: [remaining], folders: [folder],
                                                    articles: [], unreadIDs: allUnread, starredIDs: []))
        await session.reload()
        #expect(session.articles.count == (searchHasNoResults ? 0 : 2))
        #expect(session.rows.count == (searchHasNoResults ? 0 : 2))
        #expect(Set(session.articles.map(\.id)) == (searchHasNoResults ? [] : [other.id, foreignArticle.id]))
        #expect(Set(session.feeds.map(\.id)) == [remaining.id, foreignFeed.id])
        #expect(session.unreadCounts.byFeed == [remaining.id: 1, foreignFeed.id: 1])
        #expect(session.unreadCounts.byFolder == [folder.id: 1, foreignFolder.id: 1])
        #expect(session.unreadCounts.byAccount == [feed.id.accountID: 1, foreign.id: 1])
        #expect(session.unreadCounts.total == 2)
        #expect(session.errorMessage == nil)
        #expect(try await store.pendingChanges(accountID: feed.id.accountID).isEmpty)
    }

    @Test("A commit during a count read cannot publish mixed data or an obsolete error",
          .timeLimit(.minutes(1)), arguments: [false, true])
    func unreadCountsRejectMixedRevisions(failingRead: Bool) async throws {
        let (store, _, feed, originals) = try await fixture()
        let remaining = FeedSnapshot(id: FeedKey(accountID: feed.id.accountID, remoteID: "feed/remaining"),
                                     title: "Remaining", url: feed.url)
        let unread = Set(originals.map(\.id.remoteID))
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: [feed, remaining],
                                                    folders: [], articles: [], unreadIDs: unread, starredIDs: []))
        let gate = RequestGate()
        let replies = UnreadCountReplies(store: store, gate: gate)
        let repository = ScriptedRepository(base: store, countsLookup: { try await replies.counts() },
                                            query: { try await store.articles($0) })
        let session = ReaderSession(services: ReaderServices(repository: repository))
        await session.reload()
        let previousArticles = session.articles
        let previousRows = session.rows
        let previousFeeds = session.feeds
        let previousCounts = session.unreadCounts
        #expect(previousCounts.total == originals.count)
        await replies.holdNext(failing: failingRead)
        let request = Task { await session.reload() }
        defer { request.cancel(); Task { await gate.open() } }
        try await gate.waitUntilEntered()
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: [remaining],
                                                    folders: [], articles: [], unreadIDs: unread, starredIDs: []))
        await gate.open()
        await request.value
        #expect(session.articles == previousArticles)
        #expect(session.rows == previousRows)
        #expect(session.feeds == previousFeeds)
        #expect(session.unreadCounts == previousCounts)
        #expect(session.errorMessage == nil)
        #expect(!session.loading)
        await session.reload()
        #expect(session.articles.isEmpty)
        #expect(session.rows.isEmpty)
        #expect(session.feeds == [remaining])
        #expect(session.unreadCounts.total == 0)
        #expect(session.errorMessage == nil)
    }

    @Test("Committed deletion automatically refreshes timeline and complete counters",
          .timeLimit(.minutes(1)))
    func observedDeletionRefreshesTimelineAndCounts() async throws {
        let (store, _, feed, originals) = try await fixture()
        let gate = RequestGate()
        let replies = UnreadCountReplies(store: store, gate: gate)
        let repository = ScriptedRepository(base: store, countsLookup: { try await replies.counts() },
                                            query: { try await store.articles($0) })
        let session = ReaderSession(services: ReaderServices(repository: repository))
        await session.reload()
        #expect(session.unreadCounts.total == originals.count)
        await replies.holdNext(failing: false)
        let observer = Task { await session.observeChanges() }
        defer { observer.cancel(); Task { await gate.open() } }
        try await gate.waitUntilEntered()
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: [], folders: [],
                                                    articles: [], unreadIDs: Set(originals.map(\.id.remoteID)), starredIDs: []))
        await gate.open()
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while session.unreadCounts.total != 0 || !session.rows.isEmpty || session.loading {
            try Task.checkCancellation()
            try #require(ContinuousClock.now < deadline, "The committed revision must refresh the observed session.")
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(session.articles.isEmpty)
        #expect(session.feeds.isEmpty)
        #expect(session.unreadCounts.byFeed.isEmpty)
        #expect(session.unreadCounts.byFolder.isEmpty)
        #expect(session.unreadCounts.byAccount.isEmpty)
        #expect(session.errorMessage == nil)
    }

    private func summarySections(_ keys: [ArticleKey]) -> [DigestSection] {
        [DigestSection(title: "Fixture summary", text: "Sourced fixture content", sources: keys)]
    }

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

    @Test("Sessions keep selection, search and sheets independent across query changes")
    func sessionsOwnIndependentSelectionAndSearchState() async throws {
        let (_, services, feed, articles) = try await fixture()
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
        a.selection = .article(articles[1].id)
        b.selection = .article(articles[0].id)
        a.showingAccount = true
        #expect(!b.showingAccount)

        b.search = "Article 2"
        await b.reload()
        #expect(b.selection == nil)
        b.selection = .article(articles[2].id)
        #expect(a.search == "Article 1")
        #expect(a.sidebarSelection == feed.id.id)
        #expect(a.selectedArticle?.id == articles[1].id)
        #expect(a.showingAccount)
        b.showingAccount = true
        a.showingAccount = false
        #expect(b.showingAccount)
        await a.reload()
        #expect(a.selectedArticle?.id == articles[1].id)

        a.search = "Article 0"
        await a.reload()
        #expect(a.selection == nil)
        #expect(a.articles.map(\.id) == [articles[0].id])
        #expect(b.search == "Article 2")
        #expect(b.sidebarSelection == "all")
        #expect(b.selectedArticle?.id == articles[2].id)
        #expect(b.articles.map(\.id) == [articles[2].id])
        #expect(b.showingAccount)
    }

    @Test("Opening a digest does not change original article status") func openingADigestDoesNotChangeOriginalArticleStatus() async throws {
        let (store, services, feed, articles) = try await fixture()
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                    sections: summarySections(articles.map(\.id)), sources: articles.map(\.id))
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
                                    sections: summarySections([articles[0].id]), sources: [articles[0].id])
        try await store.saveDigest(digest)
        let session = ReaderSession(services: services)
        await session.reload()
        #expect(session.rows.count == 3)
        #expect(session.rows.contains { $0.id == .article(articles[1].id) })
        #expect(session.rows.contains { $0.id == .article(articles[2].id) })
    }

    @Test("Sources outside the loaded page survive refresh and leave detail when the query changes", arguments: [false, true])
    func sourcesOutsideTheLoadedPageRemainAccessible(changesQuery: Bool) async throws {
        let (store, services, feed, articles) = try await fixture(count: 350)
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                    sections: summarySections(articles.map(\.id)), sources: articles.map(\.id))
        try await store.saveDigest(digest)
        let session = ReaderSession(services: services)
        await session.reload()
        #expect(session.articles.count == 200)
        await session.loadSources(digest)
        #expect(session.sourceArticles.count == 350)
        session.selection = .article(articles[0].id)
        await session.loadSelectedArticle()
        #expect(session.selectedArticle?.id == articles[0].id)
        #expect(!session.rows.contains { $0.id == .article(articles[0].id) })
        try await store.updateContent(articles[0].id, html: "<p>Updated source</p>", text: "Updated source")
        await session.reload()
        #expect(session.articles.count == 200)
        #expect(session.selection == .article(articles[0].id))
        #expect(session.selectedArticle?.text == "Updated source")
        #expect(try await store.pendingChanges(accountID: feed.id.accountID).isEmpty)
        if changesQuery {
            session.search = "Article 1"
            await session.reload(resetLimit: true)
            #expect(session.timelineSelection.isEmpty)
            #expect(session.selectedArticle == nil)
        }
    }

    @Test("Marking the displayed revision read leaves new sources unread") func markingTheDisplayedRevisionReadLeavesNewSourcesUnread() async throws {
        let (store, services, feed, articles) = try await fixture()
        let displayed = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                       sections: summarySections([articles[0].id]), sources: [articles[0].id])
        var updated = displayed
        updated.sources = articles.map(\.id)
        updated.sections = summarySections(updated.sources)
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

    private func expectOrdinaryRows(_ session: ReaderSession, _ keys: [ArticleKey], unread: Int, starred: Int) {
        #expect(session.rows.map(\.id) == keys.map { .article($0) })
        #expect(session.articles.map(\.id) == keys)
        #expect(session.rows.filter(\.unread).count == unread)
        #expect(session.rows.filter(\.starred).count == starred)
        #expect(!session.loading)
        #expect(!session.canLoadMore)
    }

    @Test("Shared status actions keep unread, stars, normalized search, selection and counts coherent")
    func sharedActionsKeepOrdinaryResultsConsistent() async throws {
        let (store, services, feed, articles) = try await fixture(count: 6)
        let session = ReaderSession(services: services)
        let all = articles.reversed().map(\.id)
        let chosen: Set<TimelineSelection> = [.article(articles[0].id), .article(articles[1].id)]
        session.sidebarSelection = "unread"
        await session.reload()
        expectOrdinaryRows(session, all, unread: 6, starred: 0)
        session.timelineSelection = chosen
        let target = session.statusTarget(for: chosen)
        await session.setStatus(target, field: .starred, value: true)
        expectOrdinaryRows(session, all, unread: 6, starred: 2)
        #expect(session.timelineSelection == chosen)

        session.sidebarSelection = "starred"
        await session.reload()
        expectOrdinaryRows(session, [articles[1].id, articles[0].id], unread: 2, starred: 2)
        #expect(session.timelineSelection.isEmpty)
        session.search = "  ÁRTICLE 1  "
        await session.reload()
        expectOrdinaryRows(session, [articles[1].id], unread: 1, starred: 1)
        session.selection = .article(articles[1].id)
        await session.setStatus(session.statusTarget(for: session.timelineSelection), field: .read, value: true)
        expectOrdinaryRows(session, [articles[1].id], unread: 0, starred: 1)
        #expect(session.selection == .article(articles[1].id))

        session.sidebarSelection = "unread"
        await session.reload()
        expectOrdinaryRows(session, [], unread: 0, starred: 0)
        #expect(session.timelineSelection.isEmpty)
        session.search = ""
        await session.reload()
        expectOrdinaryRows(session, [articles[5].id, articles[4].id, articles[3].id, articles[2].id, articles[0].id], unread: 5, starred: 1)
        session.selection = .article(articles[0].id)
        await session.setStatus(session.statusTarget(for: session.timelineSelection), field: .read, value: true)
        expectOrdinaryRows(session, Array(all.prefix(4)), unread: 4, starred: 0)
        #expect(session.timelineSelection.isEmpty)

        session.sidebarSelection = "all"
        await session.reload()
        expectOrdinaryRows(session, all, unread: 4, starred: 2)
        session.timelineSelection = chosen
        await session.setStatus(target, field: .starred, value: false)
        await session.setStatus(target, field: .read, value: false)
        expectOrdinaryRows(session, all, unread: 6, starred: 0)
        #expect(session.timelineSelection == chosen)
        session.sidebarSelection = "starred"
        await session.reload()
        expectOrdinaryRows(session, [], unread: 0, starred: 0)
        #expect(session.timelineSelection.isEmpty)
        let pending = try await store.pendingChanges(accountID: feed.id.accountID)
        #expect(pending.count == 4)
        #expect(pending.allSatisfy { !$0.value })
        #expect(session.errorMessage == nil)
    }

    @Test("Digest badges and visible/original counts follow source status, search and stars")
    func sharedActionsKeepDigestResultsConsistent() async throws {
        let (store, services, feed, articles) = try await fixture()
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest))
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna",
                                    sections: summarySections([articles[0].id, articles[1].id]), sources: [articles[0].id, articles[1].id])
        try await store.saveDigest(digest)
        let session = ReaderSession(services: services)
        session.sidebarSelection = "all"
        await session.reload()
        #expect(session.rows.map(\.id) == [.digest(digest.id), .article(articles[2].id)])
        #expect(session.articles.map(\.id) == [articles[2].id])
        #expect(session.rows.filter(\.unread).count == 2)
        session.selection = .digest(digest.id)
        await session.setStatus(session.statusTarget(for: session.timelineSelection), field: .read, value: true)
        #expect(session.rows.count == 2)
        #expect(session.articles.count == 1)
        #expect(session.rows.filter(\.unread).count == 1)
        #expect(session.digestUnread[digest.id] != true)

        session.sidebarSelection = "unread"
        await session.reload()
        expectOrdinaryRows(session, [articles[2].id], unread: 1, starred: 0)
        #expect(session.timelineSelection.isEmpty)
        session.sidebarSelection = "all"
        session.search = "Content 0"
        await session.reload()
        expectOrdinaryRows(session, [articles[0].id], unread: 0, starred: 0)
        session.selection = .article(articles[0].id)
        await session.setStatus([articles[0].id], field: .starred, value: true)
        expectOrdinaryRows(session, [articles[0].id], unread: 0, starred: 1)
        session.sidebarSelection = "starred"
        session.search = ""
        await session.reload()
        expectOrdinaryRows(session, [articles[0].id], unread: 0, starred: 1)
        await session.setStatus([articles[0].id], field: .read, value: false)

        session.sidebarSelection = "unread"
        await session.reload()
        #expect(session.rows.map(\.id) == [.digest(digest.id), .article(articles[2].id)])
        #expect(session.articles.map(\.id) == [articles[2].id])
        #expect(session.rows.filter(\.unread).count == 2)
        #expect(session.digestUnread[digest.id] == true)
        #expect(!session.canLoadMore)
        #expect(!session.loading)
        #expect(session.errorMessage == nil)
    }

    enum QueryErrorOutcome: CaseIterable, Sendable { case current, cancelled, changedIdentity, replaced }

    @Test("Only the current uncancelled query can publish an ordinary error",
          .timeLimit(.minutes(1)), arguments: QueryErrorOutcome.allCases)
    func queryErrorsRespectCurrentRequest(outcome: QueryErrorOutcome) async throws {
        let (store, _, _, _) = try await fixture()
        let gate = RequestGate()
        let repository = ScriptedRepository(base: store) { query in
            if query.search == "failed" {
                // Already-running store work can return an ordinary error after caller cancellation.
                try await Task.detached { try await gate.pause() }.value
                throw ReaderError.server(500)
            }
            return try await store.articles(query)
        }
        let session = ReaderSession(services: ReaderServices(repository: repository))
        await session.reload()
        let previousRows = session.rows
        session.search = "failed"
        let request = Task { await session.reload() }
        defer { request.cancel(); Task { await gate.open() } }
        try await gate.waitUntilEntered()
        switch outcome {
        case .current: break
        case .cancelled: request.cancel()
        case .changedIdentity: session.search = "changed"
        case .replaced:
            session.search = ""
            await session.reload()
        }
        await gate.open()
        await request.value
        #expect((session.errorMessage != nil) == (outcome == .current))
        #expect(session.rows == previousRows)
        #expect(!session.loading)
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
                                      sections: summarySections([articles[0].id]), sources: [articles[0].id])
        try await store.saveDigest(original)
        let session = ReaderSession(services: services)
        session.sidebarSelection = feed.id.id
        await session.reload()
        session.timelineSelection = [.digest(original.id), .article(articles[0].id)]
        var updated = original
        updated.revision = UUID()
        updated.sources = articles.map(\.id)
        updated.sections = summarySections(updated.sources)
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
        let original = DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna", sections: summarySections([articles[0].id]), sources: [articles[0].id])
        try await store.saveDigest(original)
        let session = ReaderSession(services: services)
        await session.reload()
        session.selection = .digest(original.id)
        var updated = original
        updated.revision = UUID()
        updated.sources = articles.map(\.id)
        updated.sections = summarySections(updated.sources)
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
        try await store.saveDigest(DigestSnapshot(id: "day", feed: feed.id, day: Date(), timeZoneID: "Europe/Vienna", sections: summarySections(Array(articles.dropFirst().map(\.id))),
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

private actor UnreadCountReplies {
    let store: ReaderStore
    let gate: RequestGate
    private var nextFailure: Bool?

    init(store: ReaderStore, gate: RequestGate) { self.store = store; self.gate = gate }
    func holdNext(failing: Bool) { nextFailure = failing }
    func counts() async throws -> [FeedKey: Int] {
        if let failing = nextFailure {
            nextFailure = nil
            try await gate.pause()
            if failing { throw ReaderError.server(500) }
        }
        return try await store.unreadCounts()
    }
}

private actor ScriptedRepository: ReaderRepository {
    let base: any ReaderRepository
    let query: @Sendable (ArticleQuery) async throws -> [ArticleSnapshot]
    let articleLookup: (@Sendable (ArticleKey) async throws -> ArticleSnapshot?)?
    let countsLookup: (@Sendable () async throws -> [FeedKey: Int])?
    init(base: any ReaderRepository, articleLookup: (@Sendable (ArticleKey) async throws -> ArticleSnapshot?)? = nil,
         countsLookup: (@Sendable () async throws -> [FeedKey: Int])? = nil,
         query: @escaping @Sendable (ArticleQuery) async throws -> [ArticleSnapshot]) {
        self.base = base; self.query = query; self.articleLookup = articleLookup; self.countsLookup = countsLookup
    }
    func accounts() async throws -> [ReaderAccount] { try await base.accounts() }
    func saveAccount(_ account: ReaderAccount) async throws { try await base.saveAccount(account) }
    func feeds() async throws -> [FeedSnapshot] { try await base.feeds() }
    func folders() async throws -> [FolderSnapshot] { try await base.folders() }
    func unreadCounts() async throws -> [FeedKey: Int] {
        if let countsLookup { return try await countsLookup() }
        return try await base.unreadCounts()
    }
    func currentRevision() async -> UInt64 { await base.currentRevision() }
    func changes() async -> AsyncStream<UInt64> { await base.changes() }
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
