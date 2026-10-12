import FoundationModels // only for the macros

public enum Verdict: String, Codable, Sendable { case pass = "PASS", fail = "FAIL", flag = "FLAG" }

public enum Band: String, Codable, CaseIterable, Sendable {
    case strong = "Strong Fit", good = "Good Fit", moderate = "Moderate Fit", weak = "Weak Fit", poor = "Poor Fit"
}

/// What the model scores. The overall score and the band come from `Scoring`, never from the model.
@Generable
public struct DimensionScores: Codable, Equatable, Sendable {
    @Guide(description: "0-100 per the rubric", .range(0...100)) public var technical: Int
    @Guide(description: "0-100", .range(0...100)) public var experience: Int
    @Guide(description: "0-100", .range(0...100)) public var behavioral: Int
    @Guide(description: "0-100", .range(0...100)) public var career: Int
    @Guide(description: "1-3 bullets grounded in the posting text", .count(1...3)) public var strengths: [String]
    @Guide(description: "1-3 honest bullets", .count(1...3)) public var gaps: [String]
}

public struct FitEvaluation: Codable, Equatable, Sendable {
    public var scores: DimensionScores
    public var overall: Int // computed by Scoring, never by the model
    public var band: Band
    public var eligibility: Verdict; public var eligibilityNote: String?
    public var languageGate: Verdict; public var languageNote: String?
    public var locationVerdict: Verdict; public var locationNote: String?
}
