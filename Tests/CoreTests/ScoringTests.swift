@testable import Core
import Testing

@Suite struct ScoringTests {
    @Test func weightedOverallRoundsHalfUp() {
        // 0.30·80 + 0.25·70 + 0.15·60 + 0.30·80 = 74.5 → 75 (rank_state.py: int(total + 0.5)).
        #expect(Scoring.overall(technical: 80, experience: 70, behavioral: 60, career: 80) == 75)
    }

    @Test(arguments: [
        ([0, 0, 0, 0], 0), ([100, 100, 100, 100], 100), ([1, 1, 1, 1], 1),
        ([0, 2, 0, 0], 1), // 0.5 → 1
        ([0, 0, 3, 0], 0), // 0.45 → 0
        ([0, 0, 4, 0], 1), // 0.6 → 1
    ])
    func roundingIsHalfUpInExactArithmetic(scores: [Int], expected: Int) {
        #expect(Scoring.overall(technical: scores[0], experience: scores[1], behavioral: scores[2], career: scores[3]) == expected)
    }

    @Test(arguments: [
        (100, Band.strong), (75, .strong), (74, .good), (60, .good), (59, .moderate),
        (45, .moderate), (44, .weak), (30, .weak), (29, .poor), (0, .poor),
    ])
    func bandBoundariesFollowRankMd(score: Int, band: Band) {
        #expect(Band(for: score) == band)
    }

    static let scores = DimensionScores(technical: 80, experience: 70, behavioral: 60, career: 80,
                                        strengths: ["Python"], gaps: ["No team lead"])
    static func gates(_ eligibility: Verdict = .pass, language: Verdict = .pass, location: Verdict = .pass) -> GateReport {
        GateReport(eligibility: GateResult(verdict: eligibility, note: eligibility == .pass ? nil : "e"),
                   language: GateResult(verdict: language, note: language == .pass ? nil : "l"),
                   location: GateResult(verdict: location, note: location == .pass ? nil : "loc"))
    }

    @Test func passingGatesGiveTheBandOfTheOverall() {
        let fit = Scoring.evaluate(scores: Self.scores, gates: Self.gates())
        #expect(fit.overall == 75)
        #expect(fit.band == .strong)
    }

    @Test(arguments: [(Verdict.fail, Verdict.pass, Verdict.pass), (.pass, .fail, .pass), (.pass, .pass, .fail)])
    func anyGateFailForcesPoorAndKeepsTheScores(e: Verdict, l: Verdict, loc: Verdict) {
        let fit = Scoring.evaluate(scores: Self.scores, gates: Self.gates(e, language: l, location: loc))
        #expect(fit.band == .poor)
        #expect(fit.overall == 75)
        #expect(fit.scores == Self.scores)
    }

    @Test func flagDoesNotChangeTheBandButKeepsTheNote() {
        let fit = Scoring.evaluate(scores: Self.scores, gates: Self.gates(.flag, language: .flag, location: .flag))
        #expect(fit.band == .strong)
        #expect(fit.eligibility == .flag)
        #expect(fit.eligibilityNote == "e")
        #expect(fit.languageNote == "l")
        #expect(fit.locationNote == "loc")
    }
}
