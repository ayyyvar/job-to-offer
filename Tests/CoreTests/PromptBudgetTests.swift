@testable import Core
import Testing

@Suite struct PromptBudgetTests {
    static func words(_ text: String) -> Int { text.split(whereSeparator: \.isWhitespace).count }

    @Test func availableTokensAreContextMinusInstructionsMinusTheOutputReserve() {
        #expect(PromptBudget.outputReserve == 600)
        #expect(PromptBudget.available(contextSize: 4096, overheadTokens: 1500) == 1996)
    }

    @Test func a3000TokenPostingIsTruncatedTo1996TokensAndKeepsItsRequirements() async {
        let paragraph = "This paragraph describes the company and has exactly fifteen words in it for counting purposes."
        let body = Array(repeating: paragraph, count: 200).joined(separator: "\n\n")
        let text = "Senior AI Engineer\n\n\(body)\n\nRequirements\n\n- Python and FastAPI in production for 3+ years"
        #expect(Self.words(text) >= 3000)
        let cut = await Truncator.truncate(text, toTokens: PromptBudget.available(contextSize: 4096, overheadTokens: 1500), count: Self.words)
        #expect(Self.words(cut) <= 1996)
        #expect(cut.contains("- Python and FastAPI in production for 3+ years"))
    }
}
