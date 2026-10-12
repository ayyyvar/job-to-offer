import Observation

/// Last prompt's token budget, for the Settings screen (Step 10).
@MainActor @Observable
final class BudgetTelemetry {
    static let shared = BudgetTelemetry()

    private(set) var promptTokens: Int?
    private(set) var contextSize: Int?
    private(set) var truncated = false

    func record(promptTokens: Int, contextSize: Int, truncated: Bool) {
        self.promptTokens = promptTokens
        self.contextSize = contextSize
        self.truncated = truncated
    }
}
