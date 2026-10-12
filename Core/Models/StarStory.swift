import FoundationModels // only for the macros

/// A work story in STAR form (prompts/star.md). `missing` lists what an interviewer would still ask for.
@Generable
public struct StarStory: Codable, Equatable, Sendable {
    public var situation: String
    public var task: String
    public var action: String
    public var result: String
    @Guide(description: "What the story lacks; empty if nothing", .count(0...4)) public var missing: [String]

    public init(situation: String, task: String, action: String, result: String, missing: [String]) {
        self.situation = situation
        self.task = task
        self.action = action
        self.result = result
        self.missing = missing
    }
}
