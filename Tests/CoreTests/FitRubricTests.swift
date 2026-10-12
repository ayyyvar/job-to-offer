@testable import Core
import Testing

/// The model describes the posting (`PostingDigest`); Swift matches it to the candidate. Asked to rate
/// fit itself, the on-device model gave nearly every posting "good" or better (docs/MODEL_BEHAVIOR.md §7).
@Suite struct FitRubricTests {
    static func digest(_ focus: RoleFocus = .llmApplications, _ llm: LLMWork = .core, mustHave: [String] = ["Python"]) -> PostingDigest {
        PostingDigest(summary: "Builds things.", roleFocus: focus, llmWork: llm, mustHave: mustHave, niceToHave: [], workStyle: [])
    }

    @Test(arguments: [
        ("Strong proficiency in Python (especially FastAPI)", FitRubric.Skill.strong),
        ("PostgreSQL/SQLModel/Alembic", .strong),
        ("Familiarity with LLM APIs (OpenAI, Anthropic)", .strong),
        ("TypeScript and React 19", .moderate),
        ("Experience with Kubernetes, preferably AWS EKS", .weak),
        ("Fine-tuning LLMs with LoRA", .weak), // a weak area wins over a strong word in the same requirement
        ("Deploying AI at scale and managing cloud costs", .unknown), // "managing" alone is not people management
        ("3+ years building credit risk models", .unknown),
    ])
    func requirementIsMatchedToTheRubricSkillAreas(requirement: String, skill: FitRubric.Skill) {
        #expect(FitRubric.skill(of: requirement, in: CandidateProfile.fixture.skills) == skill)
    }

    @Test(arguments: ["Excellent written and verbal English", "Bachelor's degree in Computer Science", "Strong problem-solving mindset"])
    func softRequirementIsIgnored(requirement: String) {
        #expect(FitRubric.skill(of: requirement, in: CandidateProfile.fixture.skills) == nil)
    }

    @Test func termsMatchWholeWordsOnly() {
        #expect(FitRubric.skill(of: "Django", in: CandidateProfile.fixture.skills) == .moderate)
        #expect(FitRubric.skill(of: "Cargo logistics", in: CandidateProfile.fixture.skills) == .unknown) // "go" is a word, not a substring
    }

    @Test(arguments: [
        (["Python", "FastAPI"], 95), // all strong: 20 + 75
        (["React", "AWS"], 69), // all moderate: 20 + 75 · 0.65 = 68.75
        (["Kubernetes", "Kafka"], 39), // all weak: 20 + 75 · 0.25 = 38.75
        (["Python", "Kubernetes"], 67), // 20 + 75 · 0.625 = 66.875
        (["Credit scorecards"], 58), // unknown counts as half: 20 + 37.5
        (["Clear communication"], 60), // nothing to match: neutral
    ])
    func technicalIsTheMeanSkillMatch(mustHave: [String], technical: Int) {
        #expect(FitRubric.scores(digest: Self.digest(mustHave: mustHave), stack: [], skills: CandidateProfile.fixture.skills).technical == technical)
    }

    @Test func extractedStackCountsTowardTechnical() {
        #expect(FitRubric.scores(digest: Self.digest(mustHave: ["Clear communication"]), stack: ["kubernetes"], skills: CandidateProfile.fixture.skills).technical == 39)
    }

    @Test(arguments: [
        (RoleFocus.llmApplications, LLMWork.core, 85, 85),
        (.backend, .none, 70, 45),
        (.backend, .core, 75, 85), // LLM work as the core of a backend job counts as LLM experience
        (.fullStack, .part, 65, 65),
        (.mlModeling, .none, 55, 45),
        (.mlModeling, .core, 60, 50), // modelling caps career: it does not build toward applied-LLM work
        (.dataEngineering, .none, 35, 35),
        (.aiTrainingData, .part, 40, 40),
        (.management, .none, 30, 30),
    ])
    func experienceAndCareerFollowTheRoleAndItsLLMWork(focus: RoleFocus, llm: LLMWork, experience: Int, career: Int) {
        let s = FitRubric.scores(digest: Self.digest(focus, llm), stack: [], skills: CandidateProfile.fixture.skills)
        #expect(s.experience == experience)
        #expect(s.career == career)
    }

    @Test func behavioralIsNeutralExceptForClientFacingAndManagementRoles() {
        #expect(FitRubric.scores(digest: Self.digest(.backend), stack: [], skills: CandidateProfile.fixture.skills).behavioral == 65)
        #expect(FitRubric.scores(digest: Self.digest(.consulting), stack: [], skills: CandidateProfile.fixture.skills).behavioral == 55)
        #expect(FitRubric.scores(digest: Self.digest(.management), stack: [], skills: CandidateProfile.fixture.skills).behavioral == 50)
    }

    @Test func bulletsNameThePostingsOwnWords() {
        let s = FitRubric.scores(digest: Self.digest(.backend, .none, mustHave: ["Python and FastAPI", "Kubernetes", "Credit scorecards"]), stack: [], skills: CandidateProfile.fixture.skills)
        #expect(s.strengths == ["Asks for primary skills: python, fastapi"])
        #expect(s.gaps == ["Asks for weak areas: kubernetes", "Not in the profile: Credit scorecards", "No LLM work named"])
    }

    @Test func bulletsAreAtMostThreeAndEmptyWhenNothingMatches() {
        let none = FitRubric.scores(digest: Self.digest(.other, .part, mustHave: ["Clear communication"]), stack: [], skills: CandidateProfile.fixture.skills)
        #expect(none.strengths.isEmpty)
        #expect(none.gaps.isEmpty)
        let many = FitRubric.scores(digest: Self.digest(mustHave: ["Python", "React", "Kubernetes", "Scorecards", "Kafka"]), stack: [], skills: CandidateProfile.fixture.skills)
        #expect(many.strengths.count <= 3)
        #expect(many.gaps.count <= 3)
    }
}
