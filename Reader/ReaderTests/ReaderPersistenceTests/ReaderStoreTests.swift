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

    @Test("Duplicate identities select one complete version and retain the arrival date") func duplicateIdentitiesSelectOneCompleteVersionAndRetainTheArrivalDate() async throws {
        let store = try ReaderStore(inMemory: true)
        try await store.applyRefresh(refresh(articles: [article(title: "A", text: "A")]))
        try await store.applyRefresh(refresh(articles: [
            article(title: "B", text: "A", arrived: Date(timeIntervalSince1970: 200)),
            article(title: "A", text: "B", arrived: Date(timeIntervalSince1970: 300))
        ]))
        let records = try await store.articles(ArticleQuery())
        #expect(records.count == 1)
        #expect(records.first?.title == "A")
        #expect(records.first?.text == "B")
        #expect(records.first?.dateArrived == Date(timeIntervalSince1970: 100))
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

    @Test("Unsubscribing retains stars and removes unprotected articles") func unsubscribingRetainsStarsAndRemovesUnprotectedArticles() async throws {
        let store = try ReaderStore(inMemory: true)
        try await store.applyRefresh(refresh(articles: [article("1"), article("2")], unread: ["1", "2"], starred: ["1"]))
        try await store.applyRefresh(refresh(articles: [], feeds: [], unread: [], starred: []))
        let remaining = try await store.articles(ArticleQuery(starredOnly: true))
        #expect(remaining.map(\.id.remoteID) == ["1"])
        #expect(try await store.articles(ArticleQuery()).count == 1)
        #expect(try await store.feeds().isEmpty)
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
        let original = article(text: "Kurzer Feedtext")
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
        var original = article(text: "Kurzer Feedtext")
        original.url = fixtureURL
        try await store.applyRefresh(refresh(articles: [original]))
        #expect(try await store.updateContent(original, html: "<p>Old full text</p>", text: "Old full text"))
        var updated = original
        updated.url = URL(string: "https://example.org/neuer-artikel")
        try await store.applyRefresh(refresh(articles: [updated]))
        #expect(try await store.article(original.id)?.text == "Kurzer Feedtext")
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
