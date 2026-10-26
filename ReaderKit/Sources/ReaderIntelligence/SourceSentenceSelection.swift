import Foundation
import NaturalLanguage
import ReaderDomain

enum SourceSentenceSelection {
    static func choices(in text: String) -> [String] {
        let whole = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !whole.isEmpty else { return [] }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
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
        // Never silently discard text that the native tokenizer did not cover.
        return complete && !result.isEmpty ? result : [whole]
    }

    static func contextualExcerpt(_ indices: [Int], in fragment: String) throws -> String {
        _ = try excerpts(indices, from: choices(in: fragment))
        // A sentence may depend on restrictions elsewhere in this bounded fragment.
        // Keep the original context rather than treating sentence selection as semantic proof.
        return fragment.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func excerpts(_ indices: [Int], from choices: [String]) throws -> [String] {
        guard !indices.isEmpty, indices.count <= 8,
              indices.allSatisfy({ choices.indices.contains($0) }) else { throw ReaderError.invalidResponse }
        var seen: Set<Int> = []
        return indices.compactMap { seen.insert($0).inserted ? choices[$0] : nil }
    }
}
