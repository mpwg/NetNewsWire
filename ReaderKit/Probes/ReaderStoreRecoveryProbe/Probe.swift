import Foundation
import ReaderDomain
import ReaderPersistence

// A separate process exercises the shipping store, without app accounts or credentials.
@main
enum ReaderStoreRecoveryProbe {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else { throw ProbeFailure("Usage: ReaderStoreRecoveryProbe [seed|recover|verify] DIRECTORY") }
        let directory = URL(fileURLWithPath: arguments[2], isDirectory: true)
        let stateURL = directory.appendingPathComponent("state.json")
        let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"))
        switch arguments[1] {
        case "seed":
            try require(!FileManager.default.fileExists(atPath: stateURL.path), "An existing probe will not be overwritten.")
            let state = try await seed(store)
            try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
            // The parent kills this process after the committed marker appears.
            // Keep the container alive so this exercises recovery of an unclean exit.
            try await Task.sleep(for: .seconds(60))
            _ = try await store.accounts()
            throw ProbeFailure("The probe process was not terminated as expected.")
        case "recover":
            let state = try JSONDecoder().decode(RecoveryState.self, from: Data(contentsOf: stateURL))
            try await recover(store, state: state)
            print("Recovery passed: \(state.articleCount) articles, exact outbox, rollback and deletion-only refreshes.")
        case "verify":
            let state = try JSONDecoder().decode(RecoveryState.self, from: Data(contentsOf: stateURL))
            try await verifyRetained(store, state: state)
            let receipt = try await retentionReceipt(store, state: state)
            try JSONEncoder().encode(receipt).write(to: directory.appendingPathComponent("retention.json"), options: .atomic)
            print("Further process restart passed: independent stars, another subscription, digest sources and pending revisions retained.")
        default: throw ProbeFailure("Unknown probe phase.")
        }
    }

    private static func seed(_ store: ReaderStore) async throws -> RecoveryState {
        let accountID = UUID()
        guard let serverURL = URL(string: "https://recovery.invalid/api/greader.php"),
              let feedURL = URL(string: "https://recovery.invalid/feed") else { throw ProbeFailure("Invalid fixture URL.") }
        let account = ReaderAccount(id: accountID, serverURL: serverURL, username: "synthetic-probe")
        let feed = FeedSnapshot(id: FeedKey(accountID: accountID, remoteID: "feed/probe"), title: "Recovery", url: feedURL)
        let remainingFeed = FeedSnapshot(id: FeedKey(accountID: accountID, remoteID: "feed/remaining"),
                                         title: "Still subscribed", url: feedURL)
        let originals = (0..<10_000).map { index in
            ArticleSnapshot(id: ArticleKey(accountID: accountID, remoteID: String(index)), feedID: feed.id.remoteID,
                            title: "Article \(index)", text: "Synthetic text \(index)",
                            dateArrived: Date(timeIntervalSince1970: 1_790_000_000 + Double(index)))
        }
        let unread = Set(originals.map(\.id.remoteID))
        try await store.saveAccount(account)
        try await store.applyRefresh(RefreshSnapshot(accountID: accountID, feeds: [feed, remainingFeed], folders: [], articles: originals,
                                                    unreadIDs: unread, starredIDs: ["3"]))
        var earlier = originals[2]
        earlier.title = "Earlier version"
        var canonical = originals[2]
        canonical.title = "Canonical title"
        canonical.html = "<p>Canonical full text</p>"
        canonical.text = "Canonical full text"
        canonical.url = URL(string: "https://recovery.invalid/canonical")
        canonical.datePublished = Date(timeIntervalSince1970: 1_780_000_000)
        var incoming = canonical
        incoming.dateArrived = Date(timeIntervalSince1970: 1_800_000_000)
        try await store.applyRefresh(RefreshSnapshot(accountID: accountID, feeds: [feed, remainingFeed], folders: [], articles: [earlier, incoming],
                                                    unreadIDs: unread, starredIDs: ["3"]))
        try await store.setStatus([originals[0].id], field: .read, value: false)
        guard let staleRead = try await store.pendingChanges(accountID: accountID).first else { throw ProbeFailure("Missing initial revision.") }
        try await store.setStatus([originals[0].id], field: .read, value: true)
        try await store.setStatus([originals[0].id], field: .starred, value: true)
        let preferences = FeedPreferences(id: feed.id, mode: .digest, timeZoneID: "Europe/Vienna", cloudAllowed: false)
        try await store.savePreferences(preferences)
        let digest = DigestSnapshot(id: "recovery/day", feed: feed.id, day: originals[1].dateArrived,
                                    timeZoneID: "Europe/Vienna", sections: [], sources: [originals[1].id])
        try await store.saveDigest(digest)
        // A partially applied batch must roll back before the abrupt process exit.
        do {
            try await store.setStatus([originals[0].id, ArticleKey(accountID: accountID, remoteID: "zz-missing")], field: .read, value: false)
            throw ProbeFailure("An invalid batch change was accepted.")
        } catch ReaderError.invalidResponse { }
        return RecoveryState(account: account, feed: feed, remainingFeed: remainingFeed, pending: try await store.pendingChanges(accountID: accountID),
                             staleRead: staleRead, preferences: preferences, digest: digest, canonical: canonical, articleCount: originals.count)
    }

    private static func recover(_ store: ReaderStore, state: RecoveryState) async throws {
        try require(try await store.accounts() == [state.account], "Account missing after restart.")
        try require(try await allArticles(store, accountID: state.account.id).count == state.articleCount, "Articles missing after restart.")
        try require(try await store.article(state.canonical.id) == state.canonical, "The canonical version contains mixed fields.")
        let unreadCounts = try await store.unreadCounts()
        try require(unreadCounts == [state.feed.id: state.articleCount - 1], "Unread counts omit articles beyond a timeline page.")
        print("Recovered complete unread count: \(unreadCounts.values.reduce(0, +)).")
        let changedKey = ArticleKey(accountID: state.account.id, remoteID: "0")
        let changed = try await store.article(changedKey)
        try require(changed?.read == true && changed?.starred == true, "Local status or rollback was lost.")
        try await verifyMetadata(store, state: state)

        try await store.applyRefresh(RefreshSnapshot(accountID: state.account.id, feeds: [state.feed, state.remainingFeed], folders: [], articles: [],
                                                    unreadIDs: ["0", "4"], starredIDs: ["3"]))
        try await store.acknowledge([state.staleRead])
        let protected = try await store.article(changedKey)
        try require(protected?.read == true && protected?.starred == true, "Remote response overwrote pending status.")
        try await verifyMetadata(store, state: state)

        let beforeDeletion = try await store.unreadCounts()
        try require(beforeDeletion == [state.feed.id: 1], "The pure-deletion case has no unread article to remove.")
        print("Unread count before pure deletion: \(beforeDeletion.values.reduce(0, +)).")
        // Article 4 remains unread in the authoritative status set while its feed is removed.
        // A different subscription remains; star 3 has no pending writes or digest reference.
        try await store.applyRefresh(RefreshSnapshot(accountID: state.account.id, feeds: [state.remainingFeed], folders: [], articles: [],
                                                    unreadIDs: ["4"], starredIDs: []))
        try await verifyRetained(store, state: state)
    }

    private static func verifyRetained(_ store: ReaderStore, state: RecoveryState) async throws {
        let articles = try await allArticles(store, accountID: state.account.id)
        try require(Set(articles.map(\.id.remoteID)) == ["0", "1", "3"], "Deletion or source retention is incorrect.")
        try require(try await store.feeds() == [state.remainingFeed], "The remaining subscription set is incorrect.")
        try require(try await store.unreadCounts().isEmpty, "Unread counts remain stale after deletion and status reconciliation.")
        let starred = try await store.articles(ArticleQuery(starredOnly: true))
        try require(Set(starred.map(\.id.remoteID)) == ["0", "3"], "Starred article is inaccessible after unsubscribing.")
        let independentStar = try await store.article(ArticleKey(accountID: state.account.id, remoteID: "3"))
        try require(independentStar?.starred == true && independentStar?.read == true, "Independent star status was lost.")
        let pending = try await store.pendingChanges(accountID: state.account.id)
        try require(!pending.contains { $0.article.remoteID == "3" }, "The independent star is accidentally protected by pending changes.")
        try require(!state.digest.sources.contains { $0.remoteID == "3" }, "The independent star is accidentally protected by a digest.")
        try await verifyMetadata(store, state: state)
    }

    private static func retentionReceipt(_ store: ReaderStore, state: RecoveryState) async throws -> RetentionReceipt {
        let articles = try await allArticles(store, accountID: state.account.id)
        let pending = try await store.pendingChanges(accountID: state.account.id)
        return RetentionReceipt(articleIDs: articles.map(\.id.remoteID).sorted(),
                                starredIDs: articles.filter(\.starred).map(\.id.remoteID).sorted(),
                                subscribedFeedIDs: try await store.feeds().map(\.id.remoteID).sorted(),
                                readStatus: Dictionary(uniqueKeysWithValues: articles.map { ($0.id.remoteID, $0.read) }),
                                pendingRevisions: pending.count,
                                independentStarHasPendingChange: pending.contains { $0.article.remoteID == "3" },
                                unreadTotal: try await store.unreadCounts().values.reduce(0, +))
    }

    private static func verifyMetadata(_ store: ReaderStore, state: RecoveryState) async throws {
        let pending = try await store.pendingChanges(accountID: state.account.id)
        try require(Set(pending) == Set(state.pending) && pending.count == 2, "Outbox revisions were lost or incorrectly acknowledged.")
        try require(try await store.preferences() == [state.preferences], "Device-local feed preferences were lost.")
        try require(try await store.digests() == [state.digest], "Digest or its revision was lost.")
    }

    private static func allArticles(_ store: ReaderStore, accountID: UUID) async throws -> [ArticleSnapshot] {
        var articles: [ArticleSnapshot] = []
        while true {
            let page = try await store.articles(ArticleQuery(accountID: accountID, offset: articles.count, limit: 1_000))
            articles.append(contentsOf: page)
            if page.count < 1_000 { return articles }
        }
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw ProbeFailure(message) }
    }
}

private struct RecoveryState: Codable {
    let account: ReaderAccount
    let feed: FeedSnapshot
    let remainingFeed: FeedSnapshot
    let pending: [PendingChange]
    let staleRead: PendingChange
    let preferences: FeedPreferences
    let digest: DigestSnapshot
    let canonical: ArticleSnapshot
    let articleCount: Int
}

private struct RetentionReceipt: Codable {
    let articleIDs: [String]
    let starredIDs: [String]
    let subscribedFeedIDs: [String]
    let readStatus: [String: Bool]
    let pendingRevisions: Int
    let independentStarHasPendingChange: Bool
    let unreadTotal: Int
}

private struct ProbeFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
