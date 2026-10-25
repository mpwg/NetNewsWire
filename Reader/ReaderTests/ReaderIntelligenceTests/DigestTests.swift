import Foundation
import Testing
import ReaderDomain
import ReaderPersistence
import FoundationModels
@testable import ReaderIntelligence

private struct ControlledLanguageModel: LanguageModel {
    typealias Executor = ControlledModelExecutor
    let journal: ModelRequestJournal
    var capabilities: LanguageModelCapabilities { LanguageModelCapabilities([.guidedGeneration]) }
    var executorConfiguration: Int { 0 }
}

private struct ControlledModelExecutor: LanguageModelExecutor {
    typealias Model = ControlledLanguageModel
    init(configuration: Int) {}
    func respond(to request: LanguageModelExecutorGenerationRequest, model: ControlledLanguageModel,
                 streamingInto channel: LanguageModelExecutorGenerationChannel) async throws {
        let response = try await model.journal.record(request)
        await channel.send(.response(action: .appendText(response, segmentID: nil, tokenCount: 20)))
    }
}

private actor ModelRequestJournal {
    let response: String
    let failure: (any Error)?
    private(set) var requests: [LanguageModelExecutorGenerationRequest] = []
    init(response: String = #"{"groups":[]}"#, failure: (any Error)? = nil) {
        self.response = response
        self.failure = failure
    }
    func record(_ request: LanguageModelExecutorGenerationRequest) throws -> String {
        requests.append(request)
        if let failure { throw failure }
        return response
    }
}

struct AppleSummaryGeneratorTests {

    @Test("Long source text reaches native sessions without loss within the runtime budget", arguments: [3500, 4500])
    func longSourceChunksPreserveContent(capacity: Int) async throws {
        let journal = ModelRequestJournal()
        var source = try article()
        source.text = String(repeating: "Unicode source 🧪 café. ", count: 300)
        _ = try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                      capacity: capacity, count: { $0.count })
        let requests = await journal.requests
        #expect(requests.count > 1)
        var reconstructed = ""
        for request in requests {
            let prompt = request.transcript.compactMap { entry -> String? in
                guard case .prompt(let prompt) = entry else { return nil }
                return prompt.segments.compactMap { segment -> String? in
                    guard case .text(let text) = segment else { return nil }
                    return text.content
                }.joined()
            }.joined()
            let instructions = request.transcript.compactMap { entry -> String? in
                guard case .instructions(let instructions) = entry else { return nil }
                return instructions.segments.compactMap { segment -> String? in
                    guard case .text(let text) = segment else { return nil }
                    return text.content
                }.joined()
            }.joined()
            #expect(!prompt.isEmpty)
            #expect(prompt.count <= capacity - instructions.count - 2000)
            #expect(request.enabledToolDefinitions.isEmpty)
            reconstructed += prompt.replacingOccurrences(of: "Source 0:\n", with: "").replacingOccurrences(of: "\n", with: "")
        }
        #expect(reconstructed == (source.title + source.text).replacingOccurrences(of: "\n", with: ""))
    }

    @Test("An unconfigured PCC backend rejects before consent or a model request")
    func unconfiguredCloudIsNeverRequested() async {
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().cloudSummary([], permission: { throw CancellationError() })
        }
    }

    @Test("Revoked cloud consent is rejected before instantiating the PCC model")
    func cloudRequiresLiveConsentBeforeInstantiation() async {
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator(privateCloudComputeEnabled: true).cloudSummary([], permission: { false })
        }
    }

    @Test("Native framework errors propagate unchanged from the shipping session",
          arguments: [0, 1, 2, 3])
    func frameworkErrorsPropagate(kind: Int) async throws {
        let failure: any Error
        switch kind {
        case 0: failure = LanguageModelError.guardrailViolation(.init(debugDescription: "Controlled guardrail"))
        case 1: failure = LanguageModelError.contextSizeExceeded(.init(contextSize: 100, tokenCount: 200, debugDescription: "Controlled context"))
        case 2: failure = PrivateCloudComputeLanguageModel.Error.quotaLimitReached(.init(limitIncreaseSuggestion: nil, resetDate: nil,
                                                                                       debugDescription: "Controlled quota"))
        default: failure = SystemLanguageModel.Error.assetsUnavailable(.init(debugDescription: "Controlled missing assets"))
        }
        let journal = ModelRequestJournal(failure: failure)
        let source = try article()
        let received = await #expect(throws: (any Error).self) {
            try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 10000, count: { $0.count })
        }
        let error = try #require(received)
        #expect(String(reflecting: type(of: error)) == String(reflecting: type(of: failure)))
        #expect(error.localizedDescription == failure.localizedDescription)
        #expect(await journal.requests.count == 1)
    }

    @Test("An insufficient runtime context budget fails before requesting model output")
    func insufficientBudgetMakesNoRequest() async throws {
        let journal = ModelRequestJournal()
        let source = try article()
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 2200, count: { $0.count })
        }
        #expect(await journal.requests.isEmpty)
    }

    @Test("Cloud permission is rechecked before each chunk and prevents later requests")
    func revokedPermissionStopsLaterChunks() async throws {
        let journal = ModelRequestJournal()
        var source = try article()
        source.text = String(repeating: "Long source material ", count: 200)
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 4000, cloudPermission: { await journal.requests.isEmpty },
                                                      count: { $0.count })
        }
        #expect(await journal.requests.count == 1)
    }

    @Test("Cancellation from the native model remains cancellation")
    func modelCancellationPropagates() async throws {
        let journal = ModelRequestJournal(failure: CancellationError())
        let source = try article()
        await #expect(throws: CancellationError.self) {
            try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 10000, count: { $0.count })
        }
        #expect(await journal.requests.count == 1)
    }
    private func article() throws -> ArticleSnapshot {
        let url = try #require(URL(string: "https://stored.test/article"))
        return ArticleSnapshot(id: ArticleKey(accountID: UUID(), remoteID: "stored"), feedID: "feed/1",
                               title: "Stored offer", text: "A notebook from Example Store costs EUR 29.99.", url: url)
    }

    @Test("Native structured generation maps source numbers only to stored article identities")
    func structuredGenerationUsesStoredSources() async throws {
        let source = try article()
        let journal = ModelRequestJournal(response: """
        {"groups":[{"title":"Notebook","summary":"Example Store: EUR 29.99.","sourceNumbers":[0,0]}]}
        """)
        let result = try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                               capacity: 10000, count: { $0.count })
        #expect(result == [DigestSection(title: "Notebook", text: "Example Store: EUR 29.99.", sources: [source.id])])
        let request = try #require(await journal.requests.first)
        #expect(request.enabledToolDefinitions.isEmpty)
        #expect(request.schema != nil)
        #expect(request.generationOptions.maximumResponseTokens == 1200)
        #expect(await journal.requests.count == 1)
    }

    @Test("Native structured generation rejects invalid sources, unsupported numbers and model-written links",
          arguments: [
            #"{"groups":[{"title":"Offer","summary":"Stored offer","sourceNumbers":[]}]}"#,
            #"{"groups":[{"title":"Offer","summary":"Stored offer","sourceNumbers":[-1]}]}"#,
            #"{"groups":[{"title":"Offer","summary":"Stored offer","sourceNumbers":[1]}]}"#,
            #"{"groups":[{"title":"Offer","summary":"EUR 999","sourceNumbers":[0]}]}"#,
            #"{"groups":[{"title":"Offer","summary":"https://invented.test","sourceNumbers":[0]}]}"#,
            #"{"groups":[{"title":"https://invented.test","summary":"Stored offer","sourceNumbers":[0]}]}"#,
            #"{"groups":[{"title":"Offer","summary":"HTTPS://invented.test","sourceNumbers":[0]}]}"#
          ])
    func structuredGenerationRejectsUntrustedOutput(response: String) async throws {
        let journal = ModelRequestJournal(response: response)
        let source = try article()
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 10000, count: { $0.count })
        }
        #expect(await journal.requests.count == 1)
    }
}

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

private actor ControlledGenerator: SummaryGenerator {
    private let gate = RequestGate()
    private(set) var observedCloudPermission: Bool?

    func summarize(_ articles: [ArticleSnapshot], cloudAllowed: Bool) async throws -> [DigestSection] {
        throw ReaderError.invalidResponse
    }

    func summarize(_ articles: [ArticleSnapshot], cloudPermission: @escaping @Sendable () async throws -> Bool) async throws -> [DigestSection] {
        try await gate.pause()
        observedCloudPermission = try await cloudPermission()
        return [DigestSection(title: "Digest", text: "Sourced", sources: articles.map(\.id))]
    }

    func waitUntilStarted(timeout: Duration = .seconds(15)) async throws {
        try await gate.waitUntilEntered(timeout: timeout)
    }

    func release() async { await gate.open() }
}

struct DigestTests {
    @Test("A generator gate fails promptly when generation never starts")
    func generatorGateFailsWhenGenerationNeverStarts() async {
        let model = ControlledGenerator()
        await #expect(throws: RequestGate.Failure.didNotEnter) {
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
