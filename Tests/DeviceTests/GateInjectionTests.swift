import Core
import FoundationModels
@testable import job_to_offer
import Testing

/// Metamorphic eval (docs/EVALS.md #10): insert one sentence after the first paragraph of a real posting
/// and expect its gate verdict. No labels needed. The first run (2026-09-27) missed 8 of 9 eligibility
/// sentences; `Grounding.statedRestriction` was written from these sentences, so this is a regression
/// guard, not a quality score. The 35 eval postings are its check for false FAILs.
/// Location cases run on the tbd base only: it states no remote policy, so the injected sentence is the
/// only signal. The sandboxly base's own text ("remote, globally distributed") conflicted with injected
/// location sentences and made the verdict ambiguous.
@Suite struct GateInjectionTests {
    static let cases: [(sentence: String, gate: String, expected: Verdict)] = [
        ("Applicants must be U.S. citizens.", "eligibility", .fail),
        ("Only candidates with permanent residency in Germany will be considered.", "eligibility", .fail),
        ("This role requires an active Secret security clearance.", "eligibility", .fail),
        ("We are unable to sponsor work visas for this position.", "eligibility", .flag),
        ("Candidates must already have the right to work in the UK.", "eligibility", .flag),
        ("Fluent German (C1 or higher) is required for this role.", "language", .fail),
        ("Native-level English is required.", "language", .flag),
        ("This is a hybrid role with 3 days per week in our Berlin office.", "location", .flag),
        ("This is a fully remote role; you can work from anywhere in the world.", "location", .pass),
        ("Remote, but you must be based in the United States.", "location", .flag),
    ]

    @Test(.tags(.onDevice), .timeLimit(.minutes(30))) func insertedSentencesReachTheGates() async throws {
        guard SystemLanguageModel.default.isAvailable else {
            print("skip: on-device model unavailable: \(SystemLanguageModel.default.availability)")
            return
        }
        var rows = ["| Base | Sentence | Gate | Expected | Got |", "|---|---|---|---|---|"], hits = 0
        let tbdBase = "Eval/tbd_senior-ai-engineer_2026-09-25.md"
        let bases = [tbdBase, "Eval/sandboxly_senior-applied-ai-engineer_2026-09-27.txt"]
        var total = 0
        for base in bases {
            let paragraphs = try Fixture.string(base).components(separatedBy: "\n\n")
            for c in Self.cases where c.gate != "location" || base == tbdBase {
                total += 1
                // After the first paragraph: the Truncator always keeps it, so the sentence reaches the model.
                let text = ([paragraphs[0], c.sentence] + paragraphs.dropFirst()).joined(separator: "\n\n")
                var got = "error"
                do {
                    let report = Gates.run(try await FoundationModelsClient().extract(postingText: text).grounded(in: text),
                                            profile: CandidateProfile.fixture)
                    let verdict = [("eligibility", report.eligibility), ("language", report.language), ("location", report.location)]
                        .first { $0.0 == c.gate }!.1.verdict
                    got = verdict.rawValue
                    if verdict == c.expected { hits += 1 }
                } catch {
                    got = "error: \(error)"
                }
                rows.append("| \(base.split(separator: "/").last!.prefix(20)) | \(c.sentence) | \(c.gate) | \(c.expected.rawValue) | \(got) |")
            }
        }
        rows.append("Hits: \(hits) of \(total)")
        print("GATE INJECTION TABLE\n" + rows.joined(separator: "\n") + "\nEND GATE INJECTION TABLE")
        #expect(hits >= 16)
    }
}
