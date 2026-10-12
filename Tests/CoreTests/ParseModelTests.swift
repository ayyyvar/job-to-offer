@testable import Core
import Foundation
import Testing

@MainActor
@Suite struct ParseModelTests {
    static func fake(_ edit: (inout JobPosting) -> Void = { _ in }) throws -> FakeLLMClient {
        var posting = try JSONDecoder().decode(JobPosting.self, from: Fixture.load("LLM/tbd_posting.json"))
        edit(&posting)
        let digest = try JSONDecoder().decode(PostingDigest.self, from: Fixture.load("LLM/tbd_digest.json"))
        return FakeLLMClient(posting: posting, digest: digest)
    }

    nonisolated static let fetched = FetchedPosting(title: "Senior AI Engineer", company: "acme", url: "https://jobs.lever.co/acme/1",
                                        plainText: "Senior AI Engineer\n\nRequirements\n\n- Python", postedAt: nil)

    static func evaluation(_ model: ParseModel) throws -> Evaluation {
        guard case .done(let evaluation) = model.state else { Issue.record("state is \(model.state)"); throw CancellationError() }
        return evaluation
    }

    @Test func extractedFieldsReachTheGates() async throws {
        let quote = "Candidates must hold an active Secret clearance."
        let model = ParseModel(client: try Self.fake { $0.visaSponsorship = .clearanceRequired; $0.eligibilityQuote = quote }, profile: .fixture)
        await model.run(text: "Senior AI Engineer. \(quote) Python required.")
        let fit = try Self.evaluation(model).fit
        #expect(fit.eligibility == .fail)
        #expect(fit.eligibilityNote?.contains(quote) == true)
        #expect(fit.band == .poor)
    }

    @Test func passingPostingGetsTheBandOfTheRubricScore() async throws {
        // tbd_digest.json + the 10-item stack of tbd_posting.json: 11 strong, 3 unknown of 14 → technical
        // 20 + 75 · 12/14 = 84; llmApplications/core → experience 85, career 85; behavioral 65.
        // 0.30·84 + 0.25·85 + 0.15·65 + 0.30·85 = 82.
        let model = ParseModel(client: try Self.fake(), profile: .fixture)
        await model.run(text: "any posting text")
        let evaluation = try Self.evaluation(model)
        let s = evaluation.scores
        #expect([s.technical, s.experience, s.behavioral, s.career] == [84, 85, 65, 85] as [Int])
        #expect(evaluation.fit.overall == 82)
        #expect(evaluation.fit.band == .strong)
    }

    @Test func urlRunGoesIdleFetchingExtractingScoringDone() async throws {
        let recorder = StateRecorder()
        let model = ParseModel(client: try Self.fake(), profile: .fixture, fetch: { _ in Self.fetched })
        model.onStateChange = { recorder.states.append($0) }
        #expect(model.state == .idle)
        await model.run(url: "https://jobs.lever.co/acme/1")
        #expect(recorder.states.dropLast() == [.fetching, .extracting, .scoring])
        #expect(recorder.states.count == 4)
        #expect(try Self.evaluation(model).fetched == Self.fetched)
    }

    @Test func textRunSkipsFetching() async throws {
        let recorder = StateRecorder()
        let model = ParseModel(client: try Self.fake(), profile: .fixture)
        model.onStateChange = { recorder.states.append($0) }
        await model.run(text: "Senior AI Engineer")
        #expect(recorder.states.dropLast() == [.extracting, .scoring])
        #expect(recorder.states.count == 3)
    }

    @Test func fetchErrorEndsInFailedWithAReason() async throws {
        let model = ParseModel(client: try Self.fake(), profile: .fixture, fetch: { url in throw FetchError.http(status: 404, url: URL(string: url)!) })
        await model.run(url: "https://jobs.lever.co/acme/1")
        guard case .failed(let reason) = model.state else { Issue.record("state is \(model.state)"); return }
        #expect(reason.contains("404"))
    }

    @Test func modelErrorEndsInFailedWithTheModelReason() async throws {
        var client = try Self.fake()
        client.error = .failed("The on-device model is not available.")
        let model = ParseModel(client: client, profile: .fixture)
        await model.run(text: "any")
        #expect(model.state == .failed("The on-device model is not available."))
    }

    @Test func editingExtractedFieldsRecomputesTheGatesAndKeepsTheScores() async throws {
        let model = ParseModel(client: try Self.fake(), profile: .fixture)
        await model.run(text: "any")
        var evaluation = try Self.evaluation(model)
        evaluation.posting.visaSponsorship = .citizenshipOrPRRequired
        evaluation.recompute()
        #expect(evaluation.fit.eligibility == .fail)
        #expect(evaluation.fit.band == .poor)
        #expect(evaluation.fit.overall == 82)
    }
}

@MainActor final class StateRecorder { var states: [ParseModel.State] = [] }
