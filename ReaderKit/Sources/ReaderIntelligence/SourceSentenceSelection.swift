import Foundation
import NaturalLanguage
import ReaderDomain

/// Reader owns the text; the model can select only numbered original sentences.
enum SourceSentenceSelection {
    static func choices(in text: String) -> [String] {
        let whole = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !whole.isEmpty else { return [] }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        if let language = NLLanguageRecognizer.dominantLanguage(for: text) { tokenizer.setLanguage(language) }
        var result: [String] = []
        var cursor = text.startIndex
        var complete = true
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            guard range.lowerBound >= cursor else { complete = false; return false }
            if text[cursor..<range.lowerBound].contains(where: { !$0.isWhitespace }) { complete = false }
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { result.append(sentence) }
            cursor = range.upperBound
            return true
        }
        if text[cursor...].contains(where: { !$0.isWhitespace }) { complete = false }
        // Keep uncovered native-tokenizer text rather than silently discarding it.
        return complete && !result.isEmpty ? result : [whole]
    }

    static func excerpts(_ indices: [Int], from choices: [String]) throws -> [String] {
        guard !indices.isEmpty, indices.count <= 8,
              indices.allSatisfy({ choices.indices.contains($0) }) else { throw ReaderError.invalidResponse }
        return Set(indices).sorted().map { choices[$0] }
    }
}
