import Core
import Testing

@Suite struct JobKeyTests {
    struct Case: CustomTestStringConvertible, Sendable {
        let company: String
        let title: String
        let url: String
        let key: String
        var testDescription: String { "\(company) | \(title) | \(url)" }
    }

    // Expected keys come from the original `tools/job_key.py` (Python 3.14, Unicode 16.0),
    // generated on 2026-09-27. Do not edit them by hand.
    static let pythonReference: [Case] = [
        Case(company: "Acme Corp", title: "SOC Analyst (L2)", url: "", key: "acme-corp_soc-analyst-l2"),
        Case(company: "Deloitte", title: "Junior Cybersecurity Analyst (OT/IoT)", url: "", key: "deloitte_junior-cybersecurity-analyst-ot-iot"),
        Case(company: "NeverHack Estonia", title: "Penetration Tester / Red Teamer", url: "", key: "neverhack-estonia_penetration-tester-red-teamer"),
        Case(company: "OPS Consulting, LLC", title: "Malware Analyst", url: "", key: "ops-consulting-llc_malware-analyst"),
        Case(company: "Deloitte", title: "Cyber Intelligence Center Security Analyst at the Global Operations Hub", url: "",
             key: "deloitte_cyber-intelligence-center-security-analyst-at-the-global-ope-8e4a9b"),
        Case(company: "Deloitte", title: "Cyber Intelligence Center Security Analyst at the Global Operations Hub, Remote", url: "",
             key: "deloitte_cyber-intelligence-center-security-analyst-at-the-global-ope-ed7399"),
        Case(company: "Securion", title: "Аналитик информационной безопасности", url: "https://hh.ru/vacancy/123456789", key: "securion_123456789"),
        Case(company: "Securion", title: "Аналитик информационной безопасности", url: "https://example.com/jobs/abc", key: "securion_untitled-799b5c"),
        Case(company: "Securion", title: "", url: "https://example.com/jobs/abc", key: "securion_https-example-com-jobs-abc"),
        Case(company: "Securion", title: "", url: "", key: "securion_untitled-da39a3"),
        Case(company: "", title: "Senior AI Engineer", url: "", key: "unknown-company_senior-ai-engineer"),
        Case(company: "   ", title: "Senior AI Engineer", url: "", key: "unknown-company_senior-ai-engineer"),
        Case(company: "Яндекс", title: "ML Engineer", url: "", key: "company-6d769a_ml-engineer"),
        Case(company: "ΟΔΟΣ", title: "Data Engineer", url: "", key: "company-34c5f6_data-engineer"),
        Case(company: "ßß", title: "Data Engineer", url: "", key: "company-c45558_data-engineer"),
        Case(company: "Société Générale", title: "Ingénieur Données Senior", url: "", key: "societe-generale_ingenieur-donnees-senior"),
        Case(company: "Straße GmbH", title: "ＡＩ Engineer", url: "", key: "strae-gmbh_ai-engineer"),
        Case(company: "ﬁnance Co", title: "Backend Developer — Python/Go", url: "", key: "finance-co_backend-developer-python-go"),
        Case(company: "The International Business Machines Corporation of America Ltd", title: "Engineer", url: "",
             key: "the-international-business-machines-corp-c95c7b_engineer"),
        Case(company: "--Acme--", title: "--Lead--", url: "", key: "acme_lead"),
    ]

    @Test(arguments: pythonReference)
    func makeMatchesThePythonOriginal(_ c: Case) {
        #expect(JobKey.make(company: c.company, title: c.title, url: c.url) == c.key)
    }

    @Test func docstringExampleGivesTheCanonicalKey() {
        #expect(JobKey.make(company: "Acme Corp", title: "SOC Analyst (L2)") == "acme-corp_soc-analyst-l2")
    }

    @Test(arguments: [
        ("Deloitte", "Junior Cybersecurity Analyst (OT/IoT)"),
        ("NeverHack Estonia", "Penetration Tester / Red Teamer"),
        ("OPS Consulting, LLC", "Malware Analyst"),
    ])
    func pathBreakingCharactersNeverReachTheKey(company: String, title: String) {
        let key = JobKey.make(company: company, title: title)
        #expect(!key.contains { "/(),".contains($0) })
        #expect(JobKey.isCanonical(key))
    }

    @Test func longTitlesThatShareTheFirst60CharsGetDifferentKeys() {
        let base = "Cyber Intelligence Center Security Analyst at the Global Operations Hub"
        #expect(JobKey.make(company: "Deloitte", title: base) != JobKey.make(company: "Deloitte", title: base + ", Remote"))
    }

    @Test func theSameLongTitleGetsTheSameKeyTwice() {
        let title = "Cyber Intelligence Center Security Analyst at the Global Operations Hub"
        #expect(JobKey.make(company: "Deloitte", title: title) == JobKey.make(company: "Deloitte", title: title))
    }

    @Test func nonLatinTitleFallsBackToThePortalIdFromTheURL() {
        let key = JobKey.make(company: "Securion", title: "Аналитик SOC-центра", url: "https://hh.ru/vacancy/104857600?from=share")
        // "SOC" is Latin, so this title keeps a slug; a fully Cyrillic one must use the id.
        #expect(key == "securion_soc")
        #expect(JobKey.make(company: "Securion", title: "Аналитик", url: "https://hh.ru/vacancy/104857600?from=share") == "securion_104857600")
    }

    @Test func emptyCompanyBecomesUnknownCompany() {
        #expect(JobKey.make(company: "", title: "SOC Analyst") == "unknown-company_soc-analyst")
    }

    @Test(arguments: [
        ("acme-corp_soc-analyst-l2", true),
        ("a_b", true),
        ("acme_title-", true),
        ("deloitte_junior-cybersecurity-analyst-(ot/iot)", false),
        ("neverhack-estonia_penetration-tester-/-red-teamer", false),
        ("ops-consulting,-llc_malware-analyst", false),
        ("securion_", false),
        ("_title", false),
        ("a_b_c", false),
        ("Acme_title", false),
        ("-acme_title", false),
        ("acme_-title", false),
        ("", false),
        // Deliberate divergence: Python's `$` accepts a trailing "\n"; a folder name must not.
        ("acme_title\n", false),
    ])
    func isCanonicalAcceptsOnlyTheSlugUnderscoreSlugShape(key: String, expected: Bool) {
        #expect(JobKey.isCanonical(key) == expected)
    }
}
