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
        // The on-device model has no Russian: say so instead of surfacing its locale error.
        guard !Self.isMostlyCyrillic(text) else { return set(.failed(Self.unsupportedLanguage)) }
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

    static let unsupportedLanguage = "This posting is in Russian. job-to-offer reads English postings only for now."

    static func isMostlyCyrillic(_ text: String) -> Bool {
        var cyrillic = 0, latin = 0
        for scalar in text.unicodeScalars where scalar.properties.isAlphabetic {
            if (0x0400...0x04FF).contains(scalar.value) { cyrillic += 1 } else if scalar.isASCII { latin += 1 }
        }
        return cyrillic > latin
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
