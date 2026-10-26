import Foundation
import ReaderDomain

/// Reader restores exact source literals; the model never supplies replacement values.
struct SourceNumberReferences: Sendable {
    let packetNumber: Int
    private let literalToMarker: [String: String]
    private let markerToLiteral: [String: String]

    init(packetNumber: Int, text: String) throws {
        guard packetNumber >= 0, !text.contains("⟦"), !text.contains("⟧") else { throw ReaderError.invalidResponse }
        self.packetNumber = packetNumber
        var forward: [String: String] = [:]
        var reverse: [String: String] = [:]
        for match in text.matches(of: /[0-9]+(?:[.,][0-9]+)*/) {
            let literal = String(match.output)
            if forward[literal] != nil { continue }
            let marker = "⟦\(packetNumber):\(forward.count)⟧"
            forward[literal] = marker
            reverse[marker] = literal
        }
        literalToMarker = forward
        markerToLiteral = reverse
    }

    func masked(_ text: String) throws -> String {
        guard !text.contains("⟦"), !text.contains("⟧") else { throw ReaderError.invalidResponse }
        var result = ""
        var cursor = text.startIndex
        for match in text.matches(of: /[0-9]+(?:[.,][0-9]+)*/) {
            guard let marker = literalToMarker[String(match.output)] else { throw ReaderError.invalidResponse }
            result += text[cursor..<match.range.lowerBound]
            result += marker
            cursor = match.range.upperBound
        }
        result += text[cursor...]
        return result
    }

    static func restored(_ text: String, tables: [Self], citedPackets: Set<Int>) throws -> String {
        var result = ""
        var cursor = text.startIndex
        for match in text.matches(of: /⟦[0-9]+:[0-9]+⟧/) {
            let marker = String(match.output)
            guard let table = tables.first(where: { $0.markerToLiteral[marker] != nil }),
                  citedPackets.contains(table.packetNumber),
                  let literal = table.markerToLiteral[marker] else { throw ReaderError.invalidResponse }
            result += text[cursor..<match.range.lowerBound]
            result += literal
            cursor = match.range.upperBound
        }
        result += text[cursor...]
        guard !result.contains("⟦"), !result.contains("⟧") else { throw ReaderError.invalidResponse }
        return result
    }
}
