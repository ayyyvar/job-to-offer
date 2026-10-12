import Core
import Testing

@Suite struct TruncatorTests {
    /// Stand-in for the model tokenizer: one token per word.
    static func words(_ text: String) -> Int { text.split(whereSeparator: \.isWhitespace).count }

    // Holdout eval 2026-09-27 (threadly): the model threw unsupportedLanguageOrLocale on an English page;
    // without the one- to three-word header lines ("Threadly Technologies") it parsed. The client retries with this.
    @Test func shortParagraphsAreDroppedAndLongOnesKeptInOrder() {
        let text = "Senior Python Developer - Threadly Technologies\n\nThreadly Technologies\n\nRemote\n\nWe build software for customers.\n\n- 5+ years of Python\n- PostgreSQL"
        #expect(Truncator.droppingShortParagraphs(text) == "Senior Python Developer - Threadly Technologies\n\nWe build software for customers.\n\n- 5+ years of Python\n- PostgreSQL")
    }

    // Guardrail eval 2026-09-27: the model threw guardrailViolation on "We are unable to sponsor work
    // visas for this position."; without that line it extracted fine. The client retries with this.
    @Test func linesMentioningVisaOrSponsorAreDropped() {
        let text = "Senior Engineer\n\nWe are unable to sponsor work visas for this position.\n\nRemote\n\nSponsorship available for the right candidate.\n\n- 5+ years of Python"
        #expect(Truncator.droppingVisaLines(text) == "Senior Engineer\n\n\nRemote\n\n\n- 5+ years of Python")
    }

    @Test func textWithoutVisaOrSponsorLinesIsUnchanged() {
        let text = "Senior Engineer\n\nRemote\n\n- 5+ years of Python"
        #expect(Truncator.droppingVisaLines(text) == text)
    }

    @Test func textUnderTheBudgetIsUnchanged() async {
        let text = "Title\n\nBody text"
        #expect(await Truncator.truncate(text, toTokens: 100, count: Self.words) == text)
    }

    @Test func requirementsSectionSurvivesACutDeepInALinkedInPage() async throws {
        let text = HTMLText.plainText(try Fixture.string("HTML/linkedin_2026-09-27.html"))
        #expect(Self.words(text) > 1_000)
        let cut = await Truncator.truncate(text, toTokens: 300, count: Self.words)
        #expect(Self.words(cut) <= 300)
        #expect(cut.contains("Core Requirements"))
        #expect(cut.contains("Strong proficiency in Python and experience with FastAPI or similar backend frameworks."))
        #expect(cut.contains("Excellent written and verbal communication skills in English."))
        #expect(cut.hasPrefix(text.components(separatedBy: "\n\n")[0]))
    }

    @Test(arguments: ["Qualifications", "What you'll need", "What You’ll Need:"])
    func otherRequirementsHeadingsArePreferredToo(heading: String) async {
        let filler = Array(repeating: "Company history paragraph with many words in it.", count: 20).joined(separator: "\n\n")
        let text = "Title\n\n\(filler)\n\n\(heading)\n\n- Python\n- SQL\n\nBenefits\n\n- Snacks"
        let cut = await Truncator.truncate(text, toTokens: 30, count: Self.words)
        #expect(Self.words(cut) <= 30)
        #expect(cut.contains("\(heading)\n\n- Python\n- SQL"))
        #expect(!cut.contains("Snacks"))
    }

    @Test func requirementsWrittenOnePerParagraphSurvive() async {
        // Greenhouse <p>-per-requirement markup (review finding 10).
        let filler = Array(repeating: "Company history paragraph with many words in it.", count: 20).joined(separator: "\n\n")
        let text = "Title\n\n\(filler)\n\nRequirements\n\n5+ years of Python\n\nExperience with RAG pipelines in production\n\nBenefits\n\nSnacks"
        let cut = await Truncator.truncate(text, toTokens: 30, count: Self.words)
        #expect(cut.contains("5+ years of Python"))
        #expect(cut.contains("Experience with RAG pipelines in production"))
        #expect(!cut.contains("Snacks"))
    }

    @Test func keptParagraphsStayInDocumentOrder() async {
        let text = "Title\n\nIntro one two\n\nRequirements\n\n- Python\n\nBenefits\n\nLong tail " + String(repeating: "x ", count: 50)
        #expect(await Truncator.truncate(text, toTokens: 7, count: Self.words) == "Title\n\nIntro one two\n\nRequirements\n\n- Python")
    }

    @Test func requirementsSectionLargerThanTheBudgetIsCutByLines() async {
        let items = (1...100).map { "- skill \($0)" }.joined(separator: "\n")
        let text = "Title\n\nRequirements\n\n\(items)"
        let cut = await Truncator.truncate(text, toTokens: 20, count: Self.words)
        #expect(Self.words(cut) <= 20)
        #expect(cut.hasPrefix("Title\n\nRequirements\n\n- skill 1\n"))
    }

    @Test func withoutARequirementsHeadingTheStartIsKept() async {
        let text = (1...50).map { "Paragraph \($0) text" }.joined(separator: "\n\n")
        let cut = await Truncator.truncate(text, toTokens: 9, count: Self.words)
        #expect(cut == "Paragraph 1 text\n\nParagraph 2 text\n\nParagraph 3 text")
    }
}
