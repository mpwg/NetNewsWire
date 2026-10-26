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
    let consolidation: (@Sendable (String) throws -> String)?
    let failure: (any Error)?
    let failureRequest: Int
    private var nextFact = 0
    private(set) var requests: [LanguageModelExecutorGenerationRequest] = []

    init(response: String? = nil, factResponses: [String]? = nil,
         consolidation: (@Sendable (String) throws -> String)? = nil,
         failure: (any Error)? = nil, failureRequest: Int = 0) {
        self.response = response
        self.factResponses = factResponses
        self.consolidation = consolidation
        self.failure = failure
        self.failureRequest = failureRequest
    }

    func record(_ request: LanguageModelExecutorGenerationRequest) throws -> String {
        let ordinal = requests.count
        requests.append(request)
        if let failure, ordinal == failureRequest { throw failure }
        let prompt = modelPrompt(request)
        if let source = try? JSONDecoder().decode(CapturedModelSource.self, from: Data(prompt.utf8)) {
            if let factResponses {
                guard nextFact < factResponses.count else { throw ReaderError.invalidResponse }
                defer { nextFact += 1 }
                return factResponses[nextFact]
            }
            let prefix = String(source.text.prefix(128))
            let excerpt: String
            if source.text.count > 128, let boundary = prefix.lastIndex(where: \.isWhitespace) {
                excerpt = String(prefix[..<boundary]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                excerpt = prefix
            }
            return try modelJSON(["offers": [], "excerpts": [SourceLiteralCatalog.wireLabel(
                excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
            )]])
        }
        if let consolidation { return try consolidation(prompt) }
        if let response { return response }
        return try consolidationJSON(prompt)
    }
}

struct SourceLiteralCatalogTests {
    @Test("Literal choices retain original spelling and protect token and decimal boundaries")
    func choicesComeFromTheOriginal() throws {
        let original = "Example Store: Luma lamp costs EUR 129.99; use SAVE50; pickup only."
        let catalog = SourceLiteralCatalog(fragment: original, original: original)
        #expect(catalog.choices.contains("Example Store"))
        #expect(catalog.choices.contains("Luma lamp"))
        #expect(catalog.choices.contains("EUR 129.99"))
        #expect(catalog.choices.contains("SAVE50"))
        #expect(catalog.choices.contains("pickup only"))
        #expect(!catalog.choices.contains("29.99"))
        #expect(!catalog.choices.contains("SAVE5"))
        #expect(catalog.choices.allSatisfy { SourceQuotationMatching.contains($0, in: original) })
        #expect(Set(catalog.choices).count == catalog.choices.count)
        let schema = try AppleSummaryGenerator.literalFactsSchema(catalog)
        let encoded = String(decoding: try JSONEncoder().encode(schema), as: UTF8.self)
        #expect(encoded.contains("SAVE50"))
        #expect(encoded.contains("129.99"))
    }

    @Test("The candidate catalog includes distinct offer terms")
    func catalogIncludesTwoOffers() {
        let source = "Example Store offers the Luma lamp for EUR 29.99. Code SAVE5 required; pickup only. Other Store offers the Vela kettle for EUR 44.90; online only."
        let catalog = SourceLiteralCatalog(fragment: source, original: source)
        for expected in ["Example Store", "Luma lamp", "EUR 29.99", "Code SAVE5 required",
                         "pickup only", "Other Store", "Vela kettle", "EUR 44.90", "online only"] {
            #expect(catalog.choices.contains(expected), "Missing literal: \(expected)")
        }
    }

    @Test("Encoded labels map only exact original bytes, including canonical Unicode variants")
    func encodedLabelsMapExactOriginals() throws {
        let source = "Cafe\u{301} Café Code \"SAVE\" required; literal %22; 100% off."
        let catalog = SourceLiteralCatalog(fragment: source, original: source)
        for original in ["Cafe\u{301}", "Café", "Code \"SAVE\" required", "literal %22", "100% off"] {
            let label = SourceLiteralCatalog.wireLabel(original)
            let resolved = try #require(catalog.resolve(label), "Missing original: \(original)")
            #expect(Array(resolved.utf8) == Array(original.utf8))
        }
        #expect(catalog.resolve("Code %22SAVE%22 changed") == nil)
        #expect(SourceLiteralCatalog.wireLabel("%22") != SourceLiteralCatalog.wireLabel("\""))
    }

    @Test("Offer roles reject oversized passages and non-price literals")
    func roleCatalogsBoundFields() {
        let longPassage = String(repeating: "details ", count: 30).trimmingCharacters(in: .whitespaces)
        let source = "Luma lamp at Example Store costs EUR 29.99. Code SAVE50; pickup only. " + longPassage
        let catalog = SourceLiteralCatalog(fragment: source, original: source)
        let price = SourceLiteralCatalog.wireLabel("EUR 29.99")
        #expect(catalog.resolve(price, for: .price) == "EUR 29.99")
        #expect(catalog.resolve(SourceLiteralCatalog.wireLabel("Luma lamp"), for: .price) == nil)
        #expect(catalog.resolve(SourceLiteralCatalog.wireLabel("Example Store"), for: .merchant) == "Example Store")
        #expect(catalog.resolve(SourceLiteralCatalog.wireLabel(longPassage), for: .product) == nil)
        #expect(catalog.resolve(SourceLiteralCatalog.wireLabel(longPassage), for: .merchant) == nil)
        #expect(catalog.resolve(SourceLiteralCatalog.wireLabel(longPassage), for: .condition) == nil)
        #expect(catalog.wireChoices(for: .price).allSatisfy { label in
            catalog.resolve(label, for: .price)?.count ?? 1000 <= 32
        })
    }

    @Test("A source split cannot authorize a clipped word or decimal")
    func fragmentCannotInventSourceBoundaries() {
        let original = "Special code SAVE50 costs EUR 129.99."
        let fragment = "SAVE5"
        let catalog = SourceLiteralCatalog(fragment: fragment, original: original)
        #expect(catalog.choices.isEmpty)
        #expect(throws: ReaderError.invalidResponse) { try AppleSummaryGenerator.literalFactsSchema(catalog) }
    }

    @Test("Original Unicode spelling survives catalog construction")
    func unicodeSpellingStaysLiteral() {
        let source = "Cafe\u{301} 店舗: １２９円; coupon SAVE50."
        let catalog = SourceLiteralCatalog(fragment: source, original: source)
        #expect(catalog.choices.contains { $0.unicodeScalars.elementsEqual("Cafe\u{301}".unicodeScalars) })
        #expect(catalog.choices.allSatisfy { SourceQuotationMatching.contains($0, in: source) })
    }
}

struct SourceOfferValidationTests {
    @Test("Partial-only numeric or identifier matches cannot become an extracted offer", arguments: [
        ("29.99", "Luma lamp costs EUR 129.99."),
        ("29", "Luma lamp costs EUR 29.99; batch 30."),
        ("SAVE5", "Luma lamp uses SAVE50; batch 5."),
        ("99", "Luma lamp costs EUR 29.99; model 98.")
    ])
    func partialSourceValuesAreRejected(value: String, source: String) {
        let offer = DigestOfferFact(product: "Luma lamp", price: value)
        #expect(throws: ReaderError.invalidResponse) { try SourceOfferValidation.validate(offer, in: source) }
    }

    @Test("Offer fields must all occur in their own source fragment", arguments: 0..<9)
    func unsupportedOfferFieldsAreRejected(kind: Int) {
        var offer = DigestOfferFact(product: "Luma lamp", merchant: "Example Store", price: "EUR 29.99",
                                    conditions: ["Code SAVE5 required.", "Pickup only."])
        switch kind {
        case 0: offer.product = "Invented kettle"
        case 1: offer.merchant = "Another Store"
        case 2: offer.price = "EUR 999"
        case 3: offer.conditions = ["Free shipping."]
        case 4: offer.product = ""
        case 5: offer.merchant = ""
        case 6: offer.price = " "
        case 7: offer.conditions = ["Pickup only.", "Pickup only."]
        default: offer.conditions = Array(repeating: "Pickup only.", count: 9)
        }
        #expect(throws: ReaderError.invalidResponse) {
            try SourceOfferValidation.validate(offer, in: "Example Store: Luma lamp, EUR 29.99. Code SAVE5 required. Pickup only.")
        }
    }

    @Test("Missing offer fields remain unknown and exact quotes preserve negations", arguments: [false, true])
    func offerFieldsKeepUnknownValuesAndSourceSpelling(unknown: Bool) throws {
        let offer = DigestOfferFact(product: "Luma lamp", merchant: unknown ? nil : "Example Store",
                                    price: unknown ? nil : "EUR 29.99", conditions: ["Don't combine offers; pickup only."])
        let result = try SourceOfferValidation.validate(
            offer, in: "Example Store: Luma lamp, EUR 29.99. Don't combine offers; pickup only.")
        #expect(result == offer)
        #expect(result.merchant == offer.merchant)
        #expect(result.price == offer.price)
        #expect(result.conditions == ["Don't combine offers; pickup only."])
    }
}

struct SourceFactValidationTests {
    // Explicit multilingual literal-source fixtures, not translated UI strings.
    @Test("Source quotation matching rejects partial ASCII tokens and decimals while retaining exact Unicode", arguments: [
        ("29.99", "EUR 129.99", false), ("29", "EUR 29.99", false), ("99", "EUR 29.99", false),
        ("SAVE5", "Code SAVE50", false), ("EUR 29.99", "EUR 29.99.", true),
        ("29.99 EUR", "商店の価格は29.99 EUR。", true), ("Cafe\u{301}", "Cafe\u{301} offer", true),
        ("Café", "Cafe\u{301} offer", false)
    ])
    func quotationsNeedExactTokenBoundaries(value: String, source: String, valid: Bool) {
        #expect(SourceQuotationMatching.contains(value, in: source) == valid)
    }

    @Test("Numeric citation syntax must occur in the cited source, not merely share its digits", arguments: [
        ("A claim [1].", "Model 1.", true),
        ("A claim [ 1 ].", "Model 1.", true),
        ("A claim [1, 2].", "Models 1 and 2.", true),
        ("A claim [1–2].", "Models 1 and 2.", true),
        ("Array [1] is retained.", "Array [1] is source data.", false),
        ("Year (2026) is retained.", "Year 2026.", false)
    ])
    func numericCitationsNeedLiteralSourceSupport(text: String, source: String, unsupported: Bool) {
        #expect(SourceFactValidation.hasUnownedNumericCitation(in: text, source: source) == unsupported)
    }

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
    @Test("A native source quote cannot authorize a smaller price clipped from an original")
    func partialPriceQuotesStopBeforeConsolidation() async throws {
        var source = try article()
        source.text = "The price is EUR 129.99."
        let journal = ModelRequestJournal(factResponses: [try modelJSON(["offers": [], "excerpts": ["29.99"]])])
        await #expect(throws: ReaderError.invalidResponse) {
            try await AppleSummaryGenerator().generate(
                [source], model: ControlledLanguageModel(journal: journal), capacity: 10000, count: { $0.count })
        }
        #expect(await journal.requests.count == 1)
    }

    @Test("Native offer decoding preserves null fields without inventing a price")
    func nativeOfferFieldsMayRemainUnknown() async throws {
        var source = try article()
        source.text = "The Luma lamp is available for pickup only."
        let journal = ModelRequestJournal(
            response: #"{"groups":[{"title":"Lamp","summary":"Luma lamp: pickup only.","sourceNumbers":[0]}]}"#,
            factResponses: [try modelJSON(["offers": [["product": "Luma lamp", "merchant": NSNull(), "price": NSNull(), "conditions": ["pickup only"]]], "excerpts": []])])
        let result = try await AppleSummaryGenerator().generate(
            [source], model: ControlledLanguageModel(journal: journal), capacity: 10000, count: { $0.count })
        let offer = try #require(result.first?.sourceFacts?.first?.offers?.first)
        #expect(offer.merchant == nil)
        #expect(offer.price == nil)
        #expect(offer.conditions == ["pickup only"])
    }

    @Test("Encoded offer conditions resolve to exact original text before consolidation")
    func encodedOfferConditionsKeepOriginalBytes() async throws {
        var source = try article()
        source.text = "Luma lamp is available. Code \"SAVE\" required; pickup only."
        let condition = "Code \"SAVE\" required"
        let journal = ModelRequestJournal(factResponses: [try modelJSON([
            "offers": [["product": "Luma lamp", "merchant": NSNull(), "price": NSNull(),
                        "conditions": [SourceLiteralCatalog.wireLabel(condition), "pickup only"]]],
            "excerpts": []
        ])])
        let sections = try await AppleSummaryGenerator().generate(
            [source], model: ControlledLanguageModel(journal: journal), capacity: 100000, count: { $0.count })
        let offer = try #require(sections.first?.sourceFacts?.first?.offers?.first)
        #expect(offer.conditions == [condition, "pickup only"])
        let requests = await journal.requests
        let consolidation = modelPrompt(try #require(requests.last))
        #expect(!consolidation.contains("%22"))
        let inputs = try JSONDecoder().decode([CapturedModelSource].self, from: Data(consolidation.utf8))
        let payload = try #require(inputs.first).text
        let decoded = try #require(JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [[String: Any]])
        let conditions = try #require(decoded.first?["conditions"] as? [String])
        #expect(conditions == [condition, "pickup only"])
    }

    @Test("A non-price source value cannot enter the price field")
    func roleMismatchStopsBeforeConsolidation() async throws {
        var source = try article()
        source.text = "Example Store offers the Luma lamp for EUR 29.99."
        let journal = ModelRequestJournal(factResponses: [try modelJSON([
            "offers": [["product": "Luma lamp", "merchant": "Example Store",
                        "price": "Example Store", "conditions": []]], "excerpts": []
        ])])
        await #expect(throws: ReaderError.invalidResponse) {
            try await AppleSummaryGenerator().generate(
                [source], model: ControlledLanguageModel(journal: journal), capacity: 100000, count: { $0.count })
        }
        #expect(await journal.requests.count == 1)
    }

    @Test("Native offer records retain each product's own price and conditions without Reader identifiers in model input")
    func structuredOffersKeepTheirOwnTerms() async throws {
        var source = try article()
        source.text = "Example Store offers the Luma lamp for EUR 29.99. Code SAVE5 required; pickup only. Other Store offers the Vela kettle for EUR 44.90; online only."
        let first: [String: Any] = ["product": "Luma lamp", "merchant": "Example Store", "price": "EUR 29.99",
                                    "conditions": ["Code SAVE5 required", "pickup only"]]
        let second: [String: Any] = ["product": "Vela kettle", "merchant": "Other Store", "price": "EUR 44.90",
                                     "conditions": ["online only"]]
        let journal = ModelRequestJournal(factResponses: [try modelJSON(["offers": [first, second], "excerpts": []])],
                                          consolidation: { prompt in
            let inputs = try JSONDecoder().decode([CapturedModelSource].self, from: Data(prompt.utf8))
            #expect(inputs.count == 1)
            let input = try #require(inputs.first)
            let decoded = try JSONSerialization.jsonObject(with: Data(input.text.utf8))
            let values = try #require(decoded as? [[String: Any]])
            #expect(values.count == 2)
            #expect(values[0]["product"] as? String == "Luma lamp")
            #expect(values[0]["price"] as? String == "EUR 29.99")
            #expect(values[0]["conditions"] as? [String] == ["Code SAVE5 required", "pickup only"])
            #expect(values[1]["price"] as? String == "EUR 44.90")
            #expect(values.allSatisfy { $0["id"] == nil })
            return #"{"groups":[{"title":"Offers","summary":"Luma lamp: EUR 29.99; SAVE5 required, pickup only. Vela kettle: EUR 44.90, online only.","sourceNumbers":[0]}]}"#
        })
        let sections = try await AppleSummaryGenerator().generate(
            [source], model: ControlledLanguageModel(journal: journal), capacity: 100000, count: { $0.count })
        let facts = try #require(sections.first?.sourceFacts?.first)
        let offers = try #require(facts.offers)
        #expect(facts.source == source.id)
        #expect(offers.count == 2)
        #expect(offers[0].product == "Luma lamp")
        #expect(offers[0].conditions == ["Code SAVE5 required", "pickup only"])
        #expect(offers[1].merchant == "Other Store")
        #expect(offers[1].price == "EUR 44.90")
        #expect(Set(offers.map(\.id)).count == 2)
        #expect(facts.excerpts.allSatisfy(source.text.contains))
        #expect(await journal.requests.count == 2)
    }

    @Test("Hierarchical consolidation retains typed offers under all forty original identities")
    func hierarchicalOffersKeepOriginalFieldRecords() async throws {
        let sources = try distinctSources(count: 40)
        let facts = try sources.map { source in
            try modelJSON(["offers": [["product": source.title, "merchant": "Example Store", "price": "EUR 29.99", "conditions": []]],
                           "excerpts": []])
        }
        let journal = ModelRequestJournal(factResponses: facts)
        let sections = try await AppleSummaryGenerator().generate(
            sources, model: ControlledLanguageModel(journal: journal), capacity: 100000, count: { $0.count })
        let retained = try #require(sections.first?.sourceFacts)
        #expect(retained.count == sources.count)
        var identities: Set<UUID> = []
        for source in sources {
            let offers = try #require(retained.first { $0.source == source.id }?.offers)
            #expect(offers.count == 1)
            #expect(offers.first?.product == source.title)
            #expect(offers.first?.merchant == "Example Store")
            #expect(offers.first?.price == "EUR 29.99")
            if let offer = offers.first { identities.insert(offer.id) }
        }
        #expect(identities.count == sources.count)
        #expect(await journal.requests.filter { modelPrompt($0).first == "[" }.count == 3)
    }

    @Test("Native offer extraction rejects fabricated fields before consolidation")
    func fabricatedOfferFieldsStopGeneration() async throws {
        let source = try article()
        let journal = ModelRequestJournal(factResponses: [try modelJSON([
            "offers": [["product": "notebook", "merchant": "Invented Store", "price": "EUR 29.99", "conditions": []]],
            "excerpts": []
        ])])
        await #expect(throws: ReaderError.invalidResponse) {
            try await AppleSummaryGenerator().generate(
                [source], model: ControlledLanguageModel(journal: journal), capacity: 10000, count: { $0.count })
        }
        #expect(await journal.requests.count == 1)
    }

    @Test("Actual native output rejects invented bracket references while preserving copied bracket data", arguments: [false, true])
    func nativeNumericCitationsUseActualCitedText(copied: Bool) async throws {
        var source = try article()
        source.title = "Model 1."
        source.text = copied ? "Source data [1]. The price is EUR 29.99." : "The price is EUR 29.99."
        let journal = ModelRequestJournal(response:
            #"{"groups":[{"title":"Price","summary":"EUR 29.99 [1].","sourceNumbers":[0]}]}"#)
        if copied {
            let sections = try await AppleSummaryGenerator().generate(
                [source], model: ControlledLanguageModel(journal: journal), capacity: 10000, count: { $0.count })
            #expect(sections.first?.text == "EUR 29.99 [1].")
            #expect(sections.first?.sources == [source.id])
        } else {
            await #expect(throws: ReaderError.self) {
                try await AppleSummaryGenerator().generate(
                    [source], model: ControlledLanguageModel(journal: journal), capacity: 10000, count: { $0.count })
            }
        }
        #expect(await journal.requests.count == 2)
    }

    @Test("Each source fragment keeps its merchant, price and conditions in one evidence packet")
    func fragmentFactsKeepTheirSharedReference() async throws {
        let first = try article()
        var second = first
        second.id.remoteID = "second-offer"
        second.text = "Other Store offers a kettle for EUR 44.90. Online only."
        let firstText = first.text
        let journal = ModelRequestJournal(factResponses: [
            try modelJSON(["offers": [], "excerpts": [first.title, firstText]]),
            try modelJSON(["offers": [], "excerpts": ["Other Store offers a kettle for EUR 44.90.", "Online only."]])
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
        #expect(result.first?.sourceFacts == [
            DigestSourceFacts(source: first.id, excerpts: [first.title, firstText]),
            DigestSourceFacts(source: second.id, excerpts: ["Other Store offers a kettle for EUR 44.90.", "Online only."])
        ])
    }

    @Test("Opt-in evaluation captures rejected drafts without bypassing validation", arguments: [false, true])
    func traceRetainsRejectedDraft(factFailure: Bool) async throws {
        let invalid = factFailure ? #"{"offers":[],"excerpts":["A fabricated quote."]}"#
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
        #expect(result == [DigestSection(title: "Notebook", text: "Example Store: EUR 29.99.", sources: [first.id, second.id],
                                        sourceFacts: [first, second].map {
                                            DigestSourceFacts(source: $0.id, excerpts: [String(($0.title + "\n" + $0.text).prefix(128))])
                                        })])
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
        #expect(result == [DigestSection(title: "Notebook", text: "Example Store: EUR 29.99.", sources: [source.id],
                                        sourceFacts: [DigestSourceFacts(source: source.id,
                                                                       excerpts: [String((source.title + "\n" + source.text).prefix(128))])])])
    }

    @Test("Language selection changes consolidation instructions while retaining original quotations", arguments: [("en_AT", "English"), ("de_AT", "German")])
    func instructionsNameRequestedLanguage(localeID: String, language: String) async throws {
        let journal = ModelRequestJournal()
        let source = try article()
        let result = try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                               capacity: 10000, locale: Locale(identifier: localeID), count: { $0.count })
        let requests = await journal.requests
        #expect(requests.count == 2)
        let consolidation = modelInstructions(try #require(requests.last))
        #expect(consolidation.contains("in " + language + "."))
        #expect(result.first?.sourceFacts?.first?.excerpts == [source.title + "\n" + source.text])
        #expect(result.first?.sourceFacts?.first?.source == source.id)
    }

    @Test("Every raw source character reaches extraction and every stage respects its runtime budget", arguments: [8000, 12000])
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
            if let schema = request.schema,
               (try? JSONDecoder().decode(CapturedModelSource.self, from: Data(prompt.utf8))) != nil {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let schemaText = String(decoding: try encoder.encode(schema), as: UTF8.self)
                #expect((prompt + schemaText).count <= capacity - modelInstructions(request).count - 2000)
            } else {
                #expect(prompt.count <= capacity - modelInstructions(request).count - 2000)
            }
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
                                                      capacity: 8000, cloudPermission: { await journal.requests.isEmpty },
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
        #expect(result == [DigestSection(title: "Notebook", text: "Example Store: EUR 29.99.", sources: [source.id],
                                        sourceFacts: [DigestSourceFacts(source: source.id,
                                                                       excerpts: [String((source.title + "\n" + source.text).prefix(128))])])])
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
        let journal = ModelRequestJournal(factResponses: [try modelJSON(["offers": [], "excerpts": ["Other Store costs EUR 10.00."]])])
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate([source], model: ControlledLanguageModel(journal: journal),
                                                      capacity: laterFragment ? 8000 : 10000, count: { $0.count })
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
            #expect(result.first?.title == "Context")
            #expect(result.first?.text == "Relevant background context.")
            #expect(result.first?.sources == [source.id])
            let facts = try #require(result.first?.sourceFacts)
            #expect(facts.count == 1)
            #expect(facts[0].source == source.id)
            #expect(facts[0].excerpts.allSatisfy { (source.title + "\n" + source.text).contains($0) })
            #expect(facts[0].excerpts.contains { $0.contains("9999") })
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
        let retained = try #require(result.first?.sourceFacts)
        #expect(retained.count == sources.count)
        for source in sources {
            #expect(retained.first { $0.source == source.id }?.excerpts == [String((source.title + "\n" + source.text).prefix(128))])
        }
        #expect(retained.allSatisfy { !$0.text.contains("A sourced summary.") })
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
        var sources = try distinctSources(count: 40)
        for index in sources.indices { sources[index].text = String(repeating: "Source evidence words ", count: 20) }
        let journal = ModelRequestJournal(consolidation: { prompt in
            let inputs = try JSONDecoder().decode([CapturedModelSource].self, from: Data(prompt.utf8))
            let label = String(try #require(inputs.first).text.prefix(20))
            let groups = ["Alpha", "Beta", "Gamma", "Delta"].map {
                ["title": $0 + " " + label,
                 "summary": String(repeating: "Source evidence words ", count: 40) + ".",
                 "sourceNumbers": inputs.map(\.sourceNumber)] as [String: Any]
            }
            return try modelJSON(["groups": groups])
        })
        await #expect(throws: ReaderError.self) {
            try await AppleSummaryGenerator().generate(sources, model: ControlledLanguageModel(journal: journal),
                                                      capacity: 10000, count: { $0.count })
        }
        let requests = await journal.requests
        let facts = requests.filter { modelPrompt($0).first == "{" }
        let consolidations = try requests.filter { modelPrompt($0).first == "[" }.map {
            try JSONDecoder().decode([CapturedModelSource].self, from: Data(modelPrompt($0).utf8))
        }
        #expect(facts.count >= sources.count)
        #expect(!consolidations.isEmpty)
        #expect(consolidations.count <= facts.count)
        #expect(consolidations.flatMap { $0 }.allSatisfy { input in
            !["Alpha ", "Beta ", "Gamma ", "Delta "].contains { input.text.hasPrefix($0) }
        })
        #expect(requests.count == facts.count + consolidations.count)
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
    var fabricatedFacts = false
    var failure: (any Error)?
    func summarize(_ articles: [ArticleSnapshot], cloudAllowed: Bool) async throws -> [DigestSection] {
        if let failure { throw failure }
        if invalid { return [DigestSection(title: "Invalid", text: "", sources: [ArticleKey(accountID: UUID(), remoteID: "wrong")])] }
        let sources = omitLast ? Array(articles.dropLast()) : articles
        let facts = fabricatedFacts ? sources.map { DigestSourceFacts(source: $0.id, excerpts: ["Invented terms."]) } : nil
        return [DigestSection(title: "Offers", text: blank ? " \n\t" : "Sourced digest", sources: sources.map(\.id), sourceFacts: facts)]
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
    @Test("Unchanged caches from earlier generation and validation policies are regenerated", arguments: ["", "reader-source-facts-consolidation-v1\n", "reader-source-facts-consolidation-v2\n", "reader-source-facts-consolidation-v3\n", "reader-source-facts-consolidation-v4\n", "reader-source-facts-consolidation-v5\n", "reader-source-facts-consolidation-v6\n", "reader-source-facts-consolidation-v7\n", "reader-source-facts-consolidation-v8\n", "reader-source-facts-consolidation-v9\n", "reader-source-facts-consolidation-v10\n", "reader-source-facts-consolidation-v11\n", "reader-source-facts-consolidation-v12\n", "reader-source-facts-consolidation-v13\n"])
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

    @Test("Cache reuse requires complete nonblank sections and source-owned facts", arguments: 0..<12)
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
        case 7: cached.sections[0].sourceFacts = [DigestSourceFacts(source: articles[0].id, excerpts: ["Invented terms."])]
        case 8: cached.sections[0].sourceFacts = [DigestSourceFacts(source: articles[0].id, excerpts: [articles[1].title])]
        case 9: cached.sections[0].sourceFacts = [DigestSourceFacts(source: articles[0].id, excerpts: [])]
        case 10: cached.sections[0].sourceFacts = [DigestSourceFacts(source: articles[0].id, excerpts: [articles[0].title],
                                                                   offers: [DigestOfferFact(product: articles[0].title, merchant: "Invented Store")])]
        case 11: cached.sections[0].sourceFacts = [DigestSourceFacts(source: articles[0].id, excerpts: [articles[0].title],
                                                                   offers: [DigestOfferFact(product: articles[0].title, conditions: [articles[1].title])])]
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

    @Test("A generator cannot publish source facts that do not occur in their own originals")
    func fabricatedSourceFactsAreNotPublished() async throws {
        let (store, feed, articles) = try await fixture()
        let coordinator = DigestCoordinator(repository: store, generator: FixtureGenerator(fabricatedFacts: true))
        await #expect(throws: ReaderError.self) { try await coordinator.generate(feed: feed) }
        #expect(try await store.digests().isEmpty)
        for article in articles { #expect(try await store.article(article.id) == article) }
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
