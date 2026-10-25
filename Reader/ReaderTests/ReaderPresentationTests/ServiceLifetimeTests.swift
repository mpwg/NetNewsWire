import Foundation
import Security
import Testing
import ReaderDomain
import ReaderPersistence
@testable import ReaderSync
import ReaderContent
import ReaderIntelligence
import ReaderUI

@MainActor
struct ServiceLifetimeTests {
    enum Outcome: String, CaseIterable, Sendable { case success, failure, cancelledWindow }

    @Test("Service graphs release after owned work and observers finish", .timeLimit(.minutes(1)),
          arguments: Outcome.allCases)
    func serviceGraphsReleaseAfterOwnedWorkEnds(outcome: Outcome) async throws {
        let graph = try await Self.exerciseGraph(outcome: outcome)
        let retained = try await graph.retainedAfterSettling()
        #expect(retained.isEmpty, "Retained objects: \(retained)")
    }

    private static func exerciseGraph(outcome: Outcome) async throws -> WeakServiceGraph {
        let fixture = try LifetimeFixture(failing: outcome == .failure)
        let graph = WeakServiceGraph(fixture)
        try await fixture.exercise(outcome: outcome)
        return graph
    }
}

@MainActor
private final class LifetimeFixture {
    let store: ReaderStore
    let credentials: KeychainCredentialStore
    let client: FreshRSSClient
    let icons: IconService
    let images: FeedImageService
    let content: ArticleContentService
    let generator: LifetimeGenerator
    let digests: DigestCoordinator
    let services: ReaderServices
    let session: ReaderSession
    let transport: URLSession
    let server: LifetimeServer
    let gate = RequestGate()
    let host: String
    let account: ReaderAccount
    let feed: FeedSnapshot

    init(failing: Bool) throws {
        host = UUID().uuidString.lowercased() + ".test"
        account = ReaderAccount(serverURL: try #require(URL(string: "https://" + host)), username: "lifetime-fixture")
        feed = FeedSnapshot(id: FeedKey(accountID: account.id, remoteID: "feed/fixture"), title: "Lifetime feed",
                            url: account.serverURL.appendingPathComponent("feed.xml"))
        store = try ReaderStore(inMemory: true)
        credentials = KeychainCredentialStore(service: UUID().uuidString, access: LifetimeKeychainAccess())
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        transport = URLSession(configuration: configuration)
        server = LifetimeServer(gate: gate, failing: failing)
        client = FreshRSSClient(repository: store, credentials: credentials, session: transport)
        icons = IconService(session: transport)
        images = FeedImageService(icons: icons)
        content = ArticleContentService(session: transport)
        generator = LifetimeGenerator()
        digests = DigestCoordinator(repository: store, generator: generator, extractor: content)
        services = ReaderServices(repository: store, credentials: credentials, client: client,
                                  digests: digests, content: content, images: images)
        session = ReaderSession(services: services)
        let server = server
        MockURLProtocol.register(host: host) { try await server.respond($0) }
    }

    func exercise(outcome: ServiceLifetimeTests.Outcome) async throws {
        try await store.saveAccount(account)
        let article = ArticleSnapshot(id: ArticleKey(accountID: account.id, remoteID: "1"),
                                      feedID: feed.id.remoteID, title: "Original",
                                      text: String(repeating: "Retained source content. ", count: 40))
        try await store.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: [feed], folders: [],
                                                    articles: [article], unreadIDs: ["1"], starredIDs: []))
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest))
        let observer = Task { [session] in await session.observeChanges() }
        defer { observer.cancel() }
        #expect(try await digests.generate(feed: feed).count == 1)
        #expect(await generator.calls == 1)
        let request = Task { [services] in try await services.refreshIfNeeded(force: true) }
        let gate = gate
        defer { request.cancel(); Task { await gate.open() } }
        try await gate.waitUntilEntered()
        if outcome == .cancelledWindow { request.cancel() }
        await gate.open()
        if outcome == .failure {
            await #expect(throws: ReaderError.server(503)) { try await request.value }
        } else { try await request.value }
        #expect(try await images.image(for: account.serverURL.appendingPathComponent("no-icon"), maximumPixelSize: 32) == nil)
        observer.cancel()
        await observer.value
    }

    deinit {
        transport.invalidateAndCancel()
        MockURLProtocol.unregister(host: host)
    }
}

@MainActor
private final class WeakServiceGraph {
    weak var store: ReaderStore?
    weak var credentials: KeychainCredentialStore?
    weak var client: FreshRSSClient?
    weak var icons: IconService?
    weak var images: FeedImageService?
    weak var content: ArticleContentService?
    weak var generator: LifetimeGenerator?
    weak var digests: DigestCoordinator?
    weak var services: ReaderServices?
    weak var session: ReaderSession?
    weak var transport: URLSession?
    weak var server: LifetimeServer?

    init(_ fixture: LifetimeFixture) {
        store = fixture.store; credentials = fixture.credentials; client = fixture.client
        icons = fixture.icons; images = fixture.images; content = fixture.content
        generator = fixture.generator; digests = fixture.digests; services = fixture.services
        session = fixture.session; transport = fixture.transport; server = fixture.server
    }

    private var retainedNames: [String] {
        [store == nil ? nil : "store", credentials == nil ? nil : "credentials", client == nil ? nil : "client",
         icons == nil ? nil : "icons", images == nil ? nil : "images", content == nil ? nil : "content",
         generator == nil ? nil : "generator", digests == nil ? nil : "digests", services == nil ? nil : "services",
         session == nil ? nil : "session", transport == nil ? nil : "transport", server == nil ? nil : "server"].compactMap { $0 }
    }

    func retainedAfterSettling() async throws -> [String] {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        var retained = retainedNames
        while !retained.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
            retained = retainedNames
        }
        return retained
    }
}

private actor LifetimeServer {
    private let gate: RequestGate
    private let failing: Bool
    init(gate: RequestGate, failing: Bool) { self.gate = gate; self.failing = failing }

    func respond(_ request: URLRequest) async throws -> (Int, Data) {
        let path = try #require(request.url?.path)
        if path.hasSuffix("ClientLogin") { return (200, Data("SID=fixture\nAuth=fixture-auth\n".utf8)) }
        if path.hasSuffix("/subscription/list") {
            try await gate.pause()
            return (failing ? 503 : 200, Data(#"{"subscriptions":[]}"#.utf8))
        }
        if path.hasSuffix("/tag/list") { return (200, Data(#"{"tags":[]}"#.utf8)) }
        if path.hasSuffix("/stream/items/ids") { return (200, Data(#"{"itemRefs":[]}"#.utf8)) }
        return (404, Data())
    }
}

private actor LifetimeGenerator: SummaryGenerator {
    var calls = 0
    func summarize(_ articles: [ArticleSnapshot], cloudAllowed: Bool) -> [DigestSection] {
        calls += 1
        return [DigestSection(title: "Fixture", text: "Sourced fixture summary", sources: articles.map(\.id))]
    }
}

private struct LifetimeKeychainAccess: KeychainAccess {
    func copyMatching(_ query: [CFString: Any]) -> (OSStatus, Data?) { (errSecSuccess, Data("fixture-api-password".utf8)) }
    func update(_ query: [CFString: Any], attributes: [CFString: Any]) -> OSStatus { errSecSuccess }
    func add(_ query: [CFString: Any]) -> OSStatus { errSecSuccess }
    func remove(_ query: [CFString: Any]) -> OSStatus { errSecSuccess }
}
