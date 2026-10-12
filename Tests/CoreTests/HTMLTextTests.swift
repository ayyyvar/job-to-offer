import Core
import Testing

@Suite struct HTMLTextTests {
    @Test(arguments: [
        ("&lt;p&gt;Tom &amp; Jerry&lt;/p&gt;", "<p>Tom & Jerry</p>"),
        ("It&#8217;s &#x2014; &quot;ok&quot; &#39;x&#39;", "It\u{2019}s \u{2014} \"ok\" 'x'"),
        ("a&nbsp;b", "a\u{00A0}b"),
        ("&unknown; stays", "&unknown; stays"),
    ])
    func decodeEntitiesHandlesNamedAndNumericEntities(input: String, expected: String) {
        #expect(HTMLText.decodeEntities(input) == expected)
    }

    @Test func plainTextDropsTagsAndKeepsBlocksOnSeparateLines() {
        let html = "<h4>About</h4><p>We build <strong>AI</strong>&nbsp;tools.</p><ul><li>Python</li><li>RAG</li></ul>"
        #expect(HTMLText.plainText(html) == "About\n\nWe build AI tools.\n\n- Python\n- RAG")
    }

    @Test func plainTextDropsScriptAndStyleContent() {
        let html = "<style>p { color: red }</style><p>Keep</p><script>var x = '<p>no</p>';</script>"
        #expect(HTMLText.plainText(html) == "Keep")
    }

    @Test func plainTextCollapsesWhitespace() {
        #expect(HTMLText.plainText("<p>  a \t  b  </p>\n\n\n\n<p>c</p>") == "a b\n\nc")
    }

    @Test func listItemWithANestedParagraphKeepsTheBulletOnTheSameLine() {
        #expect(HTMLText.plainText("<ul><li><p>Python</p></li></ul>") == "- Python")
    }

    @Test func brBecomesANewline() {
        #expect(HTMLText.plainText("line 1<br>line 2<br/>line 3") == "line 1\nline 2\nline 3")
    }

    @Test(arguments: ["head", "template", "nav", "footer"])
    func unrenderedAndChromeElementsAreDropped(tag: String) {
        #expect(HTMLText.plainText("<\(tag) class=\"x\"><p>drop</p></\(tag)><p>Body</p>") == "Body")
    }

    @Test func headerElementIsNotMistakenForHead() {
        #expect(HTMLText.plainText("<header><p>Job title</p></header><p>Body</p>") == "Job title\n\nBody")
    }

    // Real pages fetched once with curl on 2026-09-27 (Step 4). Each sentence sits in the
    // posting's requirements section.
    static let pages = [
        ("HTML/linkedin_2026-09-27.html", "Strong proficiency in Python and experience with FastAPI or similar backend frameworks."),
        ("HTML/northvale_careers_2026-09-27.html", "3+ years of experience as a Senior Software Engineer delivering production-grade AI, Machine Learning, or LLM-based solutions"),
        ("HTML/hh_2026-09-27.html", "Опыт коммерческой разработки на Python (asyncio, FastAPI, Dependency injection);"),
    ]

    @Test(arguments: pages)
    func pageKeepsTheRequirementsParagraph(file: String, sentence: String) throws {
        #expect(HTMLText.plainText(try Fixture.string(file)).contains(sentence))
    }

    @Test(arguments: pages.map(\.0))
    func pageTextHasNoTagsNoScriptContentAndCollapsedWhitespace(file: String) throws {
        let text = HTMLText.plainText(try Fixture.string(file))
        #expect(!text.contains("<"))
        #expect(!text.contains("{\""))
        #expect(!text.contains("window."))
        #expect(!text.contains("  "))
        #expect(!text.contains("\n\n\n"))
    }

    @Test(arguments: pages.map(\.0))
    func pageConvertsInUnderOneSecond(file: String) throws {
        let html = try Fixture.string(file)
        let elapsed = ContinuousClock().measure { _ = HTMLText.plainText(html) }
        #expect(elapsed < .seconds(1))
    }

    @Test func footerLinksDoNotLookLikeARequirementsSection() throws {
        // hh.ru's footer links to "Требования к ПО" (software requirements) on every page.
        #expect(!HTMLText.plainText(try Fixture.string("HTML/hh_2026-09-27.html")).contains("Требования к ПО"))
    }

    @Test func linkedInPostingIsTheDescriptionAndCriteriaWithoutTheSignInForm() throws {
        let text = HTMLText.posting(html: try Fixture.string("HTML/linkedin_2026-09-27.html"),
                                    url: "https://www.linkedin.com/jobs/view/4000000001").plainText
        #expect(!text.contains("Join or sign in"))
        #expect(!text.contains("Password"))
        #expect(text.contains("Kaplo is a remote-first company"))
        #expect(text.contains("Strong proficiency in Python and experience with FastAPI or similar backend frameworks."))
        #expect(text.contains("Employment type\nContract"))
        #expect(text.split(whereSeparator: \.isWhitespace).count < 600)
    }

    @Test func pagePostingUsesTheTitleElementAndLeavesCompanyToTheModel() throws {
        let url = "https://www.linkedin.com/jobs/view/4000000001"
        let posting = HTMLText.posting(html: try Fixture.string("HTML/linkedin_2026-09-27.html"), url: url)
        let title = "Kaplo hiring Senior AI/LLM Engineer (Python) - Remote in Vancouver, British Columbia, Canada | LinkedIn"
        #expect(posting.title == title)
        #expect(posting.company == "")
        #expect(posting.url == url)
        #expect(posting.plainText.hasPrefix(title + "\n\n"))
        #expect(posting.postedAt == nil)
    }
}
