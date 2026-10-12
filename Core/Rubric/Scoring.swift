/// Weights and bands from rank.md / 04-job-evaluation.md. Location is a gate, not a weight.
public enum Scoring {
    /// Technical 30 %, Experience 25 %, Behavioral 15 %, Career 30 %; round half up like
    /// `rank_state.py` (`int(total + 0.5)`), in integer hundredths so 74.5 is exact.
    public static func overall(technical: Int, experience: Int, behavioral: Int, career: Int) -> Int {
        (30 * technical + 25 * experience + 15 * behavioral + 30 * career + 50) / 100
    }

    /// A gate FAIL is a veto: the band becomes Poor Fit, the scores stay.
    public static func evaluate(scores: DimensionScores, gates: GateReport) -> FitEvaluation {
        let overall = overall(technical: scores.technical, experience: scores.experience,
                              behavioral: scores.behavioral, career: scores.career)
        return FitEvaluation(scores: scores, overall: overall, band: gates.anyFail ? .poor : Band(for: overall),
                             eligibility: gates.eligibility.verdict, eligibilityNote: gates.eligibility.note,
                             languageGate: gates.language.verdict, languageNote: gates.language.note,
                             locationVerdict: gates.location.verdict, locationNote: gates.location.note)
    }
}

extension Band {
    /// Strong ≥ 75, Good 60–74, Moderate 45–59, Weak 30–44, Poor < 30.
    public init(for score: Int) {
        self = switch score {
        case 75...: .strong
        case 60..<75: .good
        case 45..<60: .moderate
        case 30..<45: .weak
        default: .poor
        }
    }
}
