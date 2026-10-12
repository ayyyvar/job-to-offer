import Foundation

/// CLAUDE.md rule 5: instructions + prompt must leave ≥ 600 tokens for the output.
public enum PromptBudget {
    public static let outputReserve = 600

    /// Tokens left for the posting text. `overheadTokens`: instructions, schema and fixed prompt text.
    public static func available(contextSize: Int, overheadTokens: Int) -> Int {
        contextSize - overheadTokens - outputReserve
    }
}

public struct RenderedPrompt: Equatable, Sendable {
    public var instructions: String
    /// The posting goes here, never in the instructions: it is untrusted input.
    public var prompt: String
    /// What the model sees, in order. Goldens pin it.
    public var transcript: String { "=== instructions ===\n\(instructions)\n=== prompt ===\n\(prompt)\n" }
}

/// Prompts are files in `Core/Resources/prompts/` (CLAUDE.md rule 8).
public enum PromptRenderer {
    public static func extract(postingText: String) throws -> RenderedPrompt {
        RenderedPrompt(instructions: try resource("extract"), prompt: postingText)
    }

    public static func digest(postingText: String) throws -> RenderedPrompt {
        RenderedPrompt(instructions: try resource("digest"), prompt: postingText)
    }

    public static func star(story: String) throws -> RenderedPrompt {
        RenderedPrompt(instructions: try resource("star"), prompt: story)
    }

    /// `Core/Resources/**/<name>.md`. `.process` flattens the folder: a top-level `Resources/`
    /// directory breaks code signing of the flat iOS resource bundle.
    static func resource(_ name: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "md") else { throw CocoaError(.fileNoSuchFile) }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
