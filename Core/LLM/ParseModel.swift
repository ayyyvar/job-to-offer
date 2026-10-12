import Observation

public struct Evaluation: Equatable, Sendable {
    public var fetched: FetchedPosting?
    public var posting: JobPosting
    public var scores: DimensionScores
    public var fit: FitEvaluation
    public var profile: CandidateProfile

    /// After the user edits extracted fields. Gates re-run; the scores stay (the user may have edited them).
    public mutating func recompute() { fit = Scoring.evaluate(scores: scores, gates: Gates.run(posting, profile: profile)) }
}

/// The parse pipeline: fetch → extract → gates → digest → FitRubric scores → band, with an observable state.
@MainActor @Observable
public final class ParseModel {
    public enum State: Equatable, Sendable {
        case idle, fetching, extracting, scoring, done(Evaluation), failed(String)
    }

    public private(set) var state: State = .idle
    @ObservationIgnored var onStateChange: ((State) -> Void)? // test hook
    @ObservationIgnored let client: any LLMClient
    @ObservationIgnored let profile: CandidateProfile
    @ObservationIgnored let fetch: @Sendable (String) async throws -> FetchedPosting

    public init(client: any LLMClient, profile: CandidateProfile,
                fetch: @escaping @Sendable (String) async throws -> FetchedPosting = PostingFetcher.fetch) {
        self.client = client
        self.profile = profile
        self.fetch = fetch
    }

    public func run(url: String) async {
        set(.fetching)
        do {
            let fetched = try await fetch(url)
            await evaluate(fetched.plainText, fetched: fetched)
        } catch {
            set(.failed(Self.reason(error)))
        }
    }

    public func run(text: String) async { await evaluate(text, fetched: nil) }

    private func evaluate(_ text: String, fetched: FetchedPosting?) async {
        do {
            set(.extracting)
            let posting = try await client.extract(postingText: text).grounded(in: text)
            set(.scoring)
            let scores = FitRubric.scores(digest: try await client.digest(postingText: text), stack: posting.stack, skills: profile.skills)
            set(.done(Evaluation(fetched: fetched, posting: posting, scores: scores,
                                 fit: Scoring.evaluate(scores: scores, gates: Gates.run(posting, profile: profile)), profile: profile)))
        } catch {
            set(.failed(Self.reason(error)))
        }
    }

    private func set(_ state: State) {
        self.state = state
        onStateChange?(state)
    }

    static func reason(_ error: any Error) -> String {
        switch error {
        case LLMError.failed(let reason): reason
        case FetchError.http(let status, let url): "Fetch failed: HTTP \(status) for \(url.absoluteString)"
        case FetchError.jobNotFound(let id): "The job \(id) is no longer on the board."
        case FetchError.badURL(let url): "Not a web link: \(url)"
        case FetchError.notText(let url): "The link is not a web page (PDF or image?): \(url). Paste the posting text instead."
        default: error.localizedDescription
        }
    }
}
