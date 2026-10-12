/// The model behind a protocol: `FoundationModelsClient` (app target) and `FakeLLMClient` (tests).
/// `tokenCount` is async throws because `SystemLanguageModel.tokenCount(for:)` is (CLAUDE.md §4 shows it sync).
public protocol LLMClient: Sendable {
    var contextSize: Int { get }
    func tokenCount(_ text: String) async throws -> Int
    func extract(postingText: String) async throws -> JobPosting
    /// The posting only, no candidate: `FitRubric` turns it into scores.
    func digest(postingText: String) async throws -> PostingDigest
    /// A spoken work story as a STAR answer, plus what it lacks.
    func star(story: String) async throws -> StarStory
}

public enum LLMError: Error, Equatable, Sendable {
    /// A user-readable reason.
    case failed(String)
}

/// Returns fixed fixtures, so Core tests run on a Mac without Apple Intelligence.
public struct FakeLLMClient: LLMClient {
    public var posting: JobPosting
    public var digest: PostingDigest
    public var error: LLMError?
    public var star = StarStory(situation: "", task: "", action: "", result: "", missing: [])
    public var contextSize = 4096

    public init(posting: JobPosting, digest: PostingDigest) {
        self.posting = posting
        self.digest = digest
    }

    /// One token per word.
    public func tokenCount(_ text: String) async throws -> Int { text.split(whereSeparator: \.isWhitespace).count }

    public func extract(postingText: String) async throws -> JobPosting {
        if let error { throw error }
        return posting
    }

    public func digest(postingText: String) async throws -> PostingDigest {
        if let error { throw error }
        return digest
    }

    public func star(story: String) async throws -> StarStory {
        if let error { throw error }
        return star
    }
}
