import Core
import FoundationModels
@testable import JobScout
import Testing

@Suite struct ExtractionTests {
    @Test(.tags(.onDevice)) func realModelExtractsTheArchivedPosting() async throws {
        guard SystemLanguageModel.default.isAvailable else {
            print("skip: on-device model unavailable: \(SystemLanguageModel.default.availability)")
            return
        }
        let text = try Fixture.string("Eval/tbd_senior-ai-engineer_2026-09-25.md")
        let posting = try await FoundationModelsClient().extract(postingText: text)
        print("extracted: \(posting)")
        #expect(posting.title.contains("Senior AI Engineer"))
        #expect(posting.stack.map { $0.lowercased() }.contains("python"))
        // The posting never mentions remote work ("remote" occurs 0 times), so `.unspecified` is the
        // truthful answer. CLAUDE.md Step 6 expected `.remote`; accept both, reject `.onsite`/`.hybrid`.
        #expect([RemotePolicy.remote, .unspecified].contains(posting.remotePolicy))
    }
}
