import Foundation
import NaturalLanguage

/// Candidate values are copied from the source; membership does not prove their semantic role.
struct SourceLiteralCatalog {
    let choices: [String]

    init(fragment: String, original: String) {
        var values: [String] = []
        var seen: Set<String> = []

        func add(_ raw: String) {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value.count <= 320,
                  SourceQuotationMatching.contains(value, in: fragment),
                  SourceQuotationMatching.contains(value, in: original),
                  seen.insert(value).inserted else { return }
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
        choices = values
    }
}
