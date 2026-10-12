import FoundationModels // only for the macros

/// What the posting asks for, with no candidate in view. The model describes; `FitRubric` matches the
/// description to the candidate. Field order is the measured one: listing the requirements before the
/// classifications pushed roleFocus toward llmApplications and lowered the eval (docs/MODEL_BEHAVIOR.md §7).
@Generable
public struct PostingDigest: Codable, Equatable, Sendable {
    @Guide(description: "1-2 sentences: what the person does day to day") public var summary: String
    public var roleFocus: RoleFocus
    public var llmWork: LLMWork
    @Guide(description: "Required skills and experience, short", .count(1...8)) public var mustHave: [String]
    @Guide(description: "Optional skills; empty if none", .count(0...5)) public var niceToHave: [String]
    @Guide(description: "Signals about team, process and culture; empty if none", .count(0...3)) public var workStyle: [String]
}

@Generable public enum RoleFocus: String, Codable, CaseIterable, Sendable {
    case llmApplications, backend, fullStack, mlModeling, dataEngineering, aiTrainingData, consulting, management, other
}

@Generable public enum LLMWork: String, Codable, CaseIterable, Sendable { case core, part, none }
