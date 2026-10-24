import Foundation
import ReaderDomain
import ReaderPersistence

// A separate process exercises the shipping store, without app accounts or credentials.
@main
enum ReaderStoreRecoveryProbe {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else { throw ProbeFailure("Aufruf: ReaderStoreRecoveryProbe [seed|recover|verify] VERZEICHNIS") }
        let directory = URL(fileURLWithPath: arguments[2], isDirectory: true)
        let stateURL = directory.appendingPathComponent("state.json")
        let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"))
        switch arguments[1] {
        case "seed":
            try require(!FileManager.default.fileExists(atPath: stateURL.path), "Vorhandene Probe wird nicht überschrieben.")
            let state = try await seed(store)
            try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
            // The parent kills this process after the committed marker appears.
            // Keep the container alive so this exercises recovery of an unclean exit.
            try await Task.sleep(for: .seconds(60))
            _ = try await store.accounts()
            throw ProbeFailure("Der Probeprozess wurde nicht wie erwartet beendet.")
        case "recover":
            let state = try JSONDecoder().decode(RecoveryState.self, from: Data(contentsOf: stateURL))
            try await recover(store, state: state)
            print("Recovery erfolgreich: \(state.articleCount) Artikel, exakte Outbox, Rollback und reine Löschungen.")
        case "verify":
            let state = try JSONDecoder().decode(RecoveryState.self, from: Data(contentsOf: stateURL))
            try await verifyRetained(store, state: state)
            print("Weiterer Prozessneustart erfolgreich: Sterne, Digestquellen und Pendingrevisionen erhalten.")
        default: throw ProbeFailure("Unbekannte Probephase.")
        }
    }

    private static func seed(_ store: ReaderStore) async throws -> RecoveryState {
        let accountID = UUID()
        guard let serverURL = URL(string: "https://recovery.invalid/api/greader.php"),
              let feedURL = URL(string: "https://recovery.invalid/feed") else { throw ProbeFailure("Ungültige Fixtureadresse.") }
        let account = ReaderAccount(id: accountID, serverURL: serverURL, username: "synthetische-probe")
        let feed = FeedSnapshot(id: FeedKey(accountID: accountID, remoteID: "feed/probe"), title: "Recovery", url: feedURL)
        let originals = (0..<10_000).map { index in
            ArticleSnapshot(id: ArticleKey(accountID: accountID, remoteID: String(index)), feedID: feed.id.remoteID,
                            title: "Artikel \(index)", text: "Synthetischer Text \(index)",
                            dateArrived: Date(timeIntervalSince1970: 1_790_000_000 + Double(index)))
        }
        let unread = Set(originals.map(\.id.remoteID))
        try await store.saveAccount(account)
        try await store.applyRefresh(RefreshSnapshot(accountID: accountID, feeds: [feed], folders: [], articles: originals,
                                                    unreadIDs: unread, starredIDs: []))
        var earlier = originals[2]
        earlier.title = "Frühere Fassung"
        var canonical = originals[2]
        canonical.title = "Kanonischer Titel"
        canonical.html = "<p>Kanonischer Volltext</p>"
        canonical.text = "Kanonischer Volltext"
        canonical.url = URL(string: "https://recovery.invalid/canonical")
        canonical.datePublished = Date(timeIntervalSince1970: 1_780_000_000)
        var incoming = canonical
        incoming.dateArrived = Date(timeIntervalSince1970: 1_800_000_000)
        try await store.applyRefresh(RefreshSnapshot(accountID: accountID, feeds: [feed], folders: [], articles: [earlier, incoming],
                                                    unreadIDs: unread, starredIDs: []))
        try await store.setStatus([originals[0].id], field: .read, value: false)
        guard let staleRead = try await store.pendingChanges(accountID: accountID).first else { throw ProbeFailure("Fehlende erste Revision.") }
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
            throw ProbeFailure("Fehlerhafte Sammeländerung wurde akzeptiert.")
        } catch ReaderError.invalidResponse { }
        return RecoveryState(account: account, feed: feed, pending: try await store.pendingChanges(accountID: accountID),
                             staleRead: staleRead, preferences: preferences, digest: digest, canonical: canonical, articleCount: originals.count)
    }

    private static func recover(_ store: ReaderStore, state: RecoveryState) async throws {
        try require(try await store.accounts() == [state.account], "Konto fehlt nach Neustart.")
        try require(try await allArticles(store, accountID: state.account.id).count == state.articleCount, "Artikel fehlen nach Neustart.")
        try require(try await store.article(state.canonical.id) == state.canonical, "Kanonische Fassung wurde vermischt.")
        let changedKey = ArticleKey(accountID: state.account.id, remoteID: "0")
        let changed = try await store.article(changedKey)
        try require(changed?.read == true && changed?.starred == true, "Lokale Statuswerte oder Rollback gingen verloren.")
        try await verifyMetadata(store, state: state)

        try await store.applyRefresh(RefreshSnapshot(accountID: state.account.id, feeds: [state.feed], folders: [], articles: [],
                                                    unreadIDs: ["0"], starredIDs: []))
        try await store.acknowledge([state.staleRead])
        let protected = try await store.article(changedKey)
        try require(protected?.read == true && protected?.starred == true, "Remoteantwort verdrängt Pendingstatus.")
        try await verifyMetadata(store, state: state)

        // No incoming articles: deletion must retain stars, pending writes and digest originals.
        try await store.applyRefresh(RefreshSnapshot(accountID: state.account.id, feeds: [], folders: [], articles: [],
                                                    unreadIDs: [], starredIDs: []))
        try await verifyRetained(store, state: state)
    }

    private static func verifyRetained(_ store: ReaderStore, state: RecoveryState) async throws {
        let articles = try await allArticles(store, accountID: state.account.id)
        try require(Set(articles.map(\.id.remoteID)) == ["0", "1"], "Löschung oder Quellenretention stimmt nicht.")
        try require(try await store.feeds().isEmpty, "Abbestellter Feed ist noch vorhanden.")
        let starred = try await store.articles(ArticleQuery(starredOnly: true))
        try require(starred.map(\.id.remoteID) == ["0"], "Stern ist nach Abbestellen nicht erreichbar.")
        try await verifyMetadata(store, state: state)
    }

    private static func verifyMetadata(_ store: ReaderStore, state: RecoveryState) async throws {
        let pending = try await store.pendingChanges(accountID: state.account.id)
        try require(Set(pending) == Set(state.pending) && pending.count == 2, "Outboxrevisionen gingen verloren oder wurden falsch bestätigt.")
        try require(try await store.preferences() == [state.preferences], "Gerätelokale Feedpräferenzen gingen verloren.")
        try require(try await store.digests() == [state.digest], "Digest oder seine Revision ging verloren.")
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
    let pending: [PendingChange]
    let staleRead: PendingChange
    let preferences: FeedPreferences
    let digest: DigestSnapshot
    let canonical: ArticleSnapshot
    let articleCount: Int
}

private struct ProbeFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
