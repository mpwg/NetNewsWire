import Foundation
import Testing
import ReaderContent
import ReaderDomain
import ReaderPersistence
import ReaderUI

@MainActor
struct ReaderExtractionTests {
    enum LateOutcome: CaseIterable, Sendable {
        case successInB, failureInB, successAfterRoundTrip, failureAfterRoundTrip
        var fails: Bool { self == .failureInB || self == .failureAfterRoundTrip }
        var returnsToA: Bool { self == .successAfterRoundTrip || self == .failureAfterRoundTrip }
    }

    @Test("An old extraction cannot publish content or errors across selection generations",
          .timeLimit(.minutes(1)), arguments: LateOutcome.allCases)
    func oldExtractionCannotPublishAcrossSelections(outcome: LateOutcome) async throws {
        let fixture = try await ExtractionFixture(failFirst: outcome.fails)
        let task = Task { await fixture.session.extract(fixture.a) }
        defer { task.cancel(); Task { await fixture.gate.open() } }
        try await fixture.gate.waitUntilEntered()
        fixture.session.selection = .article(fixture.b.id)
        if outcome.returnsToA { fixture.session.selection = .article(fixture.a.id) }
        fixture.session.errorMessage = "Current view status"
        await fixture.gate.open()
        await task.value
        #expect(fixture.session.errorMessage == "Current view status")
        #expect(fixture.services.revision == 0)
        #expect(try await fixture.store.article(fixture.a.id) == fixture.a)
        #expect(try await fixture.store.article(fixture.b.id) == fixture.b)
        #expect(fixture.session.selectedArticle?.id == (outcome.returnsToA ? fixture.a.id : fixture.b.id))
        #expect(try await fixture.store.pendingChanges(accountID: fixture.account.id).isEmpty)
    }

    @Test("An older request for the same article cannot replace a newer extraction or its status",
          .timeLimit(.minutes(1)), arguments: [false, true])
    func olderRequestCannotReplaceNewerExtraction(fails: Bool) async throws {
        let fixture = try await ExtractionFixture(failFirst: fails)
        let first = Task { await fixture.session.extract(fixture.a) }
        defer { first.cancel(); Task { await fixture.gate.open() } }
        try await fixture.gate.waitUntilEntered()
        await fixture.session.extract(fixture.a)
        let latest = try #require(try await fixture.store.article(fixture.a.id))
        #expect(latest.text.contains("New extraction"))
        #expect(fixture.services.revision == 1)
        #expect(fixture.session.errorMessage == nil)
        await fixture.gate.open()
        await first.value
        #expect(try await fixture.store.article(fixture.a.id) == latest)
        #expect(fixture.session.selectedArticle == latest)
        #expect(fixture.services.revision == 1)
        #expect(fixture.session.errorMessage == nil)
    }

    @Test("A newer failed request supersedes an older successful request", .timeLimit(.minutes(1)))
    func newerFailureSupersedesOldSuccess() async throws {
        let fixture = try await ExtractionFixture(failSecond: true)
        let first = Task { await fixture.session.extract(fixture.a) }
        defer { first.cancel(); Task { await fixture.gate.open() } }
        try await fixture.gate.waitUntilEntered()
        await fixture.session.extract(fixture.a)
        #expect(fixture.session.errorMessage == ReaderError.server(403).localizedDescription)
        await fixture.gate.open()
        await first.value
        #expect(fixture.services.revision == 0)
        #expect(try await fixture.store.article(fixture.a.id) == fixture.a)
        #expect(fixture.session.errorMessage == ReaderError.server(403).localizedDescription)
    }

    @Test("Current extraction success and HTTP failure still reach the selected article",
          .timeLimit(.minutes(1)), arguments: [false, true])
    func currentExtractionPublishesItsOwnOutcome(fails: Bool) async throws {
        let fixture = try await ExtractionFixture(failFirst: fails)
        await fixture.gate.open()
        await fixture.session.extract(fixture.a)
        if fails {
            #expect(fixture.session.errorMessage == ReaderError.server(403).localizedDescription)
            #expect(fixture.services.revision == 0)
            #expect(try await fixture.store.article(fixture.a.id) == fixture.a)
        } else {
            let stored = try #require(try await fixture.store.article(fixture.a.id))
            #expect(stored.text.contains("Old extraction"))
            #expect(stored.html.contains("https://" + fixture.host + "/relative"))
            #expect(fixture.session.selectedArticle == stored)
            #expect(fixture.services.revision == 1)
            #expect(fixture.session.errorMessage == nil)
        }
        #expect(try await fixture.store.article(fixture.b.id) == fixture.b)
        #expect(try await fixture.store.pendingChanges(accountID: fixture.account.id).isEmpty)
    }

    @Test("A detail lookup for the same selection does not invalidate extraction", .timeLimit(.minutes(1)))
    func sameSelectionLookupDoesNotInvalidateExtraction() async throws {
        let fixture = try await ExtractionFixture()
        let task = Task { await fixture.session.extract(fixture.a) }
        defer { task.cancel(); Task { await fixture.gate.open() } }
        try await fixture.gate.waitUntilEntered()
        await fixture.session.loadSelectedArticle()
        await fixture.gate.open()
        await task.value
        #expect(fixture.session.selectedArticle?.text.contains("Old extraction") == true)
        #expect(fixture.services.revision == 1)
        #expect(fixture.session.errorMessage == nil)
    }

    @Test("A full-text failure belongs to its selection and a new request clears it", .timeLimit(.minutes(1)))
    func fullTextFailureFollowsSelectionAndRetry() async throws {
        let fixture = try await ExtractionFixture(failFirst: true)
        await fixture.gate.open()
        await fixture.session.extract(fixture.a)
        #expect(fixture.session.fullTextError == ReaderError.server(403).localizedDescription)
        fixture.session.selection = .article(fixture.b.id)
        #expect(fixture.session.fullTextError == nil)
        fixture.session.selection = .article(fixture.a.id)
        fixture.session.errorMessage = nil
        await fixture.session.extract(fixture.a)
        #expect(fixture.session.fullTextError == nil)
        #expect(fixture.session.errorMessage == nil)
        #expect(fixture.session.selectedArticle?.text.contains("New extraction") == true)
    }

    @Test("Already parsed content or failure cannot publish after another article finishes",
          .timeLimit(.minutes(1)), arguments: [false, true])
    func parsedOutcomeCannotPublishAfterAnotherArticle(fails: Bool) async throws {
        let fixture = try await ExtractionFixture(failFirst: fails, holdResult: true)
        let delivery = try #require(fixture.deliveryGate)
        await fixture.gate.open()
        let first = Task { await fixture.session.extract(fixture.a) }
        defer { first.cancel(); Task { await delivery.open() } }
        try await delivery.waitUntilEntered()
        #expect(await fixture.delivery?.resultsCaptured == 1)
        fixture.session.selection = .article(fixture.b.id)
        await fixture.session.extract(fixture.b)
        let latestB = try #require(try await fixture.store.article(fixture.b.id))
        #expect(latestB.text.contains("New extraction"))
        #expect(fixture.session.selectedArticle == latestB)
        #expect(fixture.services.revision == 1)
        await delivery.open()
        await first.value
        #expect(fixture.session.selectedArticle == latestB)
        #expect(try await fixture.store.article(fixture.a.id) == fixture.a)
        #expect(try await fixture.store.article(fixture.b.id) == latestB)
        #expect(fixture.session.errorMessage == nil)
        #expect(fixture.session.fullTextError == nil)
        #expect(fixture.services.revision == 1)
    }

    enum CancellationPoint: CaseIterable, Sendable { case beforeRequest, whileLoading, afterParsing }

    @Test("Cancelled extraction ends while HTTP is held without content, revisions or alerts",
          .timeLimit(.minutes(1)), arguments: CancellationPoint.allCases)
    func cancelledExtractionHasNoSideEffects(point: CancellationPoint) async throws {
        let fixture = try await ExtractionFixture(holdResult: point == .afterParsing)
        if point == .afterParsing { await fixture.gate.open() }
        let completion = ExtractionCompletion()
        let request = Task {
            if point == .beforeRequest { withUnsafeCurrentTask { $0?.cancel() } }
            await fixture.session.extract(fixture.a)
            completion.finished = true
        }
        defer { request.cancel(); Task { await fixture.gate.open(); await fixture.deliveryGate?.open() } }
        if point == .whileLoading {
            try await fixture.gate.waitUntilEntered()
            request.cancel()
        } else if point == .afterParsing {
            try await fixture.deliveryGate?.waitUntilEntered()
            request.cancel()
        }
        #expect(try await waitUntil { completion.finished })
        if point == .whileLoading {
            #expect(try await waitUntil { await fixture.server.cancellations == 1 })
        }
        #expect(await fixture.server.requests == (point == .beforeRequest ? 0 : 1))
        #expect(fixture.session.errorMessage == nil)
        #expect(fixture.services.revision == 0)
        #expect(try await fixture.store.article(fixture.a.id) == fixture.a)
        await fixture.gate.open()
        await request.value
    }

    enum LifetimeOutcome: CaseIterable, Sendable { case success, failure, cancelled, cancelledAfterParsing }

    @Test("Extraction graphs release after success, failure and cancelled loading",
          .timeLimit(.minutes(1)), arguments: LifetimeOutcome.allCases)
    func extractionGraphsRelease(outcome: LifetimeOutcome) async throws {
        let graph = try await exerciseLifetime(outcome)
        #expect(try await waitUntil { graph.released })
    }

    private func exerciseLifetime(_ outcome: LifetimeOutcome) async throws -> WeakExtractionGraph {
        let fixture = try await ExtractionFixture(failFirst: outcome == .failure, holdResult: outcome == .cancelledAfterParsing)
        if outcome == .cancelledAfterParsing { await fixture.gate.open() }
        let graph = WeakExtractionGraph(fixture)
        let completion = ExtractionCompletion()
        let request = Task { [session = fixture.session, article = fixture.a] in
            await session.extract(article)
            completion.finished = true
        }
        defer { request.cancel(); Task { await fixture.gate.open(); await fixture.deliveryGate?.open() } }
        try await fixture.gate.waitUntilEntered()
        if outcome == .cancelledAfterParsing {
            try await fixture.deliveryGate?.waitUntilEntered()
            request.cancel()
            #expect(try await waitUntil { completion.finished })
        } else if outcome == .cancelled {
            request.cancel()
            #expect(try await waitUntil { completion.finished })
            #expect(try await waitUntil { await fixture.server.cancellations == 1 })
        }
        await fixture.gate.open()
        await request.value
        #expect(completion.finished)
        return graph
    }

    private func waitUntil(_ condition: () async -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !(await condition()) {
            if ContinuousClock.now >= deadline { return false }
            try await Task.sleep(for: .milliseconds(10))
        }
        return true
    }
}

@MainActor
private final class ExtractionCompletion { var finished = false }

@MainActor
private final class ExtractionFixture {
    let host: String
    let account: ReaderAccount
    let store: ReaderStore
    let a: ArticleSnapshot
    let b: ArticleSnapshot
    let transport: URLSession
    let content: ArticleContentService
    let services: ReaderServices
    let session: ReaderSession
    let gate = RequestGate()
    let deliveryGate: RequestGate?
    let delivery: HeldExtractionResult?
    let server: ExtractionServer

    init(failFirst: Bool = false, failSecond: Bool = false, holdResult: Bool = false) async throws {
        host = UUID().uuidString.lowercased() + ".extraction.test"
        let url = try #require(URL(string: "https://" + host))
        account = ReaderAccount(serverURL: url, username: "extraction-fixture")
        store = try ReaderStore(inMemory: true)
        let feed = FeedSnapshot(id: FeedKey(accountID: account.id, remoteID: "articles"), title: "Articles", url: url)
        a = ArticleSnapshot(id: ArticleKey(accountID: account.id, remoteID: "a"), feedID: feed.id.remoteID,
                            title: "Article A", html: "<p>Saved A</p>", text: "Saved A", url: url.appendingPathComponent("a"),
                            dateArrived: Date(timeIntervalSince1970: 1))
        b = ArticleSnapshot(id: ArticleKey(accountID: account.id, remoteID: "b"), feedID: feed.id.remoteID,
                            title: "Article B", html: "<p>Saved B</p>", text: "Saved B", url: url.appendingPathComponent("b"),
                            dateArrived: Date(timeIntervalSince1970: 2))
        try await store.saveAccount(account)
        try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: [feed], folders: [], articles: [a, b],
                                                    unreadIDs: ["a", "b"], starredIDs: []))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.urlCache = nil
        transport = URLSession(configuration: configuration)
        content = ArticleContentService(session: transport)
        if holdResult {
            let resultGate = RequestGate()
            let held = HeldExtractionResult(base: content, gate: resultGate)
            deliveryGate = resultGate
            delivery = held
            services = ReaderServices(repository: store, content: held)
        } else {
            deliveryGate = nil
            delivery = nil
            services = ReaderServices(repository: store, content: content)
        }
        session = ReaderSession(services: services)
        server = ExtractionServer(gate: gate, failFirst: failFirst, failSecond: failSecond)
        let server = server
        MockURLProtocol.register(host: host) { try await server.respond($0) }
        await session.reload()
        session.selection = .article(a.id)
    }

    deinit {
        transport.invalidateAndCancel()
        MockURLProtocol.unregister(host: host)
    }
}

private actor ExtractionServer {
    let gate: RequestGate
    let failFirst: Bool
    let failSecond: Bool
    private(set) var requests = 0
    private(set) var cancellations = 0

    init(gate: RequestGate, failFirst: Bool, failSecond: Bool) {
        self.gate = gate; self.failFirst = failFirst; self.failSecond = failSecond
    }

    func respond(_ request: URLRequest) async throws -> (Int, Data) {
        requests += 1
        let first = requests == 1
        if first {
            do { try await gate.pause() } catch {
                if Task.isCancelled { cancellations += 1 }
                throw error
            }
        }
        if first ? failFirst : failSecond { return (403, Data("Access denied".utf8)) }
        let marker = first ? "Old extraction" : "New extraction"
        let text = String(repeating: marker + " contains representative article content. ", count: 40)
        return (200, Data(("<html><body><article><h1>" + marker + "</h1><p>" + text +
                           "</p><p><a href='/relative'>Relative link</a></p></article></body></html>").utf8))
    }
}

private actor HeldExtractionResult: ArticleContentExtracting {
    let base: ArticleContentService
    let gate: RequestGate
    private(set) var resultsCaptured = 0

    init(base: ArticleContentService, gate: RequestGate) { self.base = base; self.gate = gate }

    func extract(url: URL) async throws -> ExtractedContent {
        let first = resultsCaptured == 0
        let result: Result<ExtractedContent, any Error>
        do { result = .success(try await base.extract(url: url)) } catch { result = .failure(error) }
        resultsCaptured += 1
        if first { try await gate.pause() }
        return try result.get()
    }
}

@MainActor
private final class WeakExtractionGraph {
    weak var session: ReaderSession?
    weak var services: ReaderServices?
    weak var content: ArticleContentService?
    weak var transport: URLSession?
    weak var store: ReaderStore?
    weak var server: ExtractionServer?
    weak var delivery: HeldExtractionResult?

    init(_ fixture: ExtractionFixture) {
        session = fixture.session; services = fixture.services; content = fixture.content
        transport = fixture.transport; store = fixture.store; server = fixture.server; delivery = fixture.delivery
    }

    var released: Bool { session == nil && services == nil && content == nil && transport == nil && store == nil && server == nil && delivery == nil }
}
