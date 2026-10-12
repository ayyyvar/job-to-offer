@testable import Core
import Testing

@Suite struct SkillTiersTests {
    @Test func occurrenceCountPicksTheTier() {
        let resume = "Built services in Python. Used Python for everything. Python is my main language. Also did some React work once."
        let tiers = SkillTiers.derived(from: resume, catalog: ["python", "react", "kubernetes"])
        #expect(tiers.strong == ["python"])
        #expect(tiers.moderate == ["react"])
        #expect(tiers.weak == ["kubernetes"])
    }
}
