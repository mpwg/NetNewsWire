import Foundation
import Testing
import ReaderDomain
import ReaderPersistence
import ReaderIntelligence

// Deterministic model output keeps these contracts independent of model availability.
private struct FixtureGenerator: SummaryGenerator {
    var omitLast = false
    var invalid = false
    func summarize(_ articles: [ArticleSnapshot], cloudAllowed: Bool) async throws -> [DigestSection] {
        if invalid { return [DigestSection(title: "Invalid", text: "", sources: [ArticleKey(accountID: UUID(), remoteID: "wrong")])] }
        let sources = omitLast ? Array(articles.dropLast()) : articles
        return [DigestSection(title: "Offers", text: "Sourced digest", sources: sources.map(\.id))]
    }
}

private enum GeneratorGateError: Error {
    case didNotStart
    case wasNotReleased
}

private actor ControlledGenerator: SummaryGenerator {
    private var started = false
    private var released = false
    private(set) var observedCloudPermission: Bool?

    func summarize(_ articles: [ArticleSnapshot], cloudAllowed: Bool) async throws -> [DigestSection] {
        throw ReaderError.invalidResponse
    }

    func summarize(_ articles: [ArticleSnapshot], cloudPermission: @escaping @Sendable () async throws -> Bool) async throws -> [DigestSection] {
        started = true
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !released {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw GeneratorGateError.wasNotReleased }
            try await Task.sleep(for: .milliseconds(10))
        }
        observedCloudPermission = try await cloudPermission()
        return [DigestSection(title: "Digest", text: "Sourced", sources: articles.map(\.id))]
    }

    func waitUntilStarted(timeout: Duration = .seconds(5)) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !started {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw GeneratorGateError.didNotStart }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func release() { released = true }
}

struct DigestTests {
    @Test("A generator gate fails promptly when generation never starts")
    func generatorGateFailsWhenGenerationNeverStarts() async {
        let model = ControlledGenerator()
        await #expect(throws: GeneratorGateError.didNotStart) {
            try await model.waitUntilStarted(timeout: .milliseconds(20))
        }
    }

    @Test("Cancelling generation releases the generator gate")
    func cancellingGenerationReleasesGeneratorGate() async throws {
        let model = ControlledGenerator()
        defer { Task { await model.release() } }
        let generation = Task { try await model.summarize([], cloudPermission: { false }) }
        try await model.waitUntilStarted()
        generation.cancel()
        await #expect(throws: CancellationError.self) { try await generation.value }
    }

    private func fixture(count: Int = 2) async throws -> (ReaderStore, FeedSnapshot, [ArticleSnapshot]) {
        let store = try ReaderStore(inMemory: true)
        let account = UUID()
        let feed = FeedSnapshot(id: FeedKey(accountID: account, remoteID: "feed/1"), title: "Preisjäger", url: try #require(URL(string: "https://example.org/rss")))
        let articles = (0..<count).map { index in
            ArticleSnapshot(id: ArticleKey(accountID: account, remoteID: String(index)), feedID: feed.id.remoteID,
                title: "Offer \(index)", text: String(repeating: "Source text ", count: 60),
                dateArrived: Date(timeIntervalSince1970: 1_790_000_000 + Double(index)))
        }
        try await store.applyRefresh(RefreshSnapshot(accountID: account, feeds: [feed], folders: [], articles: articles,
            unreadIDs: Set(articles.map(\.id.remoteID)), starredIDs: []))
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest, timeZoneID: "Europe/Vienna"))
        return (store, feed, articles)
    }

    @Test("All sources remain accessible when model coverage is incomplete") func allSourcesRemainAccessibleWhenModelCoverageIsIncomplete() async throws {
        let (store, feed, articles) = try await fixture(count: 250)
        let coordinator = DigestCoordinator(repository: store, generator: FixtureGenerator(omitLast: true))
        let digests = try await coordinator.generate(feed: feed)
        #expect(Set(digests.flatMap(\.sources)) == Set(articles.map(\.id)))
        #expect(Set(digests.flatMap(\.sections).flatMap(\.sources)) == Set(articles.map(\.id)))
        #expect(digests.contains { $0.warning != nil })
    }

    @Test("Marking a digest read applies only to the displayed revision") func markingADigestReadAppliesOnlyToTheDisplayedRevision() async throws {
        let (store, feed, articles) = try await fixture()
        let coordinator = DigestCoordinator(repository: store, generator: FixtureGenerator())
        let old = try #require(try await coordinator.generate(feed: feed).first)
        let later = ArticleSnapshot(id: ArticleKey(accountID: feed.id.accountID, remoteID: "later"),
            feedID: feed.id.remoteID, title: "New", text: String(repeating: "Source text ", count: 60), dateArrived: articles[0].dateArrived)
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: [feed], folders: [],
            articles: articles + [later], unreadIDs: Set((articles + [later]).map(\.id.remoteID)), starredIDs: []))
        _ = try await coordinator.generate(feed: feed)
        try await coordinator.markRead(old)
        #expect(try await store.article(later.id)?.read == false)
        #expect(try await store.article(articles[0].id)?.read == true)
    }

    @Test("Invalid model source references are not saved") func invalidModelSourceReferencesAreNotSaved() async throws {
        let (store, feed, _) = try await fixture()
        let coordinator = DigestCoordinator(repository: store, generator: FixtureGenerator(invalid: true))
        await #expect(throws: ReaderError.invalidResponse) { try await coordinator.generate(feed: feed) }
        #expect(try await store.digests().isEmpty)
    }

    @Test("Changed source text regenerates a digest") func changedSourceTextRegeneratesADigest() async throws {
        let (store, feed, articles) = try await fixture()
        let coordinator = DigestCoordinator(repository: store, generator: FixtureGenerator())
        let before = try #require(try await coordinator.generate(feed: feed).first)
        var changed = articles
        changed[0].text = String(repeating: "New source text ", count: 60)
        try await store.applyRefresh(RefreshSnapshot(accountID: feed.id.accountID, feeds: [feed], folders: [], articles: changed,
            unreadIDs: Set(changed.map(\.id.remoteID)), starredIDs: []))
        let after = try #require(try await coordinator.generate(feed: feed).first)
        #expect(after.revision != before.revision)
        #expect(after.sourceFingerprint != before.sourceFingerprint)
    }

    @Test("Revoked cloud consent applies to ongoing work") func revokedCloudConsentAppliesToOngoingWork() async throws {
        let (store, feed, _) = try await fixture()
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest, cloudAllowed: true))
        let model = ControlledGenerator()
        defer { Task { await model.release() } }
        let coordinator = DigestCoordinator(repository: store, generator: model)
        let generation = Task { try await coordinator.generate(feed: feed) }
        try await model.waitUntilStarted()
        try await store.savePreferences(FeedPreferences(id: feed.id, mode: .digest, cloudAllowed: false))
        await model.release()
        _ = try await generation.value
        #expect(await model.observedCloudPermission == false)
    }

    @Test("Model responses for changed sources are not saved") func modelResponsesForChangedSourcesAreNotSaved() async throws {
        let (store, feed, articles) = try await fixture()
        let model = ControlledGenerator()
        defer { Task { await model.release() } }
        let coordinator = DigestCoordinator(repository: store, generator: model)
        let generation = Task { try await coordinator.generate(feed: feed) }
        try await model.waitUntilStarted()
        try await store.updateContent(articles[0].id, html: "New article", text: "New")
        await model.release()
        await #expect(throws: ReaderError.staleResult) { try await generation.value }
        #expect(try await store.digests().isEmpty)
    }

    @Test("Cancelling a window task does not cancel the owned digest job") func cancellingAWindowTaskDoesNotCancelTheOwnedDigestJob() async throws {
        let (store, feed, _) = try await fixture()
        let model = ControlledGenerator()
        defer { Task { await model.release() } }
        let coordinator = DigestCoordinator(repository: store, generator: model)
        let window = Task { try await coordinator.generate(feed: feed) }
        try await model.waitUntilStarted()
        window.cancel()
        await model.release()
        let result = try await window.value
        #expect(!result.isEmpty)
        #expect(try await store.digests().count == result.count)
    }
}
