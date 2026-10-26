import Foundation
import FoundationModels
import NaturalLanguage
import ReaderDomain

@Generable
struct SourceWordSpan: Codable, Sendable {
    var firstWord: Int
    var lastWord: Int
}

/// Original word/punctuation ranges; only Reader resolves model references into text.
struct SourceWordTable {
    let text: String
    let ranges: [Range<String.Index>]

    init(_ text: String) {
        self.text = text
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        if let language = NLLanguageRecognizer.dominantLanguage(for: text) { tokenizer.setLanguage(language) }
        var result: [Range<String.Index>] = []
        var cursor = text.startIndex
        var ordered = true
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            guard range.lowerBound >= cursor else { ordered = false; return false }
            result.append(contentsOf: Self.nonWhitespaceRanges(in: text, range: cursor..<range.lowerBound))
            result.append(range)
            cursor = range.upperBound
            return true
        }
        result.append(contentsOf: Self.nonWhitespaceRanges(in: text, range: cursor..<text.endIndex))
        ranges = ordered ? result : Self.nonWhitespaceRanges(in: text, range: text.startIndex..<text.endIndex)
    }

    var choices: [[String]] {
        ranges.enumerated().map { [String($0.offset), String(text[$0.element])] }
    }

    func resolve(_ span: SourceWordSpan, maximumWords: Int) throws -> String {
        guard span.firstWord >= 0, span.lastWord >= span.firstWord,
              ranges.indices.contains(span.firstWord), ranges.indices.contains(span.lastWord),
              span.lastWord - span.firstWord < maximumWords else { throw ReaderError.invalidResponse }
        let range = ranges[span.firstWord].lowerBound..<ranges[span.lastWord].upperBound
        let value = String(text[range])
        guard SourceQuotationMatching.contains(value, in: text) else { throw ReaderError.invalidResponse }
        return value
    }

    private static func nonWhitespaceRanges(in text: String, range: Range<String.Index>) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var start: String.Index?
        var cursor = range.lowerBound
        while cursor < range.upperBound {
            if text[cursor].isWhitespace {
                if let lower = start { result.append(lower..<cursor); start = nil }
            } else if start == nil {
                start = cursor
            }
            cursor = text.index(after: cursor)
        }
        if let start { result.append(start..<range.upperBound) }
        return result
    }
}
