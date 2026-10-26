import Foundation
import Testing
import ReaderDomain
@testable import ReaderPersistence

struct ReaderStoreTests {
    private let accountID = UUID()
    private let fixtureURL: URL

    init() throws {
        fixtureURL = try #require(URL(string: "https://example.com/feed"))
    }

    private var feed: FeedSnapshot {
        FeedSnapshot(id: FeedKey(accountID: accountID, remoteID: "feed/1"), title: "News",
                     url: fixtureURL)
    }

    private func article(_ id: String = "1", title: String = "Title", text: String = "Text",
                         read: Bool = false, starred: Bool = false, arrived: Date = Date(timeIntervalSince1970: 100)) -> ArticleSnapshot {
        ArticleSnapshot(id: ArticleKey(accountID: accountID, remoteID: id), feedID: feed.id.remoteID,
                        title: title, text: text, dateArrived: arrived, read: read, starred: starred)
    }

    private func refresh(articles: [ArticleSnapshot], feeds: [FeedSnapshot]? = nil,
                         folders: [FolderSnapshot] = [], unread: Set<String> = ["1"],
                         starred: Set<String> = []) -> RefreshSnapshot {
        RefreshSnapshot(accountID: accountID, feeds: feeds ?? [feed], folders: folders,
                        articles: articles, unreadIDs: unread, starredIDs: starred)
    }

    @Test("Unread totals include every page and preserve account isolation", .timeLimit(.minutes(1)))
    func unreadCountsStayCompleteAcrossPagesAndAccounts() async throws {
        let store = try ReaderStore(inMemory: true)
        #expect(try await store.unreadCounts().isEmpty)
        let secondFeed = FeedSnapshot(id: FeedKey(accountID: accountID, remoteID: "feed/2"),
                                      title: "Second feed", url: fixtureURL)
        let firstArticles = (0..<1_005).map { article(String($0)) }
        let secondArticles = (0..<200).map { index in
            ArticleSnapshot(id: ArticleKey(accountID: accountID, remoteID: "second/\(index)"),
                            feedID: secondFeed.id.remoteID, title: "Second article")
        }
        let readArticles = (0..<5).map { article("read/\($0)") }
        let unread = Set((firstArticles + secondArticles).map(\.id.remoteID))
        try await store.applyRefresh(refresh(articles: firstArticles + secondArticles + readArticles,
                                             feeds: [feed, secondFeed], unread: unread))
        let foreignAccountID = UUID()
        let foreignFeed = FeedSnapshot(id: FeedKey(accountID: foreignAccountID, remoteID: feed.id.remoteID),
                                       title: "Foreign feed", url: fixtureURL)
        let foreignArticles = (0..<3).map { index in
            ArticleSnapshot(id: ArticleKey(accountID: foreignAccountID, remoteID: String(index)),
                            feedID: foreignFeed.id.remoteID, title: "Foreign article")
        }
        try await store.applyRefresh(RefreshSnapshot(accountID: foreignAccountID, feeds: [foreignFeed], folders: [],
                                                    articles: foreignArticles,
                                                    unreadIDs: Set(foreignArticles.map(\.id.remoteID)), starredIDs: []))
        func currentRevision() async throws -> UInt64 {
            let stream = await store.changes()
            var iterator = stream.makeAsyncIterator()
            return try #require(await iterator.next())
        }
        let before = try await currentRevision()
        #expect(try await store.articles(ArticleQuery()).count == 200)
        #expect(try await store.articles(ArticleQuery(limit: 10_000)).count == 1_000)
        #expect(try await store.unreadCounts() == [feed.id: 1_005, secondFeed.id: 200, foreignFeed.id: 3])
        #expect(try await currentRevision() == before)
        #expect(try await store.pendingChanges(accountID: accountID).isEmpty)

        try await store.setStatus([firstArticles[0].id], field: .read, value: true)
        #expect(try await store.unreadCounts() == [feed.id: 1_004, secondFeed.id: 200, foreignFeed.id: 3])
        try await store.applyRefresh(refresh(articles: [], feeds: [feed], unread: unread))
        #expect(try await store.unreadCounts() == [feed.id: 1_004, foreignFeed.id: 3])
        #expect(try await store.article(secondArticles[0].id) == nil)
        #expect(try await currentRevision() == before + 2)
        #expect(try await store.pendingChanges(accountID: accountID).count == 1)
    }

    @Test("Cancelled unread-count queries preserve the store")
    func cancelledUnreadCountQueriesDoNotMutateState() async throws {
        let store = try ReaderStore(inMemory: true)
        try await store.applyRefresh(refresh(articles: [article()]))
        let query = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await store.unreadCounts()
        }
        await #expect(throws: CancellationError.self) { try await query.value }
        #expect(try await store.unreadCounts() == [feed.id: 1])
        #expect(try await store.pendingChanges(accountID: accountID).isEmpty)
    }

    @Test("Old acknowledgements leave newer changes pending") func oldAcknowledgementsLeaveNewerChangesPending() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        try await store.setStatus([original.id], field: .read, value: true)
        let old = try await store.pendingChanges(accountID: accountID)
        try await store.setStatus([original.id], field: .read, value: false)
        try await store.acknowledge(old)
        let pending = try await store.pendingChanges(accountID: accountID)
        #expect(pending.count == 1)
        #expect(pending.first?.value == false)
        #expect(pending.first?.id != old.first?.id)
    }

    @Test("Remote refresh protects pending changes in both status directions") func remoteRefreshProtectsPendingChangesInBothStatusDirections() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        try await store.setStatus([original.id], field: .read, value: false)
        try await store.setStatus([original.id], field: .starred, value: true)
        try await store.applyRefresh(refresh(articles: [], unread: []))
        let persisted = try #require(try await store.articles(ArticleQuery()).first)
        #expect(!persisted.read)
        #expect(persisted.starred)
        #expect(try await store.pendingChanges(accountID: accountID).count == 2)
    }

    @Test("Duplicate identities publish one whole account-bound version",
          .timeLimit(.minutes(1)), arguments: [false, true], [false, true])
    func duplicateIdentitiesSelectOneCompleteVersionAndRetainTheArrivalDate(
        existingArticle: Bool, reversedVersions: Bool
    ) async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article(title: "A", text: "Prior content")
        if existingArticle { try await store.applyRefresh(refresh(articles: [original])) }

        let foreignAccountID = UUID()
        let foreignFeed = FeedSnapshot(id: FeedKey(accountID: foreignAccountID, remoteID: feed.id.remoteID),
                                       title: "Foreign feed", url: fixtureURL)
        let foreignArticle = ArticleSnapshot(id: ArticleKey(accountID: foreignAccountID, remoteID: original.id.remoteID),
                                             feedID: foreignFeed.id.remoteID, title: "Foreign article", text: "Foreign body",
                                             dateArrived: Date(timeIntervalSince1970: 50))
        try await store.applyRefresh(RefreshSnapshot(accountID: foreignAccountID, feeds: [foreignFeed], folders: [],
                                                    articles: [foreignArticle], unreadIDs: [foreignArticle.id.remoteID],
                                                    starredIDs: []))
        var first = article(title: "B", text: "Alpha body", read: true,
                            arrived: Date(timeIntervalSince1970: 200))
        first.html = "<p>Alpha HTML</p>"
        first.url = URL(string: "https://example.invalid/alpha")
        first.datePublished = Date(timeIntervalSince1970: 120)
        var second = article(title: "A", text: "Beta body", read: true,
                             arrived: Date(timeIntervalSince1970: 300))
        second.html = "<p>Beta HTML</p>"
        second.url = URL(string: "https://example.invalid/beta")
        second.datePublished = Date(timeIntervalSince1970: 130)
        let versions = reversedVersions ? [second, first] : [first, second]
        let winner = try #require(versions.last)
        let discarded = try #require(versions.first)
        var expected = winner
        expected.dateArrived = existingArticle ? original.dateArrived : winner.dateArrived
        expected.read = false
        expected.starred = true

        let stream = await store.changes()
        var revisions = stream.makeAsyncIterator()
        var revision = try #require(await revisions.next())
        for _ in 0..<2 {
            try await store.applyRefresh(refresh(articles: versions, starred: [original.id.remoteID]))
            #expect(await revisions.next() == revision + 1)
            revision += 1
            #expect(try await store.articles(ArticleQuery(accountID: accountID)) == [expected])
            #expect(try await store.article(original.id) == expected)
            #expect(try await store.articles(ArticleQuery(accountID: accountID, search: winner.text)) == [expected])
            #expect(try await store.articles(ArticleQuery(accountID: accountID, search: discarded.text)).isEmpty)
            #expect(try await store.articles(ArticleQuery(accountID: accountID, search: original.text)).isEmpty)
            #expect(try await store.articles(ArticleQuery(accountID: accountID, starredOnly: true)) == [expected])
            #expect(try await store.article(foreignArticle.id) == foreignArticle)
            #expect(try await store.articles(ArticleQuery()).count == 2)
            #expect(try await store.pendingChanges(accountID: accountID).isEmpty)
        }
    }

    @Test("Empty authoritative folder lists remove old assignments") func emptyAuthoritativeFolderListsRemoveOldAssignments() async throws {
        let store = try ReaderStore(inMemory: true)
        let folder = FolderSnapshot(accountID: accountID, remoteID: "folder/1", title: "Folder")
        var categorized = feed
        categorized.folderIDs = [folder.remoteID]
        try await store.applyRefresh(refresh(articles: [], feeds: [categorized], folders: [folder]))
        try await store.applyRefresh(refresh(articles: [], folders: []))
        #expect(try await store.folders().isEmpty)
        #expect(try await store.feeds().first?.folderIDs.isEmpty == true)
    }

    @Test("Unsubscribing retains independent stars and follows authoritative unread membership",
          arguments: [false, true], [false, true])
    func unsubscribingRetainsStarsAndRemovesUnprotectedArticles(keepsOtherSubscription: Bool, serverKeepsUnread: Bool) async throws {
        let store = try ReaderStore(inMemory: true)
        let otherFeed = FeedSnapshot(id: FeedKey(accountID: accountID, remoteID: "feed/remaining"),
                                     title: "Still subscribed", url: fixtureURL)
        let otherArticle = ArticleSnapshot(id: ArticleKey(accountID: accountID, remoteID: "3"),
                                          feedID: otherFeed.id.remoteID, title: "Other article",
                                          dateArrived: Date(timeIntervalSince1970: 300))
        let initialFeeds = keepsOtherSubscription ? [feed, otherFeed] : [feed]
        let initialArticles = [article("1"), article("2")] + (keepsOtherSubscription ? [otherArticle] : [])
        try await store.applyRefresh(refresh(articles: initialArticles, feeds: initialFeeds,
                                             unread: Set(initialArticles.map(\.id.remoteID)), starred: ["1"]))
        #expect(try await store.pendingChanges(accountID: accountID).isEmpty)
        let subscribedFeeds = keepsOtherSubscription ? [otherFeed] : []
        let remoteUnread: Set<String> = serverKeepsUnread ? ["1", "3"] : ["3"]
        try await store.applyRefresh(refresh(articles: [], feeds: subscribedFeeds, unread: remoteUnread, starred: []))
        let remaining = try await store.articles(ArticleQuery(starredOnly: true))
        #expect(remaining.map(\.id.remoteID) == ["1"])
        #expect(remaining.first?.starred == true)
        #expect(remaining.first?.read == !serverKeepsUnread)
        #expect(try await store.articles(ArticleQuery(unreadOnly: true, starredOnly: true)).map(\.id.remoteID) ==
                (serverKeepsUnread ? ["1"] : []))
        #expect(try await store.unreadCounts()[feed.id, default: 0] == (serverKeepsUnread ? 1 : 0))
        #expect(try await store.article(article("2").id) == nil)
        #expect(Set(try await store.articles(ArticleQuery()).map(\.id.remoteID)) ==
                (keepsOtherSubscription ? ["1", "3"] : ["1"]))
        #expect(try await store.feeds() == subscribedFeeds)
        #expect(try await store.pendingChanges(accountID: accountID).isEmpty)
    }

    @Test("Pending orphan read revisions survive refresh and yield to server membership only after acknowledgement",
          .timeLimit(.minutes(1)), arguments: [false, true], [false, true])
    func orphanReadRevisionsKeepPrecedenceUntilAcknowledged(localRead: Bool, serverKeepsUnread: Bool) async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article("1")
        try await store.applyRefresh(refresh(articles: [original], unread: localRead ? ["1"] : [], starred: ["1"]))
        #expect(try await store.article(original.id)?.read == !localRead)
        let foreignID = UUID()
        let foreignFeed = FeedSnapshot(id: FeedKey(accountID: foreignID, remoteID: feed.id.remoteID),
                                       title: "Foreign", url: fixtureURL)
        let foreign = ArticleSnapshot(id: ArticleKey(accountID: foreignID, remoteID: "1"),
                                      feedID: foreignFeed.id.remoteID, title: "Foreign original",
                                      dateArrived: Date(timeIntervalSince1970: 777), starred: true)
        try await store.applyRefresh(RefreshSnapshot(accountID: foreignID, feeds: [foreignFeed], folders: [],
                                                    articles: [foreign], unreadIDs: ["1"], starredIDs: ["1"]))
        #expect(try await store.article(foreign.id) == foreign)
        try await store.setStatus([original.id], field: .read, value: localRead)
        let pending = try await store.pendingChanges(accountID: accountID)
        let revision = try #require(pending.first)
        #expect(pending.count == 1)
        #expect(revision.article == original.id && revision.field == .read && revision.value == localRead)
        let remoteUnread: Set<String> = serverKeepsUnread ? ["1"] : []
        let removal = refresh(articles: [], feeds: [], unread: remoteUnread, starred: [])
        for _ in 0..<2 {
            try await store.applyRefresh(removal)
            let retained = try #require(try await store.article(original.id))
            #expect(retained.starred && retained.read == localRead)
            #expect(try await store.pendingChanges(accountID: accountID) == pending)
            #expect(try await store.unreadCounts()[feed.id, default: 0] == (localRead ? 0 : 1))
            #expect(try await store.article(foreign.id) == foreign)
        }
        try await store.acknowledge(pending)
        #expect(try await store.pendingChanges(accountID: accountID).isEmpty)
        #expect(try await store.article(original.id)?.read == localRead)
        try await store.applyRefresh(removal)
        let retained = try #require(try await store.article(original.id))
        #expect(retained.starred && retained.read == !serverKeepsUnread)
        #expect(try await store.unreadCounts()[feed.id, default: 0] == (serverKeepsUnread ? 1 : 0))
        #expect(try await store.pendingChanges(accountID: accountID).isEmpty)
        #expect(try await store.article(foreign.id) == foreign)
        #expect(try await store.pendingChanges(accountID: foreignID).isEmpty)
    }

    @Test("Digests retain their original articles after unsubscribing") func digestsRetainTheirOriginalArticlesAfterUnsubscribing() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: original.dateArrived, timeZoneID: "Europe/Vienna",
                                    sections: [], sources: [original.id])
        try await store.saveDigest(digest)
        try await store.applyRefresh(refresh(articles: [], feeds: []))
        #expect(try await store.articles(ArticleQuery()).map(\.id) == [original.id])
    }

    @Test("Failed batch changes roll back status and outbox together") func failedBatchChangesRollBackStatusAndOutboxTogether() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        let absent = ArticleKey(accountID: accountID, remoteID: "missing")
        await #expect(throws: ReaderError.invalidResponse) {
            try await store.setStatus([original.id, absent], field: .read, value: true)
        }
        #expect(try await store.articles(ArticleQuery()).first?.read == false)
        #expect(try await store.pendingChanges(accountID: accountID).isEmpty)
    }

    @Test("Search and pagination use normalized text") func searchAndPaginationUseNormalizedText() async throws {
        let store = try ReaderStore(inMemory: true)
        try await store.applyRefresh(refresh(articles: [article("1", title: "Café"), article("2", title: "Pears")]))
        #expect(try await store.articles(ArticleQuery(search: "CAFE")).map(\.id.remoteID) == ["1"])
        #expect(try await store.articles(ArticleQuery(offset: 1, limit: 1)).map(\.id.remoteID) == ["2"])
        #expect(try await store.articles(ArticleQuery(limit: 0)).isEmpty)
    }

    @Test("Accounts articles preferences and pending changes survive reopening") func accountsArticlesPreferencesAndPendingChangesSurviveReopening() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Reader.store")
        let account = ReaderAccount(id: accountID, serverURL: try #require(URL(string: "https://example.com/api/greader.php")), username: "test")
        let original = article()
        let store = try ReaderStore(url: url)
        try await store.saveAccount(account)
        try await store.applyRefresh(refresh(articles: [original]))
        try await store.setStatus([original.id], field: .starred, value: true)
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest))
        let reopened = try ReaderStore(url: url)
        #expect(try await reopened.accounts() == [account])
        #expect(try await reopened.articles(ArticleQuery()).first?.starred == true)
        #expect(try await reopened.preferences().first?.mode == .digest)
        #expect(try await reopened.pendingChanges(accountID: accountID).count == 1)
    }

    @Test("Source facts survive a disk store reopen without changing originals or pending revisions")
    func digestSourceFactsSurviveReopening() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Reader.store")
        let original = article(text: "Example Store offers the Luma lamp for EUR 29.99. Code SAVE5 required; not valid online.")
        let store = try ReaderStore(url: url)
        try await store.applyRefresh(refresh(articles: [original]))
        try await store.setStatus([original.id], field: .starred, value: true)
        let stored = try #require(try await store.article(original.id))
        let pending = try await store.pendingChanges(accountID: accountID)
        let offer = DigestOfferFact(product: "Luma lamp", merchant: "Example Store", price: "EUR 29.99", priceSubject: "Luma lamp", conditions: ["Code SAVE5 required; not valid online."])
        let facts = DigestSourceFacts(source: original.id, excerpts: [original.text], offers: [offer])
        let digest = DigestSnapshot(id: "facts-day", feed: feed.id, day: Date(timeIntervalSince1970: 0), timeZoneID: "UTC",
                                    sections: [DigestSection(title: "Offer", text: "A free summary.", sources: [original.id], sourceFacts: [facts])],
                                    sources: [original.id], sourceFingerprint: "source-facts-fixture")
        #expect(try await store.saveDigest(digest, expectedSources: [stored]))
        let reopened = try ReaderStore(url: url)
        #expect(try await reopened.digests() == [digest])
        #expect(try await reopened.digests().first?.hasDisplayableContent == true)
        #expect(try await reopened.article(original.id) == stored)
        #expect(try await reopened.pendingChanges(accountID: accountID) == pending)
    }

    @Test("Cross-account refresh data is rejected before any mutation") func crossAccountRefreshDataIsRejectedBeforeAnyMutation() async throws {
        let store = try ReaderStore(inMemory: true)
        var foreign = article()
        foreign.id.accountID = UUID()
        await #expect(throws: ReaderError.invalidResponse) {
            try await store.applyRefresh(refresh(articles: [foreign]))
        }
        #expect(try await store.feeds().isEmpty)
        #expect(try await store.articles(ArticleQuery()).isEmpty)
    }

    @Test("Full-text caches survive unchanged feeds and expire after content changes") func fullTextCachesSurviveUnchangedFeedsAndExpireAfterContentChanges() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article(text: "Short feed text")
        try await store.applyRefresh(refresh(articles: [original]))
        try await store.updateContent(original.id, html: "<p>Long extracted full text</p>", text: "Long extracted full text")
        try await store.applyRefresh(refresh(articles: [original]))
        #expect(try await store.articles(ArticleQuery()).first?.text == "Long extracted full text")
        #expect(try await store.articles(ArticleQuery(search: "extracted")).count == 1)
        try await store.applyRefresh(refresh(articles: [article(text: "Updated feed text")]))
        #expect(try await store.articles(ArticleQuery()).first?.text == "Updated feed text")
    }

    @Test("Change streams emit the current revision and committed writes") func changeStreamsEmitTheCurrentRevisionAndCommittedWrites() async throws {
        let store = try ReaderStore(inMemory: true)
        let changes = await store.changes()
        var iterator = changes.makeAsyncIterator()
        #expect(await iterator.next() == 0)
        try await store.applyRefresh(refresh(articles: [article()]))
        #expect(await iterator.next() == 1)
        await #expect(throws: ReaderError.invalidResponse) {
            try await store.setStatus([ArticleKey(accountID: accountID, remoteID: "missing")], field: .read, value: true)
        }
        try await store.setStatus([article().id], field: .read, value: true)
        #expect(await iterator.next() == 2)
    }

    @Test("Multiple observers receive the same committed change") func multipleObserversReceiveTheSameCommittedChange() async throws {
        let store = try ReaderStore(inMemory: true)
        let firstStream = await store.changes()
        let secondStream = await store.changes()
        var first = firstStream.makeAsyncIterator()
        var second = secondStream.makeAsyncIterator()
        #expect(await first.next() == 0)
        #expect(await second.next() == 0)
        try await store.applyRefresh(refresh(articles: [article()]))
        #expect(await first.next() == 1)
        #expect(await second.next() == 1)
    }

    @Test("Deletion-only refreshes publish updated queries and retain accessible stars", .timeLimit(.minutes(1))) func deletionOnlyRefreshesPublishUpdatedQueriesAndRetainAccessibleStars() async throws {
        let store = try ReaderStore(inMemory: true)
        try await store.applyRefresh(refresh(articles: [article("1"), article("2")], unread: ["1", "2"], starred: ["1"]))
        let stream = await store.changes()
        var revisions = stream.makeAsyncIterator()
        let before = try #require(await revisions.next())
        #expect(try await store.articles(ArticleQuery(unreadOnly: true)).count == 2)

        try await store.applyRefresh(refresh(articles: [], feeds: [], unread: ["1"]))

        #expect(await revisions.next() == before + 1)
        #expect(try await store.feeds().isEmpty)
        #expect(try await store.articles(ArticleQuery()).map(\.id.remoteID) == ["1"])
        #expect(try await store.articles(ArticleQuery(unreadOnly: true)).count == 1)
        #expect(try await store.articles(ArticleQuery(starredOnly: true)).map(\.id.remoteID) == ["1"])
        #expect(try await store.article(article("2").id) == nil)
    }

    @Test("Change streams do not retain the store in an ownership cycle") func changeStreamsDoNotRetainTheStoreInAnOwnershipCycle() async throws {
        var store: ReaderStore? = try ReaderStore(inMemory: true)
        weak let weakStore = store
        let changes = await store?.changes()
        store = nil
        #expect(weakStore == nil)
        var iterator = changes?.makeAsyncIterator()
        #expect(await iterator?.next() == 0)
        #expect(await iterator?.next() == nil)
    }

    @Test("Exact article queries find sources outside the first page") func exactArticleQueriesFindSourcesOutsideTheFirstPage() async throws {
        let store = try ReaderStore(inMemory: true)
        let originals = (0..<210).map { article(String($0), arrived: Date(timeIntervalSince1970: Double($0))) }
        try await store.applyRefresh(refresh(articles: originals))
        let key = ArticleKey(accountID: accountID, remoteID: "0")
        #expect(try await store.articles(ArticleQuery()).contains { $0.id == key } == false)
        #expect(try await store.article(key)?.id == key)
        #expect(try await store.article(ArticleKey(accountID: UUID(), remoteID: "0")) == nil)
    }

    @Test("Folder queries remain scoped to membership and account") func folderQueriesRemainScopedToMembershipAndAccount() async throws {
        let store = try ReaderStore(inMemory: true)
        var firstFeed = feed
        firstFeed.folderIDs = ["folder/1"]
        let secondFeed = FeedSnapshot(id: FeedKey(accountID: accountID, remoteID: "feed/2"), title: "Another feed",
                                      url: fixtureURL, folderIDs: ["folder/2"])
        var secondArticle = article("2")
        secondArticle.feedID = secondFeed.id.remoteID
        let folders = ["folder/1", "folder/2", "empty"].map { FolderSnapshot(accountID: accountID, remoteID: $0, title: $0) }
        try await store.applyRefresh(refresh(articles: [article("1"), secondArticle], feeds: [firstFeed, secondFeed], folders: folders))
        let otherAccount = UUID()
        let foreignFeed = FeedSnapshot(id: FeedKey(accountID: otherAccount, remoteID: "feed/1"), title: "Another account",
                                      url: fixtureURL, folderIDs: ["folder/1"])
        let foreignArticle = ArticleSnapshot(id: ArticleKey(accountID: otherAccount, remoteID: "3"),
                                             feedID: "feed/1", title: "Another article")
        try await store.applyRefresh(RefreshSnapshot(accountID: otherAccount, feeds: [foreignFeed],
            folders: [FolderSnapshot(accountID: otherAccount, remoteID: "folder/1", title: "folder/1")],
            articles: [foreignArticle], unreadIDs: ["3"], starredIDs: []))
        #expect(try await store.articles(ArticleQuery(accountID: accountID, folderID: "folder/1")).map(\.id.remoteID) == ["1"])
        #expect(try await store.articles(ArticleQuery(accountID: accountID, folderID: "folder/2")).map(\.id.remoteID) == ["2"])
        #expect(try await store.articles(ArticleQuery(accountID: accountID, folderID: "empty")).isEmpty)
        #expect(try await store.articles(ArticleQuery(accountID: otherAccount, folderID: "folder/1")).map(\.id.remoteID) == ["3"])
        await #expect(throws: ReaderError.invalidResponse) {
            try await store.articles(ArticleQuery(folderID: "folder/1"))
        }
    }

    @Test("Late extraction does not overwrite newer source content") func lateExtractionDoesNotOverwriteNewerSourceContent() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article(title: "Old title", text: "Old content")
        try await store.applyRefresh(refresh(articles: [original]))
        try await store.applyRefresh(refresh(articles: [article(title: "New title", text: "Newer Content")]))
        #expect(try await store.updateContent(original, html: "<p>Veraltet</p>", text: "Veraltet") == false)
        let current = try #require(try await store.article(original.id))
        #expect(current.title == "New title")
        #expect(current.text == "Newer Content")
        #expect(try await store.updateContent(current, html: "<p>Current full text</p>", text: "Current full text"))
    }

    @Test("Status changes do not invalidate matching content extraction") func statusChangesDoNotInvalidateMatchingContentExtraction() async throws {
        let store = try ReaderStore(inMemory: true)
        let repository: any ReaderRepository = store
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        try await store.setStatus([original.id], field: .read, value: true)
        #expect(try await repository.updateContent(original, html: "<p>Full text</p>", text: "Full text"))
        #expect(try await store.article(original.id)?.read == true)
        #expect(try await store.pendingChanges(accountID: accountID).count == 1)
    }

    @Test("Digests are not overwritten by stale results after new daily arrivals") func digestsAreNotOverwrittenByStaleResultsAfterNewDailyArrivals() async throws {
        let store = try ReaderStore(inMemory: true)
        let repository: any ReaderRepository = store
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: Date(timeIntervalSince1970: 0), timeZoneID: "UTC",
                                    sections: [], sources: [original.id])
        #expect(try await repository.saveDigest(digest, expectedSources: [original]))
        try await store.applyRefresh(refresh(articles: [article("2")], unread: ["1", "2"]))
        var stale = digest
        stale.revision = UUID()
        #expect(try await store.saveDigest(stale, expectedSources: [original]) == false)
        #expect(try await store.digests().first?.revision == digest.revision)
    }

    @Test("Digests accept status changes and reject changed source content") func digestsAcceptStatusChangesAndRejectChangedSourceContent() async throws {
        let store = try ReaderStore(inMemory: true)
        let original = article()
        try await store.applyRefresh(refresh(articles: [original]))
        let digest = DigestSnapshot(id: "day", feed: feed.id, day: Date(timeIntervalSince1970: 0), timeZoneID: "UTC",
                                    sections: [], sources: [original.id])
        try await store.setStatus([original.id], field: .read, value: true)
        #expect(try await store.saveDigest(digest, expectedSources: [original]))
        try await store.applyRefresh(refresh(articles: [article(text: "Changed")]))
        #expect(try await store.saveDigest(digest, expectedSources: [original]) == false)
    }

    @Test("Imported homepages fill missing metadata while preserving server precedence") func importedHomepagesFillMissingMetadataWhilePreservingServerPrecedence() async throws {
        let store = try ReaderStore(inMemory: true)
        let imported = try #require(URL(string: "https://imported.example.org/"))
        let remote = try #require(URL(string: "https://server.example.org/"))
        try await store.applyRefresh(refresh(articles: []))
        try await store.savePreferences(FeedPreferences(id: feed.id, importedHomePageURL: imported, importedFolderPath: ["A", "News"]))
        #expect(try await store.feeds().first?.homePageURL == imported)
        #expect(try await store.preferences().first?.importedFolderPath == ["A", "News"])
        var serverFeed = feed
        serverFeed.homePageURL = remote
        try await store.applyRefresh(refresh(articles: [], feeds: [serverFeed]))
        #expect(try await store.feeds().first?.homePageURL == remote)
        try await store.applyRefresh(refresh(articles: []))
        #expect(try await store.feeds().first?.homePageURL == imported)
    }

    @Test("New original URLs invalidate full text from the previous URL") func newOriginalURLsInvalidateFullTextFromThePreviousURL() async throws {
        let store = try ReaderStore(inMemory: true)
        var original = article(text: "Short feed text")
        original.url = fixtureURL
        try await store.applyRefresh(refresh(articles: [original]))
        #expect(try await store.updateContent(original, html: "<p>Old full text</p>", text: "Old full text"))
        var updated = original
        updated.url = URL(string: "https://example.org/new-article")
        try await store.applyRefresh(refresh(articles: [updated]))
        #expect(try await store.article(original.id)?.text == "Short feed text")
        #expect(try await store.article(original.id)?.url == updated.url)
    }

    @Test("Import merges preserve revoked cloud consent and current display preferences") func importMergesPreserveRevokedCloudConsentAndCurrentDisplayPreferences() async throws {
        let store = try ReaderStore(inMemory: true)
        let repository: any ReaderRepository = store
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .normal, timeZoneID: "Europe/Vienna", cloudAllowed: true))
        // Import preparation may have happened before the user changes these independent fields.
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest, timeZoneID: "UTC", cloudAllowed: false))
        try await repository.mergeImportMetadata(feed: feed.id, homePageURL: fixtureURL,
                                                 folderPath: ["Import", "News"], feedURL: fixtureURL)
        let current = try #require(try await store.preferences().first)
        #expect(current.cloudAllowed == false)
        #expect(current.mode == .digest)
        #expect(current.timeZoneID == "UTC")
        #expect(current.importedHomePageURL == fixtureURL)
        #expect(current.importedFeedURL == fixtureURL)
        #expect(current.importedFolderPath == ["Import", "News"])
    }

    @Test("Import merges retain known URLs and accept only nonempty new folder paths") func importMergesRetainKnownURLsAndAcceptOnlyNonemptyNewFolderPaths() async throws {
        let store = try ReaderStore(inMemory: true)
        let otherURL = try #require(URL(string: "https://other.example.org/feed"))
        try await store.mergeImportMetadata(feed: feed.id, homePageURL: fixtureURL,
                                           folderPath: ["A", "News"], feedURL: fixtureURL)
        try await store.mergeImportMetadata(feed: feed.id, homePageURL: otherURL, folderPath: [], feedURL: otherURL)
        var current = try #require(try await store.preferences().first)
        #expect(current.importedHomePageURL == fixtureURL)
        #expect(current.importedFeedURL == fixtureURL)
        #expect(current.importedFolderPath == ["A", "News"])
        try await store.mergeImportMetadata(feed: feed.id, homePageURL: nil,
                                           folderPath: ["B", "New"], feedURL: otherURL)
        current = try #require(try await store.preferences().first)
        #expect(current.importedFolderPath == ["B", "New"])
        #expect(current.importedHomePageURL == fixtureURL)
        #expect(current.importedFeedURL == fixtureURL)
    }
}
