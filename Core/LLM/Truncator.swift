/// Cuts posting text to a token budget and keeps the part the fit rubric needs most:
/// the first paragraph (title and ATS facts) and the requirements section.
/// The rest fills the budget in document order, up to the first paragraph that does not fit.
public enum Truncator {
    public static func truncate(_ text: String, toTokens budget: Int, count: (String) async throws -> Int) async rethrows -> String {
        guard try await count(text) > budget else { return text }
        let paragraphs = text.components(separatedBy: "\n\n")
        var keep: Set = [0]
        if var i = paragraphs.firstIndex(where: isRequirementsHeading) {
            repeat { keep.insert(i); i += 1 } while i < paragraphs.count && !isHeading(paragraphs[i])
        }
        func joined(_ set: Set<Int>) -> String { set.sorted().map { paragraphs[$0] }.joined(separator: "\n\n") }

        guard try await count(joined(keep)) <= budget else {
            // The kept part alone is too long: drop lines from its end.
            var lines = joined(keep).components(separatedBy: "\n")
            while lines.count > 1, try await count(lines.joined(separator: "\n")) > budget { lines.removeLast() }
            return lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
        }
        for i in paragraphs.indices where !keep.contains(i) {
            guard try await count(joined(keep.union([i]))) <= budget else { break }
            keep.insert(i)
        }
        return joined(keep)
    }

    /// Paragraphs of more than `maxWords` words, in order. The client retries with this after the model's
    /// language check rejects an English page on its short header lines (threadly: "Threadly Technologies").
    public static func droppingShortParagraphs(_ text: String, maxWords: Int = 3) -> String {
        text.components(separatedBy: "\n\n").filter { $0.split(whereSeparator: \.isWhitespace).count > maxWords }.joined(separator: "\n\n")
    }

    /// Drops every LINE that mentions visa or sponsorship. The client retries with this after the model's
    /// safety filter blocks a posting on a sentence like "We are unable to sponsor work visas for this
    /// position."; grounding still reaches the FLAG/quote because it reads the original full text.
    public static func droppingVisaLines(_ text: String) -> String {
        text.components(separatedBy: "\n").filter {
            let lower = $0.lowercased()
            return !lower.contains("visa") && !lower.contains("sponsor")
        }.joined(separator: "\n")
    }

    /// A one-line paragraph of at most 5 words, no digits, not a list item ("Benefits", "Nice to have").
    /// "5+ years of Python" as its own paragraph is a requirement, not the next heading.
    static func isHeading(_ paragraph: String) -> Bool {
        !paragraph.contains("\n") && !paragraph.hasPrefix("- ") && !paragraph.contains(where: \.isNumber)
            && paragraph.split(whereSeparator: \.isWhitespace).count <= 5
    }

    /// First line reads like "Requirements", "💡 Qualifications", "What you'll need:".
    static func isRequirementsHeading(_ paragraph: String) -> Bool {
        let line = paragraph.prefix { $0 != "\n" }
        return line.count <= 60 && line.contains(
            /^[^\p{L}]*(\p{L}+ )?(requirements|qualifications|what you[’']ll need|what we[’']re looking for|must[- ]haves?|who you are|your profile|what you bring)\b/
                .ignoresCase()
        )
    }
}
