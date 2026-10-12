import Foundation
import PDFKit

public enum ResumeFileType: Equatable, Sendable {
    case pdf, latex, plain

    public init(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "pdf": self = .pdf
        case "tex": self = .latex
        default: self = .plain
        }
    }
}

public enum ResumeImportError: Error, Equatable, Sendable {
    case unreadable
}

/// Resume text for `SkillTiers.derived`. PDFKit runs on macOS and iOS, so this stays in Core (CLAUDE.md §4).
public enum ResumeImporter {
    public static func text(from data: Data, type: ResumeFileType) throws -> String {
        switch type {
        case .pdf:
            guard let text = PDFDocument(data: data)?.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ResumeImportError.unreadable
            }
            return text
        case .latex:
            guard let raw = String(data: data, encoding: .utf8) else { throw ResumeImportError.unreadable }
            return strippedLaTeX(raw)
        case .plain:
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                throw ResumeImportError.unreadable
            }
            return text
        }
    }

    /// One line's text up to its first unescaped `%` (a `\%` is a literal percent, not a comment start).
    static func stripComment(_ line: Substring) -> Substring {
        var previousWasBackslash = false
        for (i, c) in line.enumerated() {
            if c == "%", !previousWasBackslash { return line.prefix(i) }
            previousWasBackslash = (c == "\\") && !previousWasBackslash
        }
        return line
    }

    /// Deterministic, regex-based: drop comments and the preamble, unwrap text commands, collapse blank lines.
    static func strippedLaTeX(_ source: String) -> String {
        var text = source.split(separator: "\n", omittingEmptySubsequences: false).map(stripComment).joined(separator: "\n")
        if let range = text.range(of: "\\begin{document}") { text = String(text[range.upperBound...]) }
        text = text.replacing(/\\item\b/, with: "\n- ")
        // Unwrap one-argument text commands, keeping the argument: \textbf{X} / \section{X} → X.
        while let match = text.firstMatch(of: /\\[a-zA-Z]+\*?(\[[^\]]*\])?\{([^{}]*)\}/) {
            text.replaceSubrange(match.range, with: match.output.2)
        }
        text = text.replacing("\\\\", with: "\n")
            .replacing(/\\[a-zA-Z]+\*?/, with: " ")
            .replacing(/[{}~]/, with: " ")
        text = text.replacing(/[ \t]+/, with: " ")
        text = text.replacing(/\n{3,}/, with: "\n\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
