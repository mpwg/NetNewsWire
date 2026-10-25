import Foundation
import Testing
import ReaderDomain
import ReaderPersistence
import ReaderUI

struct ReaderFeedReadTests {
    private func fixture(count: Int) async throws -> (ReaderStore, ReaderAccount, FeedSnapshot, [ArticleSnapshot]) {
        let store = try ReaderStore(inMemory: true)
        let url = try #require(URL(string: "https://feed-status.example.test"))
        let account = ReaderAccount(serverURL: url, username: "fixture")
        let feed = FeedSnapshot(id: FeedKey(accountID: account.id, remoteID: "feed/1"), title: "Feed", url: url)
        let articles = (0..<count).map {
            ArticleSnapshot(id: ArticleKey(accountID: account.id, remoteID: "\($0)"),
                            feedID: feed.id.remoteID, title: "Article \($0)")
        }
        try await store.saveAccount(account)
        try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: [feed], folders: [], articles: articles,
                                                    unreadIDs: Set(articles.map(\.id.remoteID)), starredIDs: []))
        return (store, account, feed, articles)
    }

    @Test("Feed read selects only current unread keys beyond timeline page limits and preserves other scopes",
          arguments: [0, 1, 405])
    func feedReadUsesCurrentUnreadSet(count: Int) async throws {
        let (store, account, feed, articles) = try await fixture(count: count)
        let other = FeedSnapshot(id: FeedKey(accountID: account.id, remoteID: "other"), title: "Other", url: feed.url)
        let otherArticle = ArticleSnapshot(id: ArticleKey(accountID: account.id, remoteID: "other"), feedID: other.id.remoteID, title: "Other")
        try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: [feed, other], folders: [], articles: [otherArticle],
                                                    unreadIDs: Set(articles.map(\.id.remoteID) + ["other"]), starredIDs: []))
        let secondAccount = ReaderAccount(serverURL: account.serverURL, username: "other-account")
        try await store.saveAccount(secondAccount)
        let secondFeed = FeedSnapshot(id: FeedKey(accountID: secondAccount.id, remoteID: feed.id.remoteID), title: "Same remote feed", url: feed.url)
        let secondArticle = ArticleSnapshot(id: ArticleKey(accountID: secondAccount.id, remoteID: "0"), feedID: secondFeed.id.remoteID, title: "Other account")
        try await store.applyRefresh(RefreshSnapshot(accountID: secondAccount.id, feeds: [secondFeed], folders: [], articles: [secondArticle],
                                                    unreadIDs: ["0"], starredIDs: []))
        if let first = articles.first { try await store.setStatus([first.id], field: .read, value: true) }
        let before = try await store.pendingChanges(accountID: account.id)
        let changed = try await store.markFeedRead(feed.id)
        #expect(Set(changed) == Set(articles.dropFirst().map(\.id)))
        let pending = try await store.pendingChanges(accountID: account.id)
        #expect(Set(pending.map(\.article)) == Set(articles.map(\.id)))
        #expect(pending.allSatisfy { $0.field == .read && $0.value })
        for old in before { #expect(pending.contains { $0.id == old.id }) }
        #expect(try await store.article(otherArticle.id)?.read == false)
        #expect(try await store.article(secondArticle.id)?.read == false)
        #expect(try await store.pendingChanges(accountID: secondAccount.id).isEmpty)
        #expect(try await store.markFeedRead(feed.id).isEmpty)
        #expect(try await store.pendingChanges(accountID: account.id) == pending)
    }

    @MainActor
    @Test("Confirmation includes articles arriving after menu creation and excludes arrivals after the commit")
    func confirmationResolvesCurrentFeedInsteadOfCapturedPage() async throws {
        let (store, account, feed, articles) = try await fixture(count: 405)
        let session = ReaderSession(services: ReaderServices(repository: store))
        await session.reload()
        #expect(session.rows.count == 200)
        let selection = Set(session.rows.prefix(2).map(\.id))
        let menuFeed = try #require(session.feedForStatusAction(selection))
        let arrival = ArticleSnapshot(id: ArticleKey(accountID: account.id, remoteID: "before-confirmation"),
                                      feedID: feed.id.remoteID, title: "Arrived while menu was open")
        try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: [feed], folders: [], articles: [arrival],
                                                    unreadIDs: Set(articles.map(\.id.remoteID) + [arrival.id.remoteID]), starredIDs: []))
        await session.markFeedRead(menuFeed.id)
        #expect(session.errorMessage == nil)
        #expect(session.markingFeedsRead.isEmpty)
        let pending = try await store.pendingChanges(accountID: account.id)
        #expect(Set(pending.map(\.article)) == Set(articles.map(\.id) + [arrival.id]))
        let later = ArticleSnapshot(id: ArticleKey(accountID: account.id, remoteID: "after-commit"),
                                    feedID: feed.id.remoteID, title: "Arrived after command")
        try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: [feed], folders: [], articles: [later],
                                                    unreadIDs: [later.id.remoteID], starredIDs: []))
        #expect(try await store.article(later.id)?.read == false)
        #expect(try await store.pendingChanges(accountID: account.id) == pending)
    }

    @Test("A removed feed fails before changing retained originals or pending revisions")
    func removedFeedDoesNotChangeRetainedArticles() async throws {
        let (store, account, feed, articles) = try await fixture(count: 3)
        try await store.setStatus([articles[0].id], field: .starred, value: true)
        try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: [], folders: [], articles: [],
                                                    unreadIDs: Set(articles.map(\.id.remoteID)), starredIDs: []))
        let before = try await store.pendingChanges(accountID: account.id)
        await #expect(throws: ReaderError.invalidResponse) { try await store.markFeedRead(feed.id) }
        #expect(try await store.article(articles[0].id)?.read == false)
        #expect(try await store.pendingChanges(accountID: account.id) == before)
    }

    @Test("A pre-cancelled feed command leaves statuses and outbox unchanged")
    func cancelledFeedReadDoesNotWrite() async throws {
        let (store, account, feed, articles) = try await fixture(count: 3)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await store.markFeedRead(feed.id)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try await store.articles(ArticleQuery(unreadOnly: true)).count == articles.count)
        #expect(try await store.pendingChanges(accountID: account.id).isEmpty)
    }
}
