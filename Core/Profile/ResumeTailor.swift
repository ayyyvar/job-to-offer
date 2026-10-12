import Foundation
import NaturalLanguage

/// One reusable piece of the candidate's history: a skill, a resume bullet, a project, a language or a
/// past application answer. The library of these is what a tailored resume picks from.
public struct ExperienceItem: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, CaseIterable, Sendable { case skill, experience, project, language, answer }

    public var id: UUID
    public var kind: Kind
    public var text: String

    public init(id: UUID = UUID(), kind: Kind, text: String) {
        self.id = id
        self.kind = kind
        self.text = text
    }

    /// Resume lines that start with a bullet mark become `.experience` items. PDF text wraps long
    /// bullets: a following line that starts lowercase or with a digit continues the bullet.
    public static func bullets(in resumeText: String) -> [ExperienceItem] {
        var texts: [String] = []
        var open = false
        for line in resumeText.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let first = trimmed.first else { open = false; continue }
            if "-•*●▪◦–".contains(first) {
                texts.append(trimmed.dropFirst().trimmingCharacters(in: .whitespaces))
                open = true
            } else if open, first.isLowercase || first.isNumber {
                texts[texts.count - 1] += " " + trimmed
            } else {
                open = false
            }
        }
        return texts.filter { !$0.isEmpty }.map { ExperienceItem(kind: .experience, text: $0) }
    }
}

/// Picks the library items closest to a posting. Vector search is a brute-force cosine scan over
/// Apple's on-device sentence embedding.
/// ponytail: embeds every item per query, O(n); cache vectors in the store if libraries pass ~5k items.
public enum ResumeTailor {
    public typealias Embed = @Sendable (String) -> [Double]?

    public static let sentenceEmbed: Embed = { text in
        NLEmbedding.sentenceEmbedding(for: .english)?.vector(for: text)
    }

    public static func select(_ items: [ExperienceItem], for query: String, limit: Int,
                              embed: Embed = sentenceEmbed) -> [ExperienceItem] {
        let q = embed(query)
        let words = Set(query.lowercased().split { !$0.isLetter && !$0.isNumber })
        func score(_ text: String) -> Double {
            if let q { return embed(text).map { cosine(q, $0) } ?? 0 }
            return Double(Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }).intersection(words).count)
        }
        return items.map { ($0, score($0.text)) }
            .sorted { $0.1 > $1.1 }
            .prefix(limit).map(\.0)
    }

    /// The query text for a posting: what it requires, then the stack.
    public static func query(digest: PostingDigest, stack: [String]) -> String {
        (digest.mustHave + digest.niceToHave + stack).joined(separator: ", ")
    }

    static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        let dot = zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
        let norm = (a.reduce(0) { $0 + $1 * $1 } * b.reduce(0) { $0 + $1 * $1 }).squareRoot()
        return norm == 0 ? 0 : dot / norm
    }
}
