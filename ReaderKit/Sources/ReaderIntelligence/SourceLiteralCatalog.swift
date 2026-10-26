import Foundation
import NaturalLanguage

/// Candidate values are copied from the source; membership does not prove their semantic role.
struct SourceLiteralCatalog {
    let choices: [String]
    let wireChoices: [String]
    private let originalByLabel: [Data: String]

    init(fragment: String, original: String) {
        var values: [String] = []
        var seen: Set<Data> = []

        func add(_ raw: String) {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value.count <= 320,
                  SourceQuotationMatching.contains(value, in: fragment),
                  SourceQuotationMatching.contains(value, in: original),
                  seen.insert(Data(value.utf8)).inserted else { return }
            values.append(value)
        }

        add(fragment)
        let prefix = String(fragment.prefix(128))
        if fragment.count > 128, let boundary = prefix.lastIndex(where: \.isWhitespace) {
            add(String(prefix[..<boundary]))
        }

        let words = NLTokenizer(unit: .word)
        words.string = fragment
        var wordRanges: [Range<String.Index>] = []
        words.enumerateTokens(in: fragment.startIndex..<fragment.endIndex) { range, _ in
            wordRanges.append(range)
            return true
        }
        for index in wordRanges.indices {
            add(String(fragment[wordRanges[index]]))
            if index + 1 < wordRanges.count {
                add(String(fragment[wordRanges[index].lowerBound..<wordRanges[index + 1].upperBound]))
            }
            if index + 2 < wordRanges.count {
                add(String(fragment[wordRanges[index].lowerBound..<wordRanges[index + 2].upperBound]))
            }
        }

        let sentences = NLTokenizer(unit: .sentence)
        sentences.string = fragment
        sentences.enumerateTokens(in: fragment.startIndex..<fragment.endIndex) { range, _ in
            let sentence = String(fragment[range])
            add(sentence)
            add(sentence.trimmingCharacters(in: CharacterSet(charactersIn: ".!?").union(.whitespacesAndNewlines)))
            for clause in sentence.components(separatedBy: CharacterSet(charactersIn: ";|\n")) {
                add(clause)
                add(clause.trimmingCharacters(in: CharacterSet(charactersIn: ".!?").union(.whitespacesAndNewlines)))
            }
            return true
        }

        let expression = try? NSRegularExpression(
            pattern: #"(?i)(?:(?:EUR|USD|GBP|CHF|€|\$|£)\s*\d[\d.,]*|\d[\d.,]*\s*(?:EUR|USD|GBP|CHF|€|\$|£|%))"#
        )
        let nsRange = NSRange(fragment.startIndex..<fragment.endIndex, in: fragment)
        expression?.enumerateMatches(in: fragment, range: nsRange) { match, _, _ in
            guard let match, let range = Range(match.range, in: fragment) else { return }
            add(String(fragment[range]))
        }
        var originals: [Data: String] = [:]
        var labels: [String] = []
        var collision = false
        for value in values {
            let label = Self.wireLabel(value)
            let key = Data(label.utf8)
            if let existing = originals[key], Data(existing.utf8) != Data(value.utf8) {
                collision = true
                break
            }
            originals[key] = value
            labels.append(label)
        }
        choices = values
        wireChoices = collision ? [] : labels
        originalByLabel = collision ? [:] : originals
    }

    /// Encoding is only a transport label; recovery requires an exact catalog entry.
    static func wireLabel(_ input: String) -> String {
        input.unicodeScalars.map { scalar in
            if scalar.value == 0x22 || scalar.value == 0x25 || scalar.value == 0x5C ||
                scalar.value < 0x20 || scalar.value == 0x7F {
                return String(format: "%%%02X", scalar.value)
            }
            return String(scalar)
        }.joined()
    }

    func resolve(_ label: String) -> String? {
        originalByLabel[Data(label.utf8)]
    }
}
