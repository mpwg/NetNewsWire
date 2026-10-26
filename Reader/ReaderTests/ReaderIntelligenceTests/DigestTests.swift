import Foundation
import CryptoKit
import Testing
import ReaderDomain
import ReaderPersistence
import FoundationModels
@testable import ReaderIntelligence

private func nativeModelFailure(_ kind: Int) -> any Error {
    switch kind {
    case 0: LanguageModelError.guardrailViolation(.init(debugDescription: "Controlled guardrail"))
    case 1: LanguageModelError.contextSizeExceeded(.init(contextSize: 100, tokenCount: 200, debugDescription: "Controlled context"))
    case 2: PrivateCloudComputeLanguageModel.Error.quotaLimitReached(.init(limitIncreaseSuggestion: nil, resetDate: nil,
                                                                         debugDescription: "Controlled quota"))
    default: SystemLanguageModel.Error.assetsUnavailable(.init(debugDescription: "Controlled missing assets"))
    }
}

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

private func modelPrompt(_ request: LanguageModelExecutorGenerationRequest) -> String {
    request.transcript.compactMap { entry -> String? in
        guard case .prompt(let prompt) = entry else { return nil }
        return prompt.segments.compactMap { segment -> String? in
            guard case .text(let text) = segment else { return nil }
            return text.content
        }.joined()
    }.joined()
}

private func modelInstructions(_ request: LanguageModelExecutorGenerationRequest) -> String {
    request.transcript.compactMap { entry -> String? in
        guard case .instructions(let instructions) = entry else { return nil }
        return instructions.segments.compactMap { segment -> String? in
            guard case .text(let text) = segment else { return nil }
            return text.content
        }.joined()
    }.joined()
}

private struct CapturedModelSource: Decodable {
    let sourceNumber: Int
    let text: String
    let articleNumbers: [Int]?
    let selectedExcerpts: [String]?
}

private func modelJSON(_ value: [String: Any]) throws -> String {
    String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), as: UTF8.self)
}

private func consolidationJSON(_ prompt: String, text: String = "A sourced summary.") throws -> String {
    let inputs = try JSONDecoder().decode([CapturedModelSource].self, from: Data(prompt.utf8))
    return try modelJSON(["groups": [["title": "Sources", "summary": text, "sourceNumbers": inputs.map(\.sourceNumber)]]])
}

private actor ModelRequestJournal {
    let response: String?
    let factResponses: [String]?
    let sentenceSelection: (@Sendable (String) throws -> String)?
    let selection: (@Sendable (String) throws -> String)?
    let consolidation: (@Sendable (String) throws -> String)?
    let failure: (any Error)?
    let failureRequest: Int
    private var nextFact = 0
    private(set) var requests: [LanguageModelExecutorGenerationRequest] = []

    init(response: String? = nil, factResponses: [String]? = nil,
         sentenceSelection: (@Sendable (String) throws -> String)? = nil,
         selection: (@Sendable (String) throws -> String)? = nil,
         consolidation: (@Sendable (String) throws -> String)? = nil,
         failure: (any Error)? = nil, failureRequest: Int = 0) {
        self.response = response
        self.factResponses = factResponses
        self.sentenceSelection = sentenceSelection
        self.selection = selection
        self.consolidation = consolidation
        self.failure = failure
        self.failureRequest = failureRequest
    }

    func record(_ request: LanguageModelExecutorGenerationRequest) throws -> String {
        let ordinal = requests.count
        requests.append(request)
        if let failure, ordinal == failureRequest { throw failure }
        let prompt = modelPrompt(request)
        if modelInstructions(request).hasPrefix("Select source sentences") {
            guard let sentenceSelection else { throw ReaderError.invalidResponse }
            return try sentenceSelection(prompt)
        }
        if let source = try? JSONDecoder().decode(CapturedModelSource.self, from: Data(prompt.utf8)) {
            if let factResponses {
                guard nextFact < factResponses.count else { throw ReaderError.invalidResponse }
                defer { nextFact += 1 }
                return factResponses[nextFact]
            }
            return try modelJSON(["excerpts": [String(source.text.prefix(128))]])
        }
        if modelInstructions(request).hasPrefix("Select evidence groups") {
            guard let selection else { throw ReaderError.invalidResponse }
            return try selection(prompt)
        }
        if let consolidation { return try consolidation(prompt) }
        if let response { return response }
        return try consolidationJSON(prompt)
    }
}

private struct CapturedSentenceSource: Decodable {
    struct Sentence: Decodable {
        var sentenceNumber: Int
        var text: String
    }
    var sourceNumber: Int
    var sentences: [Sentence]
}

struct SourceSentenceSelectionTests {
    // Explicit multilingual source-text fixtures; code and descriptions stay English.
    @Test("Native sentence choices retain every nonwhitespace character in source order", arguments: [
        "Heading.\nA notebook costs EUR 29.99; pickup only. Shipping is excluded.",
        "Überschrift.\nStraße: 29,99 €. Nur Abholung!",
        "Cafe\u{301} offer 🧪. Price: EUR 2.99.\nOnly Thursday.",
        "商店の価格は 29.99 EUR。木曜日だけです。",
        "🧪 ✓ <tag> [source] ;",
        "First\r\n\tSecond.\u{200B}Third!"
    ])
    func nativeChoicesPreserveCompleteSource(text: String) {
        let choices = SourceSentenceSelection.choices(in: text)
        #expect(!choices.isEmpty)
        #expect(choices.allSatisfy { !$0.isEmpty && text.contains($0) })
        #expect(choices.joined().filter { !$0.isWhitespace } == text.filter { !$0.isWhitespace })
    }

    @Test("Blank fragments provide no selectable sentence", arguments: ["", " \n\t"])
    func blankFragmentsHaveNoChoices(text: String) {
        let choices = SourceSentenceSelection.choices(in: text)
        #expect(choices.isEmpty)
        #expect(throws: ReaderError.self) { try SourceSentenceSelection.excerpts([0], from: choices) }
    }

    @Test("Selected text preserves original punctuation, order and deduplicated identity")
    func selectedSourceTextIsCopiedWithoutRewriting() throws {
        let choices = ["Example Store: EUR 29.99; pickup only.", "Other Store: EUR 44.90 — online only."]
        #expect(try SourceSentenceSelection.excerpts([1, 0, 1], from: choices) == [choices[1], choices[0]])
    }

    @Test("Selected claims retain restrictions and negations anywhere in their bounded source fragment",
          arguments: [0, 1, 2])
    func selectedClaimsKeepWholeFragmentContext(index: Int) throws {
        let fragment = "Example Store offers a notebook for EUR 29.99.\n\nPickup only.\nOnline orders and shipping are excluded."
        let choices = SourceSentenceSelection.choices(in: fragment)
        #expect(choices.count == 3)
        let result = try SourceSentenceSelection.contextualExcerpt([index], in: fragment)
        #expect(result == fragment)
        #expect(try SourceFactValidation.excerpts([result], in: fragment) == [fragment])
    }

    @Test("Context expansion rejects invalid selections before returning any source text",
          arguments: [[], [-1], [3], Array(repeating: 0, count: 9)])
    func contextExpansionRequiresValidSelection(indices: [Int]) {
        #expect(throws: ReaderError.invalidResponse) {
            try SourceSentenceSelection.contextualExcerpt(indices, in: "A price. A restriction. A negation.")
        }
    }

    @Test("Empty, negative, excessive and out-of-range sentence selections are rejected",
          arguments: [[], [-1], [2], Array(repeating: 0, count: 9)])
    func invalidSentenceSelectionsAreRejected(indices: [Int]) {
        #expect(throws: ReaderError.self) {
            try SourceSentenceSelection.excerpts(indices, from: ["First original.", "Second original."])
        }
    }
}

struct SourceNumberReferenceTests {
    // Explicit multilingual and Unicode source fixtures.
    @Test("Native numeric references round-trip exact literals and surrounding Unicode", arguments: [
        "Budget EUR 250000. Repeated: 250000.",
        "Preis EUR 29,99; zusätzlich 2.500,50.",
        "Hours 21:00–17:00; dates 2026-10-26.",
        "Café 🧪 costs 29.99; cafe\u{301} costs 29.99.",
        "No numeric values are present."
    ])
    func numericReferencesKeepExactSourceText(text: String) throws {
        let table = try SourceNumberReferences(packetNumber: 7, text: text)
        let masked = try table.masked(text)
        #expect(try SourceNumberReferences.restored(masked, tables: [table], citedPackets: [7]) == text)
    }

    @Test("Source namespace collisions and numbers outside the packet are rejected", arguments: [
        "⟦readerNumber:0:0⟧", "⟦readerNumber", "EUR 9999", "29,99"
    ])
    func sourceReferencesCannotBeForged(text: String) {
        #expect(throws: ReaderError.invalidResponse) {
            let table = try SourceNumberReferences(packetNumber: 0, text: "EUR 29.99")
            _ = try table.masked(text)
        }
    }

    @Test("Unknown, malformed and uncited packet references never restore", arguments: [
        "⟦readerNumber:0:99⟧", "⟦readerNumber:0:0", "⟦readerNumber:00:0⟧", "⟦readerNumber:1:0⟧"
    ])
    func invalidNumericReferencesFailClosed(text: String) throws {
        let first = try SourceNumberReferences(packetNumber: 0, text: "EUR 29.99")
        let other = try SourceNumberReferences(packetNumber: 1, text: "EUR 29.99")
        #expect(throws: ReaderError.invalidResponse) {
            try SourceNumberReferences.restored(text, tables: [first, other], citedPackets: [0])
        }
    }
}

struct SourceFactValidationTests {
    // Multilingual source-text fixtures; test code and descriptions remain English.
    @Test("Source excerpts preserve Unicode, merchant names and numeric punctuation",
          arguments: [
            ("A notebook from Example Store costs EUR 29.99.", "Example Store costs EUR 29.99."),
            ("Bei Beispielmarkt kostet es EUR 29,99.", "Beispielmarkt kostet es EUR 29,99."),
            ("Café offer 🧪 costs EUR 2.99.", "Café offer 🧪"),
            ("Cafe\u{301} offer costs EUR 2.99.", "Cafe\u{301} offer"),
            ("商店の価格は 29.99 EUR。", "29.99 EUR")
          ])
    func excerptsRemainVerbatim(fragment: String, excerpt: String) throws {
        let result = try SourceFactValidation.excerpts([excerpt, " \n" + excerpt + "\t"], in: fragment)
        #expect(result == [excerpt])
    }

    @Test("Empty, fabricated, reformatted and excessive source excerpts are rejected",
          arguments: [
            [], [""], [" \n\t"], ["Example Shop costs EUR 29.99."],
            ["Example Store costs EUR 29,99."], ["EUR 999"],
            ["A notebook", "An invented fact"], Array(repeating: "A notebook", count: 9)
          ])
    func invalidExcerptsAreRejected(excerpts: [String]) {
        #expect(throws: ReaderError.self) {
            try SourceFactValidation.excerpts(excerpts, in: "A notebook from Example Store costs EUR 29.99.")
        }
    }

    @Test("The bounded fact set retains its original order")
    func maximumFactSetKeepsItsOrder() throws {
        let excerpts = (0..<8).map { "Fact \($0)." }
        #expect(try SourceFactValidation.excerpts(excerpts, in: excerpts.joined(separator: " ")) == excerpts)
    }
}

private actor GenerationTraceJournal {
    var entries: [SummaryGenerationTrace] = []
    func append(_ entry: SummaryGenerationTrace) { entries.append(entry) }
}

struct AppleSummaryGeneratorTests {
    @Test("Native drafting receives opaque numbers and restores exact cited source literals")
    func numericDraftsRestoreOnlyReaderOwnedValues() async throws {
        var source = try article()
        source.title = "Project."
        source.text = "The budget is EUR 250000."
        let journal = ModelRequestJournal(
            sentenceSelection: { _ in #"{"sentenceNumbers":[1]}"# },
            selection: { _ in #"{"groups":[{"sourceNumbers":[0]}]}"# },
            consolidation: { prompt in
                let packets = try JSONDecoder().decode([CapturedModelSource].self, from: Data(prompt.utf8))
                #expect(packets.first?.text == "Project.\nThe budget is EUR ⟦readerNumber:0:0⟧.")
                #expect(packets.first?.selectedExcerpts == ["The budget is EUR ⟦readerNumber:0:0⟧."])
                #expect(packets.first?.articleNumbers == [0])
                #expect(!prompt.contains("250000"))
                return #"{"title":"Budget","summary":"The budget is EUR ⟦readerNumber:0:0⟧.","sourceNumbers":[0]}"#
            })
        let sections = try await AppleSummaryGenerator().generate(
            [source], model: ControlledLanguageModel(journal: journal), capacity: 10000,
            isolateSelectedEvidence: true, selectSourceSentences: true, protectNumericLiterals: true, count: { $0.count })
        #expect(sections.first?.text == "The budget is EUR 250000.")
        #expect(sections.first?.sources == [source.id])
        #expect(await journal.requests.count == 3)
    }

    @Test("Numeric drafts reject unknown or uncited references, changed literals and inline citations", arguments: [
        "EUR ⟦readerNumber:0:99⟧.", "EUR ⟦readerNumber:1:0⟧.", "EUR ⟦readerNumber:0:0.",
        "EUR 250.000.", "EUR ⟦readerNumber:0:0⟧ (0)."
    ])
    func numericDraftsKeepIndependentSourceValidation(text: String) async throws {
        var sources = try distinctSources(count: 2)
        for index in sources.indices {
            sources[index].title = "Project."
            sources[index].text = index == 0 ? "The budget is EUR 250000." : "The budget is EUR 100."
        }
        let journal = ModelRequestJournal(
            sentenceSelection: { _ in #"{"sentenceNumbers":[1]}"# },
            selection: { _ in #"{"groups":[{"sourceNumbers":[0,1]}]}"# },
            consolidation: { _ in try modelJSON(["title": "Budget", "summary": text, "sourceNumbers": [0]]) })
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate(
                sources, model: ControlledLanguageModel(journal: journal), capacity: 10000,
                isolateSelectedEvidence: true, selectSourceSentences: true, protectNumericLiterals: true, count: { $0.count })
        }
        #expect(await journal.requests.count == 4)
    }

    @Test("Numeric expansion counts the actual draft JSON before issuing a request")
    func numericDraftBudgetUsesExpandedReferenceText() async throws {
        let journal = ModelRequestJournal(
            sentenceSelection: { _ in #"{"sentenceNumbers":[0]}"# },
            selection: { _ in #"{"groups":[{"sourceNumbers":[0]}]}"# })
        var source = try article()
        source.title = "Budget EUR 250000."
        source.text = ""
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate(
                [source], model: ControlledLanguageModel(journal: journal), capacity: 10000,
                isolateSelectedEvidence: true, selectSourceSentences: true, protectNumericLiterals: true,
                count: { $0.contains("⟦readerNumber") ? 10000 : $0.count })
        }
        #expect(await journal.requests.count == 2)
    }

    @Test("Numeric references require independent selected-evidence drafting")
    func numericReferencesRequireAnIsolatedDraft() async throws {
        let journal = ModelRequestJournal()
        await #expect(throws: ReaderError.invalidResponse) {
            try await AppleSummaryGenerator().generate(
                [article()], model: ControlledLanguageModel(journal: journal), capacity: 10000,
                protectNumericLiterals: true, count: { $0.count })
        }
        #expect(await journal.requests.isEmpty)
    }

    @Test("Overlapping evidence groups coalesce transitively while independent groups stay separate", arguments: [
        ([[0], [0]], [[0]]),
        ([[0, 1], [2, 3], [1, 2]], [[0, 1, 2, 3]]),
        ([[0], [1, 2], [2, 3], [4]], [[0], [1, 2, 3], [4]]),
        ([[3, 1, 1], [0], [4, 2]], [[1, 3], [0], [2, 4]]),
        ([], [])
    ])
    func evidenceGroupsCoalesceOnlySharedPackets(input: [[Int]], expected: [[Int]]) {
        #expect(AppleSummaryGenerator.coalescedSelections(input) == expected)
    }

    @Test("Overlapping native plans issue only one draft with all connected original identities", arguments: [false, true])
    func overlappingPlansShareOneActualDraft(indexed: Bool) async throws {
        let sources = try distinctSources(count: 2)
        let journal = ModelRequestJournal(
            response: #"{"title":"Selected","summary":"A sourced summary.","sourceNumbers":[0,1]}"#,
            sentenceSelection: { _ in #"{"sentenceNumbers":[0]}"# },
            selection: { _ in #"{"groups":[{"sourceNumbers":[0]},{"sourceNumbers":[1]},{"sourceNumbers":[0,1]}]}"# })
        let sections = try await AppleSummaryGenerator().generate(
            sources, model: ControlledLanguageModel(journal: journal), capacity: 10000,
            isolateSelectedEvidence: true, selectSourceSentences: indexed, count: { $0.count })
        #expect(sections.count == 1)
        #expect(sections.first?.sources == sources.map(\.id))
        let requests = await journal.requests
        #expect(requests.count == 4)
        let draft = try #require(requests.last)
        let packets = try JSONDecoder().decode([CapturedModelSource].self, from: Data(modelPrompt(draft).utf8))
        #expect(packets.map(\.sourceNumber) == [0, 1])
        #expect(packets.map(\.articleNumbers) == [[0], [1]])
    }

    @Test("Indexed facts retain the selected claim and its complete bounded source context", arguments: [false, true])
    func indexedFactsKeepActualSourceText(isolated: Bool) async throws {
        var source = try article()
        source.title = "First statement."
        source.text = "A merchant sells an item for EUR 29.99. Pickup only."
        let journal = ModelRequestJournal(
            sentenceSelection: { _ in #"{"sentenceNumbers":[1]}"# },
            selection: { _ in #"{"groups":[{"sourceNumbers":[0]}]}"# },
            consolidation: { prompt in
                let packets = try JSONDecoder().decode([CapturedModelSource].self, from: Data(prompt.utf8))
                #expect(packets.count == 1)
                #expect(packets.first?.text == "First statement.\nA merchant sells an item for EUR 29.99. Pickup only.")
                #expect(packets.first?.selectedExcerpts == ["A merchant sells an item for EUR 29.99."])
                let group = #"{"title":"Selected","summary":"EUR 29.99.","sourceNumbers":[0]}"#
                return isolated ? group : #"{"groups":["# + group + "]}"
            })
        let sections = try await AppleSummaryGenerator().generate(
            [source], model: ControlledLanguageModel(journal: journal), capacity: 10000,
            isolateSelectedEvidence: isolated, selectSourceSentences: true, count: { $0.count })
        #expect(sections.first?.sources == [source.id])
        let requests = await journal.requests
        #expect(requests.count == (isolated ? 3 : 2))
        let first = try #require(requests.first)
        let supplied = try JSONDecoder().decode(CapturedSentenceSource.self, from: Data(modelPrompt(first).utf8))
        #expect(supplied.sourceNumber == 0)
        #expect(supplied.sentences.contains { $0.sentenceNumber == 1 && $0.text == "A merchant sells an item for EUR 29.99." })
        for request in requests { #expect(modelInstructions(request).count + modelPrompt(request).count <= 8000) }
    }

    @Test("Identical context preserves independent selected assertions and merges only matching focus",
          arguments: [(false, false), (false, true), (true, false), (true, true)])
    func selectedFocusKeepsItsOriginalIdentity(isolated: Bool, differentFocus: Bool) async throws {
        var sources = try distinctSources(count: 2)
        for index in sources.indices {
            sources[index].title = "Shared report."
            sources[index].text = "The notebook costs EUR 29.99. Pickup only."
        }
        let journal = ModelRequestJournal(sentenceSelection: { prompt in
            let input = try JSONDecoder().decode(CapturedSentenceSource.self, from: Data(prompt.utf8))
            return try modelJSON(["sentenceNumbers": [differentFocus ? input.sourceNumber + 1 : 1]])
        }, selection: { _ in
            try modelJSON(["groups": [["sourceNumbers": differentFocus ? [0, 1] : [0]]]])
        }, consolidation: { prompt in
            let packets = try JSONDecoder().decode([CapturedModelSource].self, from: Data(prompt.utf8))
            #expect(packets.count == (differentFocus ? 2 : 1))
            #expect(packets.allSatisfy { $0.text == "Shared report.\nThe notebook costs EUR 29.99. Pickup only." })
            #expect(packets.first?.selectedExcerpts == ["The notebook costs EUR 29.99."])
            #expect(packets.first?.articleNumbers == (differentFocus ? [0] : [0, 1]))
            if differentFocus {
                #expect(packets.last?.selectedExcerpts == ["Pickup only."])
                #expect(packets.last?.articleNumbers == [1])
            }
            let group: [String: Any] = ["title": "Selected", "summary": "A sourced summary.",
                                        "sourceNumbers": packets.map(\.sourceNumber)]
            return try modelJSON(isolated ? group : ["groups": [group]])
        })
        let sections = try await AppleSummaryGenerator().generate(
            sources, model: ControlledLanguageModel(journal: journal), capacity: 10000,
            isolateSelectedEvidence: isolated, selectSourceSentences: true, count: { $0.count })
        #expect(sections.first?.sources == sources.map(\.id))
    }

    @Test("Selected excerpts and complete context must fit together without truncation")
    func selectedContextBudgetRejectsBeforeConsolidation() async throws {
        let journal = ModelRequestJournal(sentenceSelection: { _ in #"{"sentenceNumbers":[0]}"# })
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate(
                [article()], model: ControlledLanguageModel(journal: journal), capacity: 10000,
                selectSourceSentences: true, count: { text in
                    text.contains(#""selectedExcerpts""#) ? 10000 : text.count
                })
        }
        #expect(await journal.requests.count == 1)
    }

    @Test("Invalid native sentence indices stop before evidence consolidation",
          arguments: [[], [-1], [99], Array(repeating: 0, count: 9)])
    func indexedFactsRejectInvalidNativeSelections(indices: [Int]) async throws {
        let journal = ModelRequestJournal(sentenceSelection: { _ in try modelJSON(["sentenceNumbers": indices]) })
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate(
                [article()], model: ControlledLanguageModel(journal: journal), capacity: 10000,
                selectSourceSentences: true, count: { $0.count })
        }
        #expect(await journal.requests.count == 1)
    }

    @Test("Indexed input budgeting includes the actual sentence JSON before a request")
    func indexedSourceJSONMustFitItsBudget() async throws {
        let journal = ModelRequestJournal(sentenceSelection: { _ in #"{"sentenceNumbers":[0]}"# })
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate(
                [article()], model: ControlledLanguageModel(journal: journal), capacity: 10000,
                selectSourceSentences: true, count: { text in
                    text.contains(#""sentences""#) ? 10000 : text.count
                })
        }
        #expect(await journal.requests.isEmpty)
    }

    @Test("Cancellation after native sentence selection prevents consolidation")
    func indexedFactsCheckCancellation() async throws {
        let source = try article()
        let journal = ModelRequestJournal(sentenceSelection: { _ in #"{"sentenceNumbers":[0]}"# })
        let task = Task {
            try await AppleSummaryGenerator().generate(
                [source], model: ControlledLanguageModel(journal: journal), capacity: 10000,
                trace: { entry in
                    if entry.stage == "sentence-selection" { withUnsafeCurrentTask { $0?.cancel() } }
                }, selectSourceSentences: true, count: { $0.count })
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await journal.requests.count == 1)
    }

    @Test("An isolated draft receives only selected evidence and keeps its actual original identity")
    func isolatedDraftExcludesUnselectedPackets() async throws {
        let sources = try distinctSources(count: 2)
        let journal = ModelRequestJournal(response: #"{"title":"Selected","summary":"A sourced summary.","sourceNumbers":[1]}"#,
            selection: { _ in #"{"groups":[{"sourceNumbers":[1]}]}"# })
        let sections = try await AppleSummaryGenerator().generate(
            sources, model: ControlledLanguageModel(journal: journal), capacity: 10000,
            isolateSelectedEvidence: true, count: { $0.count })
        #expect(sections.count == 1)
        #expect(sections.first?.sources == [sources[1].id])
        let requests = await journal.requests
        #expect(requests.count == 4)
        let plan = try #require(requests.dropFirst(2).first)
        let supplied = try JSONDecoder().decode([CapturedModelSource].self, from: Data(modelPrompt(plan).utf8))
        try #require(supplied.count == 2)
        let draft = try #require(requests.last)
        let selected = try JSONDecoder().decode([CapturedModelSource].self, from: Data(modelPrompt(draft).utf8))
        #expect(selected.count == 1)
        #expect(selected.first?.sourceNumber == 1)
        #expect(selected.first?.articleNumbers == [1])
        #expect(selected.first?.text == supplied[1].text)
        #expect(selected.first?.text != supplied[0].text)
        for request in requests {
            #expect(modelInstructions(request).count + modelPrompt(request).count <= 8000)
        }
    }

    @Test("Invalid evidence plans cannot start an isolated drafting request", arguments: [0, 1, 2])
    func invalidIsolationPlansStopBeforeDrafting(kind: Int) async throws {
        let plan = switch kind {
        case 0: #"{"groups":[]}"#
        case 1: #"{"groups":[{"sourceNumbers":[]}]}"#
        default: #"{"groups":[{"sourceNumbers":[99]}]}"#
        }
        let journal = ModelRequestJournal(selection: { _ in plan })
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate(
                distinctSources(count: 2), model: ControlledLanguageModel(journal: journal), capacity: 10000,
                isolateSelectedEvidence: true, count: { $0.count })
        }
        #expect(await journal.requests.count == 3)
    }

    @Test("Isolated drafts cannot borrow unselected prices or packet indices", arguments: [false, true])
    func isolatedDraftsKeepIndependentValidation(invalidIndex: Bool) async throws {
        var sources = try distinctSources(count: 2)
        sources[0].text = "Selected material costs EUR 10."
        sources[1].text = "Excluded material costs EUR 9999."
        let output = invalidIndex
            ? #"{"title":"Selected","summary":"Selected material.","sourceNumbers":[1]}"#
            : #"{"title":"Selected","summary":"EUR 9999.","sourceNumbers":[0]}"#
        let journal = ModelRequestJournal(response: output, selection: { _ in #"{"groups":[{"sourceNumbers":[0]}]}"# })
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate(
                sources, model: ControlledLanguageModel(journal: journal), capacity: 10000,
                isolateSelectedEvidence: true, count: { $0.count })
        }
        #expect(await journal.requests.count == 4)
    }

    @Test("Revoking live permission after selection prevents isolated drafting")
    func isolatedDraftChecksLivePermission() async throws {
        let journal = ModelRequestJournal(selection: { _ in #"{"groups":[{"sourceNumbers":[0]}]}"# })
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate(
                distinctSources(count: 2), model: ControlledLanguageModel(journal: journal), capacity: 10000,
                cloudPermission: { await journal.requests.count < 3 },
                isolateSelectedEvidence: true, count: { $0.count })
        }
        #expect(await journal.requests.count == 3)
    }

    @Test("Cancellation after selection prevents isolated drafting")
    func isolatedDraftChecksCancellation() async throws {
        let sources = try distinctSources(count: 2)
        let journal = ModelRequestJournal(selection: { _ in #"{"groups":[{"sourceNumbers":[0]}]}"# })
        let task = Task {
            try await AppleSummaryGenerator().generate(
                sources, model: ControlledLanguageModel(journal: journal), capacity: 10000,
                trace: { entry in
                    if entry.stage == "selection" { withUnsafeCurrentTask { $0?.cancel() } }
                }, isolateSelectedEvidence: true, count: { $0.count })
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await journal.requests.count == 3)
    }

    @Test("Selection and isolated drafting each count their actual instruction budget", arguments: [false, true])
    func isolatedRequestsEnforceActualBudgets(draft: Bool) async throws {
        let journal = ModelRequestJournal(selection: { _ in #"{"groups":[{"sourceNumbers":[0]}]}"# })
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate(
                distinctSources(count: 2), model: ControlledLanguageModel(journal: journal), capacity: 10000,
                isolateSelectedEvidence: true, count: { text in
                    if draft ? text.contains("Write one group using only") : text.hasPrefix("Select evidence groups") {
                        return 10000
                    }
                    return text.count
                })
        }
        #expect(await journal.requests.count == (draft ? 3 : 2))
    }

    @Test("Each source fragment keeps its merchant, price and conditions in one evidence packet")
    func fragmentFactsKeepTheirSharedReference() async throws {
        let first = try article()
        var second = first
        second.id.remoteID = "second-offer"
        second.text = "Other Store offers a kettle for EUR 44.90. Online only."
        let firstText = first.text
        let journal = ModelRequestJournal(factResponses: [
            try modelJSON(["excerpts": [first.title, firstText]]),
            try modelJSON(["excerpts": ["Other Store offers a kettle for EUR 44.90.", "Online only."]])
        ], consolidation: { prompt in
            let inputs = try JSONDecoder().decode([CapturedModelSource].self, from: Data(prompt.utf8))
            #expect(inputs.count == 2)
            #expect(inputs[0].text == first.title + "\n" + firstText)
            #expect(inputs[1].text == "Other Store offers a kettle for EUR 44.90.\nOnline only.")
            return #"{"groups":[{"title":"Offers","summary":"Other Store: EUR 44.90, online only.","sourceNumbers":[0,1]}]}"#
        })
        let result = try await AppleSummaryGenerator().generate([first, second], model: ControlledLanguageModel(journal: journal),
                                                               capacity: 10000, count: { $0.count })
        #expect(result.first?.sources == [first.id, second.id])
    }

    @Test("Opt-in evaluation captures rejected drafts without bypassing validation", arguments: [false, true])
    func traceRetainsRejectedDraft(factFailure: Bool) async throws {
        let invalid = factFailure ? #"{"excerpts":["A fabricated quote."]}"#
            : #"{"groups":[{"title":"Offer","summary":"EUR 9999.","sourceNumbers":[0]}]}"#
        let journal = ModelRequestJournal(response: factFailure ? nil : invalid,
                                          factResponses: factFailure ? [invalid] : nil)
        let trace = GenerationTraceJournal()
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate([try article()], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 10000, trace: { await trace.append($0) }, count: { $0.count })
        }
        let entries = await trace.entries
        #expect(entries.map(\.stage) == (factFailure ? ["facts"] : ["facts", "consolidation"]))
        let last = try #require(entries.last)
        let captured = try JSONSerialization.jsonObject(with: Data(last.response.utf8)) as? NSDictionary
        let expected = try JSONSerialization.jsonObject(with: Data(invalid.utf8)) as? NSDictionary
        #expect(captured == expected)
        let requests = await journal.requests
        #expect(entries.map(\.prompt) == requests.map(modelPrompt))
        #expect(entries.compactMap(\.instructions) == requests.map(modelInstructions))
    }

    @Test("Cancellation in an evaluation sink prevents validation and later requests")
    func traceCancellationStopsGeneration() async throws {
        let journal = ModelRequestJournal()
        let task = Task {
            try await AppleSummaryGenerator().generate([try article()], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 10000, trace: { _ in
                withUnsafeCurrentTask { $0?.cancel() }
            }, count: { $0.count })
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!Task.isCancelled)
        #expect(await journal.requests.count == 1)
    }

    @Test("Matching source facts merge without losing stored source identities", arguments: [false, true])
    func equalFactsKeepEverySourceIdentity(foreignAccount: Bool) async throws {
        let journal = ModelRequestJournal(response: """
        {"groups":[{"title":"Notebook","summary":"Example Store: EUR 29.99.","sourceNumbers":[0]}]}
        """)
        let first = try article()
        var second = first
        second.id = ArticleKey(accountID: foreignAccount ? UUID() : first.id.accountID,
                               remoteID: foreignAccount ? first.id.remoteID : "other-stored")
        let result = try await AppleSummaryGenerator().generate([first, second], model: ControlledLanguageModel(journal: journal),
                                                               capacity: 10000, count: { $0.count })
        #expect(result == [DigestSection(title: "Notebook", text: "Example Store: EUR 29.99.", sources: [first.id, second.id])])
        let requests = await journal.requests
        #expect(requests.count == 3)
        let consolidation = try JSONDecoder().decode([CapturedModelSource].self, from: Data(modelPrompt(try #require(requests.last)).utf8))
        #expect(consolidation.count == 1)
        #expect(consolidation.first?.articleNumbers == [0, 1])
    }

    @Test("Exact repeated summary sentences and sections do not duplicate the same claim", arguments: ["en_AT", "de_AT"])
    func exactRepeatedClaimsAreDeduplicated(localeID: String) async throws {
        let journal = ModelRequestJournal(response: """
        {"groups":[
          {"title":"Notebook","summary":"Example Store: EUR 29.99. Example Store: EUR 29.99.","sourceNumbers":[0]},
          {"title":"Notebook","summary":"Example Store: EUR 29.99. Example Store: EUR 29.99.","sourceNumbers":[0]}
        ]}
        """)
        let source = try article()
        let result = try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                               capacity: 10000, locale: Locale(identifier: localeID), count: { $0.count })
        #expect(result == [DigestSection(title: "Notebook", text: "Example Store: EUR 29.99.", sources: [source.id])])
    }

    @Test("Only consolidation translates; source extraction remains verbatim", arguments: [("en_AT", "English"), ("de_AT", "German")])
    func instructionsNameRequestedLanguage(localeID: String, language: String) async throws {
        let journal = ModelRequestJournal()
        _ = try await AppleSummaryGenerator().generate([try article()], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 10000, locale: Locale(identifier: localeID), count: { $0.count })
        let requests = await journal.requests
        #expect(requests.count == 2)
        let extraction = modelInstructions(try #require(requests.first))
        let consolidation = modelInstructions(try #require(requests.last))
        #expect(extraction.contains("verbatim"))
        #expect(extraction.contains("Do not rewrite or translate"))
        #expect(consolidation.contains("in " + language + "."))
        // Repetition and source coverage are verified through generated results, not prompt wording.
    }

    @Test("Every raw source character reaches extraction and every stage respects its runtime budget", arguments: [3500, 4500])
    func longSourceChunksPreserveContent(capacity: Int) async throws {
        let journal = ModelRequestJournal()
        var source = try article()
        source.text = String(repeating: "Unicode source 🧪 café. ", count: 300)
        _ = try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                      capacity: capacity, count: { $0.count })
        let requests = await journal.requests
        var reconstructed = ""
        var consolidations = 0
        for request in requests {
            let prompt = modelPrompt(request)
            if let input = try? JSONDecoder().decode(CapturedModelSource.self, from: Data(prompt.utf8)) {
                #expect(input.sourceNumber == 0)
                reconstructed += input.text
            } else {
                consolidations += 1
            }
            #expect(!prompt.isEmpty)
            #expect(prompt.count <= capacity - modelInstructions(request).count - 2000)
            #expect(request.enabledToolDefinitions.isEmpty)
            #expect(request.schema != nil)
            #expect(request.generationOptions.maximumResponseTokens == 1200)
        }
        #expect(consolidations >= 1)
        #expect(reconstructed == source.title + "\n" + source.text)
    }

    @Test("Unconfigured PCC rejects before consent or a model request")
    func unconfiguredCloudIsNeverRequested() async {
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().cloudSummary([], permission: { throw CancellationError() })
        }
    }

    @Test("Revoked cloud consent is rejected before instantiating PCC")
    func cloudRequiresLiveConsentBeforeInstantiation() async {
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator(privateCloudComputeEnabled: true).cloudSummary([], permission: { false })
        }
    }

    @Test("Native framework errors propagate unchanged from both shipping stages",
          arguments: [0, 1, 2, 3], [0, 1])
    func frameworkErrorsPropagate(kind: Int, stage: Int) async throws {
        let failure = nativeModelFailure(kind)
        let journal = ModelRequestJournal(failure: failure, failureRequest: stage)
        let received = await #expect(throws: (any Error).self) {
            try await AppleSummaryGenerator().generate([try article()], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 10000, count: { $0.count })
        }
        let error = try #require(received)
        #expect(String(reflecting: type(of: error)) == String(reflecting: type(of: failure)))
        #expect(error.localizedDescription == failure.localizedDescription)
        #expect(await journal.requests.count == stage + 1)
    }

    @Test("Insufficient context budget fails before any model request")
    func insufficientBudgetMakesNoRequest() async throws {
        let journal = ModelRequestJournal()
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate([try article()], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 2200, count: { $0.count })
        }
        #expect(await journal.requests.isEmpty)
    }

    @Test("Cloud permission is rechecked before every fragment")
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

    @Test("Cloud consent revoked after fact extraction prevents consolidation")
    func revokedPermissionStopsConsolidation() async throws {
        let journal = ModelRequestJournal()
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate([try article()], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 10000, cloudPermission: { await journal.requests.isEmpty },
                                                      count: { $0.count })
        }
        #expect(await journal.requests.count == 1)
    }

    @Test("Native cancellation remains cancellation in either stage", arguments: [0, 1])
    func modelCancellationPropagates(stage: Int) async throws {
        let journal = ModelRequestJournal(failure: CancellationError(), failureRequest: stage)
        await #expect(throws: CancellationError.self) {
            try await AppleSummaryGenerator().generate([try article()], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 10000, count: { $0.count })
        }
        #expect(await journal.requests.count == stage + 1)
    }

    @Test("Cancelling a held token count prevents all model requests", .timeLimit(.minutes(1)))
    func cancellationDuringBudgetingPreventsRequests() async throws {
        let gate = RequestGate()
        let journal = ModelRequestJournal()
        let source = try article()
        let task = Task {
            try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 10000, count: { text in
                try await gate.pause()
                return text.count
            })
        }
        defer { task.cancel(); Task { await gate.open() } }
        try await gate.waitUntilEntered()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await journal.requests.isEmpty)
    }

    @Test("Structured consolidation maps references only through validated source facts")
    func structuredGenerationUsesStoredSources() async throws {
        let source = try article()
        let journal = ModelRequestJournal(response: """
        {"groups":[{"title":"Notebook","summary":"Example Store: EUR 29.99.","sourceNumbers":[0,0]}]}
        """)
        let result = try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                               capacity: 10000, count: { $0.count })
        #expect(result == [DigestSection(title: "Notebook", text: "Example Store: EUR 29.99.", sources: [source.id])])
        let requests = await journal.requests
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.enabledToolDefinitions.isEmpty && $0.schema != nil })
        #expect(requests.allSatisfy { $0.generationOptions.maximumResponseTokens == 1200 })
    }

    @Test("Consolidation rejects invalid references, unsupported numbers, links and blank output",
          arguments: [
            #"{"groups":[]}"#,
            #"{"groups":[{"title":"Offer","summary":"Stored offer","sourceNumbers":[]}]}"#,
            #"{"groups":[{"title":"Offer","summary":"Stored offer","sourceNumbers":[-1]}]}"#,
            #"{"groups":[{"title":"Offer","summary":"Stored offer","sourceNumbers":[1]}]}"#,
            #"{"groups":[{"title":"Offer","summary":"EUR 999","sourceNumbers":[0]}]}"#,
            #"{"groups":[{"title":"Offer","summary":"https://invented.test","sourceNumbers":[0]}]}"#,
            #"{"groups":[{"title":"https://invented.test","summary":"Stored offer","sourceNumbers":[0]}]}"#,
            #"{"groups":[{"title":"Offer","summary":"HTTPS://invented.test","sourceNumbers":[0]}]}"#,
            #"{"groups":[{"title":"","summary":"Stored offer","sourceNumbers":[0]}]}"#,
            #"{"groups":[{"title":" \t","summary":"Stored offer","sourceNumbers":[0]}]}"#,
            #"{"groups":[{"title":"Offer","summary":"","sourceNumbers":[0]}]}"#,
            #"{"groups":[{"title":"Offer","summary":" \n\t","sourceNumbers":[0]}]}"#
          ])
    func structuredGenerationRejectsUntrustedOutput(response: String) async throws {
        let journal = ModelRequestJournal(response: response)
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate([try article()], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 10000, count: { $0.count })
        }
        #expect(await journal.requests.count == 2)
    }

    @Test("Facts cannot borrow text from another source or a later fragment", arguments: [false, true])
    func factsRemainBoundToTheirOwnFragment(laterFragment: Bool) async throws {
        var source = try article()
        if laterFragment { source.text = String(repeating: "Leading source material. ", count: 200) + "Other Store costs EUR 10.00." }
        let journal = ModelRequestJournal(factResponses: [try modelJSON(["excerpts": ["Other Store costs EUR 10.00."]])])
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                      capacity: laterFragment ? 4000 : 10000, count: { $0.count })
        }
        #expect(await journal.requests.count == 1)
    }

    @Test("Selected statements reference only their supporting originals", arguments: [false, true])
    func selectedStatementsKeepExactProvenance(foreignAccount: Bool) async throws {
        var sources = try distinctSources(count: 2)
        if foreignAccount {
            sources[1].id = ArticleKey(accountID: UUID(), remoteID: sources[0].id.remoteID)
        }
        let journal = ModelRequestJournal(response: #"{"groups":[{"title":"Notes","summary":"A sourced summary.","sourceNumbers":[0]}]}"#)
        let sections = try await AppleSummaryGenerator().generate(
            sources, model: ControlledLanguageModel(journal: journal), capacity: 10000, count: { $0.count })
        #expect(sections.count == 1)
        #expect(sections.first?.text == "A sourced summary.")
        #expect(sections.first?.sources == [sources[0].id])
        #expect(await journal.requests.count == 3)
    }

    @Test("Key-statement selection may omit a fragment but cannot borrow its price", arguments: [false, true])
    func selectedFragmentsKeepArticleCoverageAndNumericBounds(unsupportedPrice: Bool) async throws {
        var source = try article()
        source.text = String(repeating: "Relevant background context. ", count: 300)
            + String(repeating: "Other conditions cost EUR 9999. ", count: 150)
        let journal = ModelRequestJournal(consolidation: { prompt in
            let inputs = try JSONDecoder().decode([CapturedModelSource].self, from: Data(prompt.utf8))
            #expect(inputs.count > 1)
            #expect(inputs.allSatisfy { $0.articleNumbers == [0] })
            #expect(inputs.first?.text.contains("9999") == false)
            #expect(inputs.dropFirst().contains { $0.text.contains("9999") })
            return try modelJSON(["groups": [[
                "title": "Context", "summary": unsupportedPrice ? "EUR 9999." : "Relevant background context.",
                "sourceNumbers": [0]
            ]]])
        })
        let generator = AppleSummaryGenerator()
        if unsupportedPrice {
            await #expect(throws: ReaderError.self) {
                try await generator.generate([source], model: ControlledLanguageModel(journal: journal),
                                             capacity: 8000, count: { $0.count })
            }
        } else {
            let result = try await generator.generate([source], model: ControlledLanguageModel(journal: journal),
                                                      capacity: 8000, count: { $0.count })
            #expect(result == [DigestSection(title: "Context", text: "Relevant background context.", sources: [source.id])])
        }
        #expect(await journal.requests.filter { modelPrompt($0).first == "{" }.count > 1)
    }

    @Test("Packet indices and other packets cannot justify generated prices", arguments: ["0", "10.00"])
    func generatedNumbersRequireTheirReferencedFacts(number: String) async throws {
        var sources = try distinctSources(count: 2)
        sources[0].title = "First offer"
        sources[1].title = "Second offer"
        sources[1].text = "An adapter from Other Store costs EUR 10.00."
        let response = try modelJSON(["groups": [
            ["title": "Offer", "summary": "EUR " + number, "sourceNumbers": [0]],
            ["title": "Other", "summary": "Another sourced offer.", "sourceNumbers": [1]]
        ]])
        let journal = ModelRequestJournal(response: response)
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate(sources, model: ControlledLanguageModel(journal: journal),
                                                      capacity: 10000, count: { $0.count })
        }
    }

    @Test("Many distinct sources use bounded hierarchical consolidation without losing identities", .timeLimit(.minutes(1)))
    func hierarchicalConsolidationKeepsEverySource() async throws {
        let sources = try distinctSources(count: 40)
        let journal = ModelRequestJournal()
        let result = try await AppleSummaryGenerator().generate(sources, model: ControlledLanguageModel(journal: journal),
                                                               capacity: 100000, count: { $0.count })
        #expect(result.count == 1)
        #expect(Set(result.flatMap(\.sources)) == Set(sources.map(\.id)))
        let requests = await journal.requests
        let consolidations = requests.filter { modelPrompt($0).first == "[" }
        #expect(consolidations.count == 3)
        #expect(requests.count == 43)
        for request in consolidations {
            let inputs = try JSONDecoder().decode([CapturedModelSource].self, from: Data(modelPrompt(request).utf8))
            #expect((1...32).contains(inputs.count))
            let requiredLine = try #require(modelInstructions(request).components(separatedBy: "\n").first {
                $0.hasPrefix("Available articles: ")
            })
            let encodedReferences = requiredLine.replacingOccurrences(of: "Available articles: ", with: "")
            let required = try JSONDecoder().decode([Int].self, from: Data(encodedReferences.utf8))
            #expect(required == Set(inputs.flatMap { $0.articleNumbers ?? [] }).sorted())
        }
    }

    @Test("Later consolidation cannot recover numbers absent from its supplied evidence")
    func laterStagesCannotReachBackToDiscardedNumbers() async throws {
        let sources = try distinctSources(count: 40)
        let journal = ModelRequestJournal(consolidation: { prompt in
            let inputs = try JSONDecoder().decode([CapturedModelSource].self, from: Data(prompt.utf8))
            return try consolidationJSON(prompt, text: inputs.count == 1 ? "EUR 29.99." : "A sourced summary.")
        })
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate(sources, model: ControlledLanguageModel(journal: journal),
                                                      capacity: 100000, count: { $0.count })
        }
        #expect(await journal.requests.count == 43)
    }

    @Test("Nonshrinking consolidation fails within a bounded first reduction", .timeLimit(.minutes(1)))
    func nonshrinkingConsolidationDoesNotLoop() async throws {
        var sources = try distinctSources(count: 8)
        for index in sources.indices { sources[index].text = String(repeating: "Source evidence words ", count: 20) }
        let journal = ModelRequestJournal(consolidation: { prompt in
            let inputs = try JSONDecoder().decode([CapturedModelSource].self, from: Data(prompt.utf8))
            let label = String(try #require(inputs.first).text.prefix(20))
            let groups = ["Alpha", "Beta", "Gamma", "Delta"].map {
                ["title": $0 + " " + label,
                 "summary": String(repeating: "Source evidence words ", count: 8) + ".",
                 "sourceNumbers": inputs.map(\.sourceNumber)] as [String: Any]
            }
            return try modelJSON(["groups": groups])
        })
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate(sources, model: ControlledLanguageModel(journal: journal),
                                                      capacity: 4000, count: { $0.count })
        }
        let count = await journal.requests.count
        #expect(count > 8 && count <= 16)
    }

    private func distinctSources(count: Int) throws -> [ArticleSnapshot] {
        let original = try article()
        return (0..<count).map { index in
            var source = original
            source.id = ArticleKey(accountID: original.id.accountID, remoteID: "stored-\(index)")
            source.title = "Stored offer \(index)"
            return source
        }
    }

    private func article() throws -> ArticleSnapshot {
        let url = try #require(URL(string: "https://stored.test/article"))
        return ArticleSnapshot(id: ArticleKey(accountID: UUID(), remoteID: "stored"), feedID: "feed/1",
                               title: "Stored offer", text: "A notebook from Example Store costs EUR 29.99.", url: url)
    }
}

// Deterministic model output keeps these contracts independent of model availability.
private struct FixtureGenerator: SummaryGenerator {
    var omitLast = false
    var invalid = false
    var blank = false
    var failure: (any Error)?
    func summarize(_ articles: [ArticleSnapshot], cloudAllowed: Bool) async throws -> [DigestSection] {
        if let failure { throw failure }
        if invalid { return [DigestSection(title: "Invalid", text: "", sources: [ArticleKey(accountID: UUID(), remoteID: "wrong")])] }
        let sources = omitLast ? Array(articles.dropLast()) : articles
        return [DigestSection(title: "Offers", text: blank ? " \n\t" : "Sourced digest", sources: sources.map(\.id))]
    }
}

private struct StagedFixtureGenerator: SummaryGenerator {
    let journal: ModelRequestJournal

    func summarize(_ articles: [ArticleSnapshot], cloudAllowed: Bool) async throws -> [DigestSection] {
        try await AppleSummaryGenerator().generate(articles, model: ControlledLanguageModel(journal: journal),
                                                  capacity: 10000, count: { $0.count })
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
    @Test("Unchanged valid caches from source-only and first-stage policies are regenerated", arguments: ["", "reader-source-facts-consolidation-v1\n", "reader-source-facts-consolidation-v2\n", "reader-source-facts-consolidation-v3\n", "reader-source-facts-consolidation-v4\n"])
    func previousGenerationCacheIsRegenerated(policyPrefix: String) async throws {
        let (store, feed, articles) = try await fixture()
        let coordinator = DigestCoordinator(repository: store, generator: FixtureGenerator())
        var cached = try #require(try await coordinator.generate(feed: feed).first)
        // Frozen pre-staged wire format, independent of the current coordinator's fingerprint.
        struct PreviousSource: Encodable {
            let id: ArticleKey
            let title: String
            let text: String
            let html: String
            let url: URL?
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let previous = articles.sorted { $0.id.id < $1.id.id }.map {
            PreviousSource(id: $0.id, title: $0.title, text: $0.text, html: $0.html, url: $0.url)
        }
        var previousBytes = Data(policyPrefix.utf8)
        previousBytes.append(try encoder.encode(previous))
        cached.sourceFingerprint = SHA256.hash(data: previousBytes).map { String(format: "%02x", $0) }.joined()
        try await store.saveDigest(cached)
        let regenerated = try #require(try await coordinator.generate(feed: feed).first)
        #expect(regenerated.revision != cached.revision)
        #expect(regenerated.sourceFingerprint != cached.sourceFingerprint)
        #expect(regenerated.warning == nil)
        #expect(Set(regenerated.sources) == Set(articles.map(\.id)))
        for article in articles { #expect(try await store.article(article.id) == article) }
        #expect(try await store.pendingChanges(accountID: feed.id.accountID).isEmpty)
    }
    @Test("Selected native model prose retains every original without changing stored articles")
    func selectedModelStatementsPreserveAllOriginalLinks() async throws {
        let (store, feed, articles) = try await fixture()
        let journal = ModelRequestJournal(response: #"{"groups":[{"title":"Notes","summary":"A sourced summary.","sourceNumbers":[0]}]}"#)
        let coordinator = DigestCoordinator(repository: store, generator: StagedFixtureGenerator(journal: journal))
        let digest = try #require(try await coordinator.generate(feed: feed).first)
        #expect(digest.hasDisplayableContent)
        #expect(digest.warning != nil)
        #expect(Set(digest.sources) == Set(articles.map(\.id)))
        #expect(digest.sections.count == 2)
        #expect(digest.sections.first?.text == "A sourced summary.")
        #expect(digest.sections.first?.sources == [articles[0].id])
        #expect(digest.sections.last?.text == "")
        #expect(digest.sections.last?.sources == [articles[1].id])
        #expect(Set(digest.sections.flatMap(\.sources)) == Set(articles.map(\.id)))
        for article in articles { #expect(try await store.article(article.id) == article) }
        #expect(try await store.pendingChanges(accountID: feed.id.accountID).isEmpty)
        #expect(await journal.requests.count == articles.count + 1)
    }

    @Test("A late staged failure keeps warned originals and cannot change their stored state", arguments: [false, true])
    func stagedFailuresPreserveOriginalsAndOutbox(invalidOutput: Bool) async throws {
        let (store, feed, articles) = try await fixture()
        let journal: ModelRequestJournal
        if invalidOutput {
            journal = ModelRequestJournal(response: #"{"groups":[{"title":"Offer","summary":"EUR 999","sourceNumbers":[0,1]}]}"#)
        } else {
            journal = ModelRequestJournal(failure: nativeModelFailure(1), failureRequest: articles.count)
        }
        let coordinator = DigestCoordinator(repository: store, generator: StagedFixtureGenerator(journal: journal))
        let digest = try #require(try await coordinator.generate(feed: feed).first)
        #expect(digest.warning != nil)
        #expect(Set(digest.sources) == Set(articles.map(\.id)))
        #expect(Set(digest.sections.flatMap(\.sources)) == Set(articles.map(\.id)))
        for article in articles { #expect(try await store.article(article.id) == article) }
        #expect(try await store.pendingChanges(accountID: feed.id.accountID).isEmpty)
        #expect(await journal.requests.count == articles.count + 1)
    }

    @Test("Cache reuse requires complete nonblank sections bound to stored sources", arguments: [0, 1, 2, 3, 4, 5, 6])
    func cachedClaimsRequireValidContentAndSources(kind: Int) async throws {
        let (store, feed, articles) = try await fixture()
        let coordinator = DigestCoordinator(repository: store, generator: FixtureGenerator())
        var cached = try #require(try await coordinator.generate(feed: feed).first)
        switch kind {
        case 1: cached.sections[0].title = " \t"
        case 2: cached.sections[0].text = " \n\t"
        case 3: cached.sections[0].sources = [ArticleKey(accountID: feed.id.accountID, remoteID: "not-stored")]
        case 4: cached.sections[0].sources = [articles[0].id]
        case 5: cached.sections[0].title = "https://invented.test"
        case 6: cached.sections[0].text = "HTTPS://invented.test"
        default: break
        }
        try await store.saveDigest(cached)
        let refreshed = try #require(try await coordinator.generate(feed: feed).first)
        #expect((refreshed.revision == cached.revision) == (kind == 0))
        #expect(refreshed.warning == nil)
        #expect(refreshed.sections.first?.title == "Offers")
        #expect(refreshed.sections.first?.text == "Sourced digest")
        #expect(Set(refreshed.sections.flatMap(\.sources)) == Set(articles.map(\.id)))
        #expect(try await store.pendingChanges(accountID: feed.id.accountID).isEmpty)
    }

    @Test("Blank model text cannot claim complete source coverage or publish a digest")
    func blankModelTextDoesNotClaimCoverage() async throws {
        let (store, feed, articles) = try await fixture()
        let coordinator = DigestCoordinator(repository: store, generator: FixtureGenerator(blank: true))
        await #expect(throws: ReaderError.invalidResponse) { try await coordinator.generate(feed: feed) }
        #expect(try await store.digests().isEmpty)
        for source in articles {
            let original = try #require(try await store.article(source.id))
            #expect(original.text == source.text)
            #expect(!original.read)
        }
        #expect(try await store.pendingChanges(accountID: feed.id.accountID).isEmpty)
    }

    @Test("Model failures keep their native warning and every unread original", arguments: [0, 1, 2, 3])
    func modelFailuresPreserveWarningsAndOriginals(kind: Int) async throws {
        let (store, feed, articles) = try await fixture()
        let failure = nativeModelFailure(kind)
        let coordinator = DigestCoordinator(repository: store, generator: FixtureGenerator(failure: failure))
        let digest = try #require(try await coordinator.generate(feed: feed).first)
        #expect(digest.warning?.contains(failure.localizedDescription) == true)
        #expect(Set(digest.sources) == Set(articles.map(\.id)))
        #expect(Set(digest.sections.flatMap(\.sources)) == Set(articles.map(\.id)))
        for article in articles {
            let original = try #require(try await store.article(article.id))
            #expect(original.title == article.title)
            #expect(original.text == article.text)
            #expect(!original.read)
        }
        #expect(try await store.pendingChanges(accountID: feed.id.accountID).isEmpty)
    }
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
