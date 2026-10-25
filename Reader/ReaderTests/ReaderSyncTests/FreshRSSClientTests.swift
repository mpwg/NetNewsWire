import Foundation
import Synchronization
import Testing
import ReaderDomain
import ReaderPersistence
@testable import ReaderSync

struct FreshRSSClientTests {
    @Test("Article identifiers survive Reader API encoding", arguments: ["0", "1", "9223372036854775807", "-9223372036854775808", "-1"])
    func articleIdentifiersSurviveReaderAPIEncoding(id: String) throws {
        #expect(try ReaderItemID.canonical(ReaderItemID.longForm(id)) == id)
    }

    @Test("Installation subdirectories and explicit API paths are preserved") func installationSubdirectoriesAndExplicitAPIPathsArePreserved() throws {
        let root = try #require(URL(string: "https://example.test/rss"))
        let api = try #require(URL(string: "https://example.test/rss/api/greader.php"))
        #expect(try FreshRSSClient.endpoint(for: root) == api)
        #expect(try FreshRSSClient.endpoint(for: api) == api)
        #expect(throws: ReaderError.invalidURL) {
            try FreshRSSClient.endpoint(for: #require(URL(string: "file:///tmp/rss")))
        }
    }

    @Test("Refresh waits for every page and retains old publication dates") func refreshWaitsForEveryPageAndRetainsOldPublicationDates() async throws {
        let fixture = try Fixture()
        try await fixture.client.refresh(account: fixture.account)
        let snapshots = await fixture.repository.snapshots
        let snapshot = try #require(snapshots.first)
        #expect(snapshots.count == 1)
        #expect(Set(snapshot.articles.map { $0.id.remoteID }) == ["1", "2"])
        #expect(snapshot.unreadIDs == ["1"])
        #expect(snapshot.starredIDs == ["2"])
        #expect(snapshot.articles.first?.datePublished?.timeIntervalSince1970 == 946684800)
        #expect(snapshot.articles.first?.dateArrived.timeIntervalSince1970 == 1792830000)
        #expect(snapshot.feeds.first?.homePageURL?.absoluteString == "https://news.test")
        let calls = await fixture.server.calls
        #expect(calls.allSatisfy { $0.query["ot"] == nil })
        #expect(calls.contains { $0.query["c"] == "next" })
        #expect(calls.filter { !$0.path.hasSuffix("ClientLogin") }.allSatisfy { $0.auth == "GoogleLogin auth=auth==" })
        let login = try #require(calls.first { $0.path.hasSuffix("ClientLogin") })
        #expect(login.fields["Email"] == ["mat+test"])
        #expect(login.fields["Passwd"] == ["a&b=c"])
    }

    @Test("Failed unread requests leave the local snapshot unchanged") func failedUnreadRequestsLeaveTheLocalSnapshotUnchanged() async throws {
        let fixture = try Fixture()
        await fixture.server.setFailure(.unread)
        await #expect(throws: ReaderError.server(503)) { try await fixture.client.refresh(account: fixture.account) }
        #expect(await fixture.repository.snapshots.isEmpty)
    }

    @Test("HTTP success with an error body does not acknowledge status changes") func httpSuccessWithAnErrorBodyDoesNotAcknowledgeStatusChanges() async throws {
        let fixture = try Fixture()
        let change = PendingChange(article: ArticleKey(accountID: fixture.account.id, remoteID: "1"), field: .read, value: true)
        await fixture.repository.replacePending(change)
        await fixture.server.setFailure(.writeBody)
        await #expect(throws: ReaderError.invalidResponse) { try await fixture.client.flush(account: fixture.account) }
        #expect(await fixture.repository.pending == [change])
    }

    @Test("Rejected renames are not committed as local successes") func rejectedRenamesAreNotCommittedAsLocalSuccesses() async throws {
        let fixture = try Fixture()
        await fixture.server.setFailure(.mutation)
        await #expect(throws: ReaderError.server(500)) {
            try await fixture.client.renameFeed(account: fixture.account, feedID: "feed/1", title: "New name")
        }
        #expect(await fixture.repository.snapshots.isEmpty)
    }

    @Test("Missing article content prevents incomplete commits") func missingArticleContentPreventsIncompleteCommits() async throws {
        let fixture = try Fixture()
        await fixture.server.setFailure(.missingContent)
        await #expect(throws: (any Error).self) { try await fixture.client.refresh(account: fixture.account) }
        #expect(await fixture.repository.snapshots.isEmpty)
    }

    @Test("Repeated pagination tokens fail instead of looping forever") func repeatedPaginationTokensFailInsteadOfLoopingForever() async throws {
        let fixture = try Fixture()
        await fixture.server.setFailure(.continuationLoop)
        await #expect(throws: ReaderError.invalidResponse) { try await fixture.client.refresh(account: fixture.account) }
        #expect(await fixture.repository.snapshots.isEmpty)
    }

    @Test("Expired write tokens are renewed once") func expiredWriteTokensAreRenewedOnce() async throws {
        let fixture = try Fixture()
        let change = PendingChange(article: ArticleKey(accountID: fixture.account.id, remoteID: "1"), field: .starred, value: true)
        await fixture.repository.replacePending(change)
        await fixture.server.setFailure(.expiredWriteToken)
        try await fixture.client.flush(account: fixture.account)
        #expect(await fixture.repository.pending.isEmpty)
        #expect(await fixture.server.tokenRequests == 2)
    }

    @Test("Overlapping sends acknowledge only their own revisions", .timeLimit(.minutes(1))) func overlappingSendsAcknowledgeOnlyTheirOwnRevisions() async throws {
        let fixture = try Fixture()
        let key = ArticleKey(accountID: fixture.account.id, remoteID: "1")
        let old = PendingChange(article: key, field: .read, value: true)
        let newer = PendingChange(article: key, field: .read, value: false)
        await fixture.repository.replacePending(old)
        let gate = RequestGate()
        defer { Task { await gate.open() } }
        await fixture.server.setWriteGate(gate)
        let first = Task { try await fixture.client.flush(account: fixture.account) }
        try await gate.waitUntilEntered()
        await fixture.repository.replacePending(newer)
        await fixture.server.setFailure(.secondWrite)
        let second = Task { try await fixture.client.flush(account: fixture.account) }
        await gate.open()
        try await first.value
        await #expect(throws: ReaderError.server(500)) { try await second.value }
        #expect(await fixture.repository.pending == [newer])
        let writes = await fixture.server.calls.filter { $0.path.hasSuffix("/edit-tag") }
        #expect(writes.count == 2)
        #expect(writes[0].fields["a"] == ["user/-/state/com.google/read"])
        #expect(writes[1].fields["r"] == ["user/-/state/com.google/read"])
    }

    @Test("Untitled article titles use the requested resource language",
          arguments: [("en", "Untitled"), ("de", "Ohne Titel")])
    func untitledArticleTitlesUseRequestedLanguage(localeID: String, expected: String) {
        #expect(FreshRSSClient.untitledArticleTitle(locale: Locale(identifier: localeID)) == expected)
    }

    @Test("Already cancelled refreshes send no authentication request")
    func alreadyCancelledRefreshesSendNoAuthenticationRequest() async throws {
        let fixture = try Fixture()
        let request = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await fixture.client.refresh(account: fixture.account)
        }
        await #expect(throws: CancellationError.self) { try await request.value }
        #expect(await fixture.server.calls.isEmpty)
        #expect(await fixture.repository.snapshots.isEmpty)
    }

    @Test("Cancelling a status batch prevents the next batch and preserves pending revisions", .timeLimit(.minutes(1)))
    func cancellingStatusBatchPreventsNextBatchAndPreservesPendingRevisions() async throws {
        let fixture = try Fixture()
        let changes = (0..<501).map {
            PendingChange(article: ArticleKey(accountID: fixture.account.id, remoteID: String($0)), field: .read, value: true)
        }
        await fixture.repository.replacePending(changes)
        let gate = RequestGate()
        await fixture.server.setWriteGate(gate)
        let request = Task { try await fixture.client.flush(account: fixture.account) }
        defer { request.cancel(); Task { await gate.open() } }
        try await gate.waitUntilEntered()
        request.cancel()
        await #expect {
            try await request.value
        } throws: { error in
            error is CancellationError || (error as? URLError)?.code == .cancelled
        }
        let writes = await fixture.server.calls.filter { $0.path.hasSuffix("/edit-tag") }
        #expect(writes.count == 1)
        #expect(writes.first?.fields["i"]?.count == 500)
        #expect(await fixture.repository.pending == changes)
    }

    @Test("Empty authoritative folder lists are propagated") func emptyAuthoritativeFolderListsArePropagated() async throws {
        let fixture = try Fixture()
        await fixture.server.setFailure(.emptyFolders)
        try await fixture.client.refresh(account: fixture.account)
        #expect(await fixture.repository.snapshots.first?.folders.isEmpty == true)
        #expect(await fixture.repository.snapshots.first?.feeds.first?.folderIDs.isEmpty == true)
    }
}

struct FreshRSSPersistenceTests {
    enum FailureStage: CaseIterable, Sendable { case statusSend, unreadRetrieval }

    @Test("Late status acknowledgement preserves a newer SwiftData revision", .timeLimit(.minutes(1)))
    func lateAcknowledgementPreservesNewerStoredRevision() async throws {
        let store = try ReaderStore(inMemory: true)
        let fixture = try Fixture(repository: store)
        try await store.saveAccount(fixture.account)
        try await fixture.client.refresh(account: fixture.account)
        let key = ArticleKey(accountID: fixture.account.id, remoteID: "1")
        try await store.setStatus([key], field: .read, value: true)
        let old = try #require(try await store.pendingChanges(accountID: fixture.account.id).first)
        let gate = RequestGate()
        await fixture.server.setWriteGate(gate)
        let first = Task { try await fixture.client.flush(account: fixture.account) }
        defer { first.cancel(); Task { await gate.open() } }
        try await gate.waitUntilEntered()
        try await store.setStatus([key], field: .read, value: false)
        let newer = try #require(try await store.pendingChanges(accountID: fixture.account.id).first)
        #expect(newer.id != old.id)
        await gate.open()
        try await first.value
        #expect(try await store.pendingChanges(accountID: fixture.account.id) == [newer])
        #expect(try await store.article(key)?.read == false)
        await fixture.server.setFailure(.secondWrite)
        await #expect(throws: ReaderError.server(500)) { try await fixture.client.flush(account: fixture.account) }
        #expect(try await store.pendingChanges(accountID: fixture.account.id) == [newer])
        #expect(try await store.article(key)?.read == false)
        await fixture.server.setFailure(nil)
        try await fixture.client.refresh(account: fixture.account)
        #expect(try await store.pendingChanges(accountID: fixture.account.id).isEmpty)
        #expect(try await store.article(key)?.read == false)
    }

    @Test("Failed sync stages preserve unread state and retry through SwiftData", .timeLimit(.minutes(1)),
          arguments: FailureStage.allCases)
    func failedSyncPreservesStoredUnreadAndRetries(stage: FailureStage) async throws {
        let store = try ReaderStore(inMemory: true)
        let fixture = try Fixture(repository: store)
        try await store.saveAccount(fixture.account)
        try await fixture.client.refresh(account: fixture.account)
        let key = ArticleKey(accountID: fixture.account.id, remoteID: "2")
        #expect(try await store.article(key)?.read == true)
        let gate = RequestGate()
        if stage == .unreadRetrieval { await fixture.server.setUnreadGate(gate) }
        await fixture.server.setFailure(stage == .statusSend ? .writeBody : .unread)
        if stage == .statusSend { try await store.setStatus([key], field: .read, value: false) }
        let refresh = Task { try await fixture.client.refresh(account: fixture.account) }
        defer { refresh.cancel(); Task { await gate.open() } }
        if stage == .unreadRetrieval {
            try await gate.waitUntilEntered()
            try await store.setStatus([key], field: .read, value: false)
        }
        let pending = try await store.pendingChanges(accountID: fixture.account.id)
        let original = try await store.article(key)
        try #require(pending.count == 1)
        await gate.open()
        let expected: ReaderError = stage == .statusSend ? .invalidResponse : .server(503)
        await #expect(throws: expected) { try await refresh.value }
        #expect(try await store.pendingChanges(accountID: fixture.account.id) == pending)
        #expect(try await store.article(key) == original)
        #expect(original?.read == false)
        await fixture.server.setFailure(nil)
        try await fixture.client.refresh(account: fixture.account)
        #expect(try await store.pendingChanges(accountID: fixture.account.id).isEmpty)
        #expect(try await store.article(key)?.read == false)
    }

    @Test("Empty memberships and folder deletion reach the stored root feed")
    func authoritativeEmptyFoldersUpdateStoredMemberships() async throws {
        let store = try ReaderStore(inMemory: true)
        let fixture = try Fixture(repository: store)
        try await store.saveAccount(fixture.account)
        try await fixture.client.refresh(account: fixture.account)
        #expect(try await store.folders().count == 1)
        #expect(try await store.feeds().first?.folderIDs == ["user/-/label/News"])
        await fixture.server.setFailure(.emptyMemberships)
        try await fixture.client.refresh(account: fixture.account)
        #expect(try await store.folders().count == 1)
        #expect(try await store.feeds().first?.folderIDs.isEmpty == true)
        await fixture.server.setFailure(.emptyFolders)
        try await fixture.client.refresh(account: fixture.account)
        #expect(try await store.folders().isEmpty)
        let feed = try #require(try await store.feeds().first)
        #expect(feed.id == FeedKey(accountID: fixture.account.id, remoteID: "feed/1"))
        #expect(feed.folderIDs.isEmpty)
        #expect(try await store.articles(ArticleQuery(accountID: fixture.account.id)).count == 2)
    }
}

struct FreshRSSMutationTests {
    enum Operation: CaseIterable, Sendable {
        case rename, assign, removeAssignment, move

        var fields: [String: [String]] {
            var result = ["ac": ["edit"], "s": ["feed/1"]]
            if self == .rename { result["t"] = ["Renamed feed"] }
            if self == .assign || self == .move { result["a"] = ["user/-/label/New"] }
            if self == .removeAssignment || self == .move { result["r"] = ["user/-/label/News"] }
            return result
        }

        fileprivate func perform(_ fixture: Fixture) async throws {
            switch self {
            case .rename:
                try await fixture.client.renameFeed(account: fixture.account, feedID: "feed/1", title: "Renamed feed")
            case .assign:
                try await fixture.client.moveFeed(account: fixture.account, feedID: "feed/1",
                                                  fromFolderID: nil, toFolderID: "user/-/label/New")
            case .removeAssignment:
                try await fixture.client.moveFeed(account: fixture.account, feedID: "feed/1",
                                                  fromFolderID: "user/-/label/News", toFolderID: nil)
            case .move:
                try await fixture.client.moveFeed(account: fixture.account, feedID: "feed/1",
                                                  fromFolderID: "user/-/label/News", toFolderID: "user/-/label/New")
            }
        }
    }

    enum Failure: CaseIterable, Sendable {
        case token, http, body
        var error: ReaderError {
            switch self {
            case .token: .server(503)
            case .http: .server(500)
            case .body: .invalidResponse
            }
        }
    }

    @Test("Mutation errors preserve the SwiftData tree for every subscription operation",
          arguments: Operation.allCases, Failure.allCases)
    func failedMutationsPreserveStoredTree(operation: Operation, failure: Failure) async throws {
        let store = try ReaderStore(inMemory: true)
        let fixture = try Fixture(repository: store)
        try await store.saveAccount(fixture.account)
        try await fixture.client.refresh(account: fixture.account)
        let feeds = try await store.feeds()
        let folders = try await store.folders()
        let articles = try await store.articles(ArticleQuery(accountID: fixture.account.id))
        await fixture.client.invalidateCredentials(accountID: fixture.account.id)
        await fixture.server.setFailure(failure == .token ? .token : failure == .http ? .mutation : .mutationBody)
        let callsBefore = await fixture.server.calls.count
        await #expect(throws: failure.error) { try await operation.perform(fixture) }
        let calls = await Array(fixture.server.calls.dropFirst(callsBefore))
        let edits = calls.filter { $0.path.hasSuffix("/subscription/edit") }
        if failure == .token {
            #expect(calls.filter { $0.path.hasSuffix("/token") }.count == 1)
            #expect(edits.isEmpty)
        } else {
            let edit = try #require(edits.first)
            #expect(edits.count == 1)
            #expect(edit.fields.filter { $0.key != "T" } == operation.fields)
        }
        #expect(!calls.contains { $0.path.hasSuffix("/subscription/list") })
        #expect(try await store.feeds() == feeds)
        #expect(try await store.folders() == folders)
        #expect(try await store.articles(ArticleQuery(accountID: fixture.account.id)) == articles)
        #expect(try await store.pendingChanges(accountID: fixture.account.id).isEmpty)
    }
}

struct FreshRSSCompletionTests {
    enum Outcome: CaseIterable, Sendable { case saved, storeFailure, cancelled }

    @Test("Refresh completion includes the persisted snapshot and propagates save failure or cancellation",
          .timeLimit(.minutes(1)), arguments: Outcome.allCases)
    func refreshCompletionIncludesPersistence(outcome: Outcome) async throws {
        let store = try ReaderStore(inMemory: true)
        let gate = RequestGate()
        let events = CommitEvents()
        let repository = CommitGateRepository(store: store, gate: gate, events: events, fail: outcome == .storeFailure)
        let fixture = try Fixture(repository: repository)
        try await store.saveAccount(fixture.account)
        let refresh = Task {
            try await fixture.client.refresh(account: fixture.account)
            events.append("refreshReturned")
        }
        defer { refresh.cancel(); Task { await gate.open() } }
        try await gate.waitUntilEntered()
        #expect(events.values == ["saveEntered"])
        #expect(try await store.feeds().isEmpty)
        #expect(try await store.articles(ArticleQuery(accountID: fixture.account.id)).isEmpty)
        if outcome == .cancelled { refresh.cancel() }
        await gate.open()
        switch outcome {
        case .saved:
            try await refresh.value
            #expect(events.values == ["saveEntered", "saved", "refreshReturned"])
            #expect(try await store.feeds().count == 1)
            let articles = try await store.articles(ArticleQuery(accountID: fixture.account.id))
            #expect(Set(articles.map { $0.id.remoteID }) == ["1", "2"])
            #expect(articles.first { $0.id.remoteID == "1" }?.read == false)
            #expect(articles.first { $0.id.remoteID == "2" }?.starred == true)
            #expect(try await store.pendingChanges(accountID: fixture.account.id).isEmpty)
        case .storeFailure:
            await #expect(throws: CommitGateRepository.failure) { try await refresh.value }
        case .cancelled:
            await #expect(throws: CancellationError.self) { try await refresh.value }
        }
        if outcome != .saved {
            #expect(events.values == ["saveEntered"])
            #expect(try await store.feeds().isEmpty)
            #expect(try await store.folders().isEmpty)
            #expect(try await store.articles(ArticleQuery(accountID: fixture.account.id)).isEmpty)
        }
    }
}

private final class CommitEvents: Sendable {
    private let state = Mutex<[String]>([])
    var values: [String] { state.withLock { $0 } }
    func append(_ event: String) { state.withLock { $0.append(event) } }
}

private actor CommitGateRepository: ReaderRepository {
    static let failure = ReaderError.unavailable("Isolated persistence failure.")
    let store: ReaderStore
    let gates: [RequestGate]
    let events: CommitEvents
    let fail: Bool
    private var started = 0

    init(store: ReaderStore, gate: RequestGate, events: CommitEvents, fail: Bool, followingGates: [RequestGate] = []) {
        self.store = store; self.gates = [gate] + followingGates; self.events = events; self.fail = fail
    }

    func applyRefresh(_ snapshot: RefreshSnapshot) async throws {
        let index = started
        started += 1
        events.append("saveEntered")
        try await gates[min(index, gates.count - 1)].pause()
        try Task.checkCancellation()
        if fail, index == 0 { throw Self.failure }
        try await store.applyRefresh(snapshot)
        events.append("saved")
    }

    func accounts() async throws -> [ReaderAccount] { try await store.accounts() }
    func saveAccount(_ account: ReaderAccount) async throws { try await store.saveAccount(account) }
    func feeds() async throws -> [FeedSnapshot] { try await store.feeds() }
    func folders() async throws -> [FolderSnapshot] { try await store.folders() }
    func articles(_ query: ArticleQuery) async throws -> [ArticleSnapshot] { try await store.articles(query) }
    func article(_ key: ArticleKey) async throws -> ArticleSnapshot? { try await store.article(key) }
    func changes() async -> AsyncStream<UInt64> { await store.changes() }
    func setStatus(_ keys: [ArticleKey], field: StatusField, value: Bool) async throws {
        try await store.setStatus(keys, field: field, value: value)
    }
    func pendingChanges(accountID: UUID) async throws -> [PendingChange] { try await store.pendingChanges(accountID: accountID) }
    func acknowledge(_ changes: [PendingChange]) async throws { try await store.acknowledge(changes) }
    func preferences() async throws -> [FeedPreferences] { try await store.preferences() }
    func savePreferences(_ preferences: FeedPreferences) async throws { try await store.savePreferences(preferences) }
    func digests() async throws -> [DigestSnapshot] { try await store.digests() }
    func saveDigest(_ digest: DigestSnapshot) async throws { try await store.saveDigest(digest) }
    func updateContent(_ key: ArticleKey, html: String, text: String) async throws {
        try await store.updateContent(key, html: html, text: text)
    }
}

struct FreshRSSQueueTests {
    enum Operation: CaseIterable, Sendable {
        case refresh, flush, addSubscription, rename

        fileprivate func perform(_ fixture: Fixture) async throws {
            switch self {
            case .refresh: try await fixture.client.refresh(account: fixture.account)
            case .flush: try await fixture.client.flush(account: fixture.account)
            case .addSubscription:
                _ = try await fixture.client.addSubscription(account: fixture.account,
                                                              url: #require(URL(string: "https://feed.test/new")))
            case .rename: try await fixture.client.renameFeed(account: fixture.account, feedID: "feed/1", title: "Cancelled")
            }
        }
    }

    @Test("Cancelled queued operations finish while the owner remains blocked", .timeLimit(.minutes(1)),
          arguments: Operation.allCases, [true, false])
    func cancelledQueuedOperationsDoNotWaitForOwner(operation: Operation, alreadyCancelled: Bool) async throws {
        let store = try ReaderStore(inMemory: true)
        let fixture = try Fixture(repository: store)
        try await store.saveAccount(fixture.account)
        try await fixture.client.refresh(account: fixture.account)
        try await store.setStatus([ArticleKey(accountID: fixture.account.id, remoteID: "1")], field: .read, value: true)
        let pending = try await store.pendingChanges(accountID: fixture.account.id)
        let gate = RequestGate()
        await fixture.server.setWriteGate(gate)
        let owner = Task { try await fixture.client.flush(account: fixture.account) }
        defer { owner.cancel(); Task { await gate.open() } }
        try await gate.waitUntilEntered()
        let callsBefore = await fixture.server.calls.count
        let events = CommitEvents()
        let request = Task {
            defer { events.append("finished") }
            if alreadyCancelled { withUnsafeCurrentTask { $0?.cancel() } }
            try await operation.perform(fixture)
        }
        defer { request.cancel() }
        if !alreadyCancelled {
            try await Self.waitForQueue(fixture, count: 1)
            request.cancel()
        }
        let finished = try await Self.waitForEvent("finished", events: events)
        #expect(finished, "Cancellation must complete before releasing the blocked owner.")
        #expect(await fixture.client.queuedOperationCount(accountID: fixture.account.id) == 0)
        #expect(await fixture.server.calls.count == callsBefore)
        #expect(await fixture.server.completedWrites.isEmpty)
        #expect(try await store.pendingChanges(accountID: fixture.account.id) == pending)
        await gate.open()
        try await owner.value
        await #expect(throws: CancellationError.self) { try await request.value }
        try await fixture.client.refresh(account: fixture.account)
        #expect(try await store.pendingChanges(accountID: fixture.account.id).isEmpty)
    }

    @Test("Queued sends cannot reverse response order or acknowledge a newer stored revision", .timeLimit(.minutes(1)))
    func queuedSendsKeepResponseOrderAndNewerRevision() async throws {
        let store = try ReaderStore(inMemory: true)
        let fixture = try Fixture(repository: store)
        try await store.saveAccount(fixture.account)
        try await fixture.client.refresh(account: fixture.account)
        let key = ArticleKey(accountID: fixture.account.id, remoteID: "1")
        try await store.setStatus([key], field: .read, value: true)
        let gate = RequestGate()
        await fixture.server.setWriteGate(gate)
        let first = Task { try await fixture.client.flush(account: fixture.account) }
        defer { first.cancel(); Task { await gate.open() } }
        try await gate.waitUntilEntered()
        try await store.setStatus([key], field: .read, value: false)
        let newer = try await store.pendingChanges(accountID: fixture.account.id)
        await fixture.server.setFailure(.secondWrite)
        let second = Task { try await fixture.client.flush(account: fixture.account) }
        defer { second.cancel() }
        try await Self.waitForQueue(fixture, count: 1)
        #expect(await fixture.server.calls.filter { $0.path.hasSuffix("/edit-tag") }.count == 1)
        #expect(await fixture.server.completedWrites.isEmpty)
        await gate.open()
        try await first.value
        await #expect(throws: ReaderError.server(500)) { try await second.value }
        #expect(await fixture.server.completedWrites == [1, 2])
        #expect(try await store.pendingChanges(accountID: fixture.account.id) == newer)
        #expect(try await store.article(key)?.read == false)
        let writes = await fixture.server.calls.filter { $0.path.hasSuffix("/edit-tag") }
        #expect(writes.map { $0.fields["a"] ?? $0.fields["r"] ?? [] } ==
                [["user/-/state/com.google/read"], ["user/-/state/com.google/read"]])
        #expect(writes.first?.fields["a"] != nil)
        #expect(writes.last?.fields["r"] != nil)
        #expect(await fixture.client.queuedOperationCount(accountID: fixture.account.id) == 0)
    }

    @Test("Overlapping refreshes wait for their own commit after owner success failure or cancellation",
          .timeLimit(.minutes(1)), arguments: FreshRSSCompletionTests.Outcome.allCases)
    func overlappingRefreshesKeepIndependentCompletion(outcome: FreshRSSCompletionTests.Outcome) async throws {
        let store = try ReaderStore(inMemory: true)
        let firstGate = RequestGate(), secondGate = RequestGate()
        let events = CommitEvents()
        let repository = CommitGateRepository(store: store, gate: firstGate, events: events,
                                               fail: outcome == .storeFailure, followingGates: [secondGate])
        let fixture = try Fixture(repository: repository)
        try await store.saveAccount(fixture.account)
        let first = Task { try await fixture.client.refresh(account: fixture.account); events.append("firstReturned") }
        defer { first.cancel(); Task { await firstGate.open(); await secondGate.open() } }
        try await firstGate.waitUntilEntered()
        let second = Task { try await fixture.client.refresh(account: fixture.account); events.append("secondReturned") }
        defer { second.cancel() }
        try await Self.waitForQueue(fixture, count: 1)
        #expect(events.values == ["saveEntered"])
        #expect(try await store.feeds().isEmpty)
        #expect(await fixture.server.calls.filter { $0.path.hasSuffix("/subscription/list") }.count == 1)
        if outcome == .cancelled { first.cancel() }
        await firstGate.open()
        switch outcome {
        case .saved: try await first.value
        case .storeFailure: await #expect(throws: CommitGateRepository.failure) { try await first.value }
        case .cancelled: await #expect(throws: CancellationError.self) { try await first.value }
        }
        try await secondGate.waitUntilEntered()
        #expect(!events.values.contains("secondReturned"))
        #expect(events.values.filter { $0 == "saveEntered" }.count == 2)
        #expect(events.values.filter { $0 == "saved" }.count == (outcome == .saved ? 1 : 0))
        #expect(try await store.feeds().count == (outcome == .saved ? 1 : 0))
        await secondGate.open()
        try await second.value
        #expect(events.values.last == "secondReturned")
        #expect(events.values.filter { $0 == "saved" }.count == (outcome == .saved ? 2 : 1))
        #expect(try await store.articles(ArticleQuery(accountID: fixture.account.id)).count == 2)
        #expect(try await store.pendingChanges(accountID: fixture.account.id).isEmpty)
        #expect(await fixture.client.queuedOperationCount(accountID: fixture.account.id) == 0)
    }

    @Test("Cancelling a middle waiter preserves FIFO survivors and recovers after a failed send", .timeLimit(.minutes(1)))
    func cancellingMiddleWaiterPreservesSurvivorsAndRecovery() async throws {
        let store = try ReaderStore(inMemory: true)
        let fixture = try Fixture(repository: store)
        try await store.saveAccount(fixture.account)
        try await fixture.client.refresh(account: fixture.account)
        let key = ArticleKey(accountID: fixture.account.id, remoteID: "1")
        try await store.setStatus([key], field: .read, value: true)
        let gate = RequestGate()
        await fixture.server.setWriteGate(gate)
        let owner = Task { try await fixture.client.flush(account: fixture.account) }
        defer { owner.cancel(); Task { await gate.open() } }
        try await gate.waitUntilEntered()
        try await store.setStatus([key], field: .read, value: false)
        let newer = try await store.pendingChanges(accountID: fixture.account.id)
        await fixture.server.setFailure(.secondWrite)
        let firstWaiter = Task { try await fixture.client.flush(account: fixture.account) }
        defer { firstWaiter.cancel() }
        try await Self.waitForQueue(fixture, count: 1)
        let cancelledEvents = CommitEvents()
        let middle = Task {
            defer { cancelledEvents.append("finished") }
            try await fixture.client.renameFeed(account: fixture.account, feedID: "feed/1", title: "Cancelled")
        }
        defer { middle.cancel() }
        try await Self.waitForQueue(fixture, count: 2)
        let lastWaiter = Task { try await fixture.client.refresh(account: fixture.account) }
        defer { lastWaiter.cancel() }
        try await Self.waitForQueue(fixture, count: 3)
        middle.cancel()
        #expect(try await Self.waitForEvent("finished", events: cancelledEvents))
        #expect(await fixture.client.queuedOperationCount(accountID: fixture.account.id) == 2)
        #expect(await fixture.server.completedWrites.isEmpty)
        #expect(try await store.pendingChanges(accountID: fixture.account.id) == newer)
        await gate.open()
        try await owner.value
        await #expect(throws: CancellationError.self) { try await middle.value }
        await #expect(throws: ReaderError.server(500)) { try await firstWaiter.value }
        try await lastWaiter.value
        #expect(await fixture.server.completedWrites == [1, 2, 3])
        #expect(await fixture.server.calls.filter { $0.path.hasSuffix("/subscription/edit") }.isEmpty)
        #expect(try await store.pendingChanges(accountID: fixture.account.id).isEmpty)
        #expect(try await store.article(key)?.read == false)
        #expect(await fixture.client.queuedOperationCount(accountID: fixture.account.id) == 0)
    }

    @Test("A blocked account does not prevent another account from committing", .timeLimit(.minutes(1)))
    func blockedAccountsDoNotHoldIndependentAccounts() async throws {
        let store = try ReaderStore(inMemory: true)
        let fixture = try Fixture(repository: store)
        let other = ReaderAccount(serverURL: fixture.account.serverURL, username: "independent-fixture")
        try await store.saveAccount(fixture.account)
        try await store.saveAccount(other)
        try await fixture.client.refresh(account: fixture.account)
        try await store.setStatus([ArticleKey(accountID: fixture.account.id, remoteID: "1")], field: .read, value: true)
        let pending = try await store.pendingChanges(accountID: fixture.account.id)
        let gate = RequestGate()
        await fixture.server.setWriteGate(gate)
        let owner = Task { try await fixture.client.flush(account: fixture.account) }
        defer { owner.cancel(); Task { await gate.open() } }
        try await gate.waitUntilEntered()
        let events = CommitEvents()
        let independent = Task {
            try await fixture.client.refresh(account: other)
            events.append("committed")
        }
        defer { independent.cancel() }
        #expect(try await Self.waitForEvent("committed", events: events))
        #expect(try await store.articles(ArticleQuery(accountID: other.id)).count == 2)
        #expect(try await store.feeds().filter { $0.id.accountID == other.id }.count == 1)
        #expect(try await store.pendingChanges(accountID: fixture.account.id) == pending)
        #expect(await fixture.server.completedWrites.isEmpty)
        #expect(await fixture.client.queuedOperationCount(accountID: other.id) == 0)
        await gate.open()
        try await owner.value
        try await independent.value
    }

    private static func waitForQueue(_ fixture: Fixture, count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while await fixture.client.queuedOperationCount(accountID: fixture.account.id) != count {
            try #require(ContinuousClock.now < deadline, "The actual account queue must reach the expected depth.")
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private static func waitForEvent(_ event: String, events: CommitEvents) async throws -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !events.values.contains(event), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        return events.values.contains(event)
    }
}

private final class Fixture: @unchecked Sendable {
    let account: ReaderAccount
    let repository = TestRepository()
    let server = TestServer()
    let client: FreshRSSClient
    private let host: String
    private let session: URLSession

    init(repository clientRepository: (any ReaderRepository)? = nil) throws {
        host = UUID().uuidString.lowercased() + ".test"
        let url = try #require(URL(string: "https://" + host + "/rss"))
        account = ReaderAccount(serverURL: url, username: "mat+test")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
        client = FreshRSSClient(repository: clientRepository ?? repository, credentials: TestCredentials(), session: session)
        let server = server
        MockURLProtocol.register(host: host) { request in try await server.respond(request) }
    }

    deinit {
        session.invalidateAndCancel()
        MockURLProtocol.unregister(host: host)
    }
}

private actor TestCredentials: CredentialStore {
    func password(accountID: UUID) -> String? { "a&b=c" }
    func savePassword(_ password: String, accountID: UUID) {}
    func removePassword(accountID: UUID) {}
}

private actor TestRepository: ReaderRepository {
    var snapshots: [RefreshSnapshot] = []
    var pending: [PendingChange] = []
    func replacePending(_ change: PendingChange) { pending = [change] }
    func replacePending(_ changes: [PendingChange]) { pending = changes }
    func accounts() -> [ReaderAccount] { [] }
    func saveAccount(_ account: ReaderAccount) {}
    func feeds() -> [FeedSnapshot] { [] }
    func folders() -> [FolderSnapshot] { [] }
    func articles(_ query: ArticleQuery) -> [ArticleSnapshot] { [] }
    func applyRefresh(_ snapshot: RefreshSnapshot) { snapshots.append(snapshot) }
    func setStatus(_ keys: [ArticleKey], field: StatusField, value: Bool) {}
    func pendingChanges(accountID: UUID) -> [PendingChange] { pending.filter { $0.article.accountID == accountID } }
    func acknowledge(_ changes: [PendingChange]) {
        let ids = Set(changes.map(\.id))
        pending.removeAll { ids.contains($0.id) }
    }
    func preferences() -> [FeedPreferences] { [] }
    func savePreferences(_ preferences: FeedPreferences) {}
    func digests() -> [DigestSnapshot] { [] }
    func saveDigest(_ digest: DigestSnapshot) {}
    func updateContent(_ key: ArticleKey, html: String, text: String) {}
}

private struct RequestCall: Sendable {
    let path: String
    let query: [String: String]
    let fields: [String: [String]]
    let auth: String?
}

// Shared test synchronization: bounded waits and cancellation leave no continuations behind.
actor RequestGate {
    enum Failure: Error { case didNotEnter, notOpened }
    private var entered = false
    private var opened = false

    func pause(timeout: Duration = .seconds(15)) async throws {
        entered = true
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !opened {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw Failure.notOpened }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func waitUntilEntered(timeout: Duration = .seconds(15)) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !entered {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw Failure.didNotEnter }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func open() { opened = true }
}

struct RequestGateTests {
    @Test("Opening a request gate before entry preserves the release signal")
    func openingGateBeforeEntryPreservesRelease() async throws {
        let gate = RequestGate()
        await gate.open()
        try await gate.pause(timeout: .milliseconds(20))
    }

    @Test("An unreleased request gate fails within its deadline")
    func unreleasedGateFailsWithinDeadline() async {
        let gate = RequestGate()
        await #expect(throws: RequestGate.Failure.notOpened) {
            try await gate.pause(timeout: .milliseconds(20))
        }
    }
}

private actor TestServer {
    enum Failure { case unread, token, mutation, mutationBody, writeBody, missingContent, continuationLoop, expiredWriteToken, secondWrite, emptyMemberships, emptyFolders }
    private var failure: Failure?
    private var gate: RequestGate?
    private var unreadGate: RequestGate?
    private var unreadIDs: Set<String> = ["1"]
    private var writes = 0
    var completedWrites: [Int] = []
    var tokenRequests = 0
    var calls: [RequestCall] = []
    func setFailure(_ value: Failure?) { failure = value }
    func setWriteGate(_ value: RequestGate) { gate = value }
    func setUnreadGate(_ value: RequestGate) { unreadGate = value }

    func respond(_ request: URLRequest) async throws -> (Int, Data) {
        let url = try #require(request.url)
        let path = url.path
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let query = Dictionary(queryItems.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, latest in latest })
        var fields: [String: [String]] = [:]
        if let body = request.httpBody, let encoded = String(data: body, encoding: .utf8) {
            var parts = URLComponents()
            parts.percentEncodedQuery = encoded
            for item in parts.queryItems ?? [] { fields[item.name, default: []].append(item.value ?? "") }
        }
        calls.append(RequestCall(path: path, query: query, fields: fields, auth: request.value(forHTTPHeaderField: "Authorization")))
        if path.hasSuffix("ClientLogin") { return data("SID=ignored\nAuth=auth==\n") }
        if path.hasSuffix("/token") {
            tokenRequests += 1
            if failure == .token { return data("token unavailable", status: 503) }
            return data("write-\(tokenRequests)\n")
        }
        if path.hasSuffix("/subscription/list") {
            let categories = failure == .emptyFolders || failure == .emptyMemberships ? "[]" : "[{\"id\":\"user/-/label/News\"}]"
            return data("{\"subscriptions\":[{\"id\":\"feed/1\",\"title\":\"News\",\"url\":\"https://news.test/feed\",\"htmlUrl\":\"https://news.test\",\"categories\":\(categories)}]}")
        }
        if path.hasSuffix("/tag/list") {
            return data(failure == .emptyFolders ? "{\"tags\":[]}" : "{\"tags\":[{\"id\":\"user/-/label/News\"}]}")
        }
        if path.hasSuffix("/stream/items/ids") {
            if query["xt"] != nil {
                if let unreadGate { try await unreadGate.pause() }
                if failure == .unread { return data("temporarily unavailable", status: 503) }
                let references = unreadIDs.sorted().map { ["id": $0] }
                return (200, try JSONSerialization.data(withJSONObject: ["itemRefs": references]))
            }
            if query["s"] == "user/-/state/com.google/starred" { return data("{\"itemRefs\":[{\"id\":\"2\"}]}") }
            if query["c"] == "next", failure != .continuationLoop { return data("{\"itemRefs\":[{\"id\":\"2\"}]}") }
            return data("{\"itemRefs\":[{\"id\":\"1\"}],\"continuation\":\"next\"}")
        }
        if path.hasSuffix("/stream/items/contents") {
            if failure == .missingContent { return data("{\"items\":[]}") }
            return data("""
            {"items":[{"id":"tag:google.com,2005:reader/item/0000000000000001","title":"Old article","summary":{"content":"<p>Text &amp; Content</p>"},"origin":{"streamId":"feed/1"},"published":946684800,"crawlTimeMsec":"1792830000000"},{"id":"tag:google.com,2005:reader/item/0000000000000002","title":"Second article","summary":{"content":"Text"},"origin":{"streamId":"feed/1"}}]}
            """)
        }
        if path.hasSuffix("/edit-tag") {
            writes += 1
            let current = writes
            defer { completedWrites.append(current) }
            if current == 1, let gate { try await gate.pause() }
            if failure == .secondWrite, current == 2 { return data("failure", status: 500) }
            if failure == .writeBody { return data("Error=notApplied") }
            if failure == .expiredWriteToken, fields["T"] == ["write-1"] { return data("expired", status: 403) }
            let ids = try Set((fields["i"] ?? []).map(ReaderItemID.canonical))
            if fields["a"] == ["user/-/state/com.google/read"] { unreadIDs.subtract(ids) }
            if fields["r"] == ["user/-/state/com.google/read"] { unreadIDs.formUnion(ids) }
            return data("OK")
        }
        if path.hasSuffix("/subscription/edit") { return data("failure", status: failure == .mutation ? 500 : 200) }
        throw ReaderError.invalidResponse
    }

    private func data(_ value: String, status: Int = 200) -> (Int, Data) { (status, Data(value.utf8)) }
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async throws -> (Int, Data)
    private struct Route: Sendable { var handler: Handler; var mimeType: String? }
    private static let handlers = Mutex<[String: Route]>([:])
    private let runningTask = Mutex<Task<Void, Never>?>(nil)
    static func register(host: String, mimeType: String? = nil, handler: @escaping Handler) {
        handlers.withLock { $0[host] = Route(handler: handler, mimeType: mimeType) }
    }
    static func unregister(host: String) { handlers.withLock { $0[host] = nil } }
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let handler = Self.handlers.withLock { $0[request.url?.host ?? ""] }
        var request = request
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(contentsOf: buffer.prefix(count))
            }
            request.httpBody = body
        }
        let capturedRequest = request
        let task = Task { @Sendable [self, handler, capturedRequest] in
            do {
                guard let handler, let url = capturedRequest.url else { throw ReaderError.invalidResponse }
                let (status, data) = try await handler.handler(capturedRequest)
                try Task.checkCancellation()
                guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                                     headerFields: handler.mimeType.map { ["Content-Type": $0] }) else {
                    throw ReaderError.invalidResponse
                }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
        runningTask.withLock { $0 = task }
    }
    override func stopLoading() { runningTask.withLock { $0?.cancel(); $0 = nil } }
}
