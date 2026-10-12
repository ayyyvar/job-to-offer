@testable import Core
import Testing

/// The on-device model fills fields the posting never states (Step 6 device run on the archived
/// posting: `.sponsors`, `.remote`, `.fullTime`, "not specified"). `grounded(in:)` keeps a claim only
/// when the posting text supports it, so a hallucination cannot become a gate verdict.
@Suite struct GroundingTests {
    static let noVisaText = "Senior AI Engineer\nRequirements\n3+ years of Python.\nStrong English communication skills (B2 level or higher)"

    @Test func visaClaimWithoutAnyVisaWordsBecomesSilent() {
        var p = JobPosting.sample(visaSponsorship: .sponsors, eligibilityQuote: "3+ years of Python.")
        p = p.grounded(in: Self.noVisaText)
        #expect(p.visaSponsorship == .silent)
        #expect(p.eligibilityQuote == "")
    }

    @Test(arguments: [
        (VisaStance.citizenshipOrPRRequired, "Applicants must be U.S. citizens or green card holders."),
        (.clearanceRequired, "An active TS/SCI clearance is required for this role."),
        (.sponsors, "We offer visa sponsorship and relocation support."),
        (.authorizationRequired, "You must be authorized to work in Canada."),
    ])
    func statedVisaClaimIsKeptAndQuotedVerbatimFromTheText(stance: VisaStance, sentence: String) {
        let text = "Senior AI Engineer\n\nAbout us. \(sentence) We ship weekly."
        let p = JobPosting.sample(visaSponsorship: stance, eligibilityQuote: "a paraphrase").grounded(in: text)
        #expect(p.visaSponsorship == stance)
        #expect(p.eligibilityQuote == sentence)
    }

    // Gate injection eval 2026-09-27: after one inserted sentence, 8 of 9 restrictions came back `.silent`
    // ("must be U.S. citizens" went to locationRequirement only). A stated restriction now upgrades the
    // stance and becomes the quote: a wrong FAIL is visible and editable, a wrong PASS is silent.
    @Test(arguments: [
        ("Applicants must be U.S. citizens.", VisaStance.citizenshipOrPRRequired),
        ("Only candidates with permanent residency in Germany will be considered.", .citizenshipOrPRRequired),
        ("This role requires an active Secret security clearance.", .clearanceRequired),
        ("Candidates must already have the right to work in the UK.", .authorizationRequired),
        ("We are unable to sponsor work visas for this position.", .authorizationRequired),
        ("Applicants must be authorized to work in the country in which they apply.", .authorizationRequired),
    ])
    func statedRestrictionUpgradesASilentStance(sentence: String, stance: VisaStance) {
        let text = "Senior AI Engineer\n\nWe ship weekly. \(sentence) Python required."
        let p = JobPosting.sample(visaSponsorship: .silent).grounded(in: text)
        #expect(p.visaSponsorship == stance)
        #expect(p.eligibilityQuote == sentence)
    }

    @Test(arguments: [
        "Qualified applicants will receive consideration regardless of race, national origin or citizenship status.",
        "- Company-sponsored trips to Manila to meet your team",
        "Experience with customs clearance software is a plus.",
        "EU citizens and non-EU citizens are welcome to apply.",
    ])
    func boilerplateAndOtherSensesDoNotUpgrade(sentence: String) {
        let p = JobPosting.sample(visaSponsorship: .silent).grounded(in: "Senior AI Engineer\n\n\(sentence)")
        #expect(p.visaSponsorship == .silent)
    }

    @Test func statedRestrictionNeverDowngradesAStricterStance() {
        let text = "You must be a U.S. citizen. You also need the right to work in the US."
        let p = JobPosting.sample(visaSponsorship: .authorizationRequired).grounded(in: text)
        #expect(p.visaSponsorship == .citizenshipOrPRRequired)
        #expect(JobPosting.sample(visaSponsorship: .clearanceRequired).grounded(in: "You need the right to work in the US.").visaSponsorship == .clearanceRequired)
    }

    @Test func sponsorsClaimOnANegatedSentenceBecomesAuthorizationRequired() {
        let text = "Remote role. We are unable to provide visa sponsorship at this time."
        let p = JobPosting.sample(visaSponsorship: .sponsors).grounded(in: text)
        #expect(p.visaSponsorship == .authorizationRequired)
        #expect(p.eligibilityQuote == "We are unable to provide visa sponsorship at this time.")
    }

    @Test(arguments: [
        (RemotePolicy.remote, "This is a fully remote role.", RemotePolicy.remote),
        (.remote, "Work from anywhere in Europe.", .remote),
        (.remote, Self.noVisaText, .unspecified),
        (.hybrid, "Hybrid: two office days a week.", .hybrid),
        (.hybrid, Self.noVisaText, .unspecified),
        (.onsite, "This role is on-site in Berlin.", .onsite),
        (.onsite, Self.noVisaText, .unspecified),
    ])
    func remotePolicyNeedsAWordForItInTheText(claimed: RemotePolicy, text: String, expected: RemotePolicy) {
        #expect(JobPosting.sample(remotePolicy: claimed).grounded(in: text).remotePolicy == expected)
    }

    @Test func locationRequirementDropsOnlyRemoteAndBlankEntries() {
        // A paraphrased place ("US only" → "United States") must survive: a wrong FLAG is visible,
        // a dropped requirement is a silent PASS.
        let p = JobPosting.sample(locationRequirement: ["Remote", "United States", " "]).grounded(in: "Remote (US only)")
        #expect(p.locationRequirement == ["United States"])
    }

    // Review finding 1: grounding may remove only the permissive claim (`.sponsors`).
    @Test(arguments: [
        (VisaStance.citizenshipOrPRRequired, "Applicants must hold Australian permanent residency."),
        (.clearanceRequired, "Must be SC cleared."),
        (.authorizationRequired, "You must be authorised to work in the UK."),
    ])
    func restrictiveStanceIsKeptAndQuotedWhenTheWordingDiffers(stance: VisaStance, sentence: String) {
        let p = JobPosting.sample(visaSponsorship: stance).grounded(in: "About us. \(sentence) We ship weekly.")
        #expect(p.visaSponsorship == stance)
        #expect(p.eligibilityQuote == sentence)
    }

    @Test func restrictiveStanceWithNoMatchingSentenceIsKeptWithoutAnInventedQuote() {
        let p = JobPosting.sample(visaSponsorship: .clearanceRequired, eligibilityQuote: "Active clearance needed")
            .grounded(in: "Must pass a Department of Defense background investigation.")
        #expect(p.visaSponsorship == .clearanceRequired)
        #expect(p.eligibilityQuote == "")
    }

    @Test func modelQuoteFoundVerbatimInTheTextIsKept() {
        let quote = "Must pass a Department of Defense background investigation."
        let p = JobPosting.sample(visaSponsorship: .clearanceRequired, eligibilityQuote: quote).grounded(in: "Hi. \(quote)")
        #expect(p.eligibilityQuote == quote)
    }

    // swatchwell eval 2026-09-28: "sponsor" alone (events, communities) is not the immigration claim.
    @Test func bareSponsorMentionWithNoImmigrationWordFallsBackToSilent() {
        let text = "- Giving Back: We sponsor multiple events throughout the year to help out our communities."
        let p = JobPosting.sample(visaSponsorship: .sponsors).grounded(in: text)
        #expect(p.visaSponsorship == .silent)
        #expect(p.eligibilityQuote == "")
    }

    @Test func realPostingBareSponsorMentionOfCommunityEventsBecomesSilent() throws {
        let text = String(decoding: try Fixture.load("Eval/GatesReal/10_swatchwell-applied-ai-engineer_2026-09-28.txt"), as: UTF8.self)
        let p = JobPosting.sample(remotePolicy: .hybrid, visaSponsorship: .sponsors).grounded(in: text)
        #expect(p.visaSponsorship == .silent)
        #expect(p.eligibilityQuote == "")
    }

    @Test func sponsorMentionWithWorkVisaWordingIsKept() {
        let text = "We sponsor work visas for international hires."
        let p = JobPosting.sample(visaSponsorship: .sponsors).grounded(in: text)
        #expect(p.visaSponsorship == .sponsors)
        #expect(p.eligibilityQuote == text)
    }

    // arbeitnow job-board menu line: has the immigration word but no offer verb, so it stays .silent.
    @Test func jobBoardMenuLineWithVisaSponsorshipButNoOfferVerbBecomesSilent() {
        let text = "- Jobs with Visa Sponsorship"
        let p = JobPosting.sample(visaSponsorship: .sponsors).grounded(in: text)
        #expect(p.visaSponsorship == .silent)
        #expect(p.eligibilityQuote == "")
    }

    @Test func sponsorshipAvailableWordingIsKept() {
        let text = "Visa sponsorship is available for this role."
        let p = JobPosting.sample(visaSponsorship: .sponsors).grounded(in: text)
        #expect(p.visaSponsorship == .sponsors)
        #expect(p.eligibilityQuote == text)
    }

    @Test func weOfferVisaSponsorshipWordingIsKept() {
        let text = "We offer visa sponsorship and relocation support."
        let p = JobPosting.sample(visaSponsorship: .sponsors).grounded(in: text)
        #expect(p.visaSponsorship == .sponsors)
        #expect(p.eligibilityQuote == text)
    }

    // Review finding 2: every sponsorship sentence is checked for a negation.
    @Test(arguments: [
        "Visa sponsorship is not available for this role.",
        "Relocation is not offered.",
        "We process visas for clients daily. We can't sponsor employees.",
    ])
    func negatedSponsorshipAnywhereBecomesAuthorizationRequired(text: String) {
        #expect(JobPosting.sample(visaSponsorship: .sponsors).grounded(in: text).visaSponsorship == .authorizationRequired)
    }

    @Test(arguments: [
        (EmploymentType.fullTime, "Full-time, permanent.", EmploymentType.fullTime),
        (.fullTime, Self.noVisaText, .unspecified),
        (.contract, "6-month contract, B2B.", .contract),
        (.freelance, "Freelance project, 20 h/week.", .freelance),
        (.partTime, "Part-time, 20 hours.", .partTime),
    ])
    func employmentTypeNeedsAWordForItInTheText(claimed: EmploymentType, text: String, expected: EmploymentType) {
        var p = JobPosting.sample()
        p.employmentType = claimed
        #expect(p.grounded(in: text).employmentType == expected)
    }

    @Test(arguments: ["not specified", "N/A", "Not mentioned", "competitive"])
    func compensationWithoutANumberBecomesEmpty(value: String) {
        var p = JobPosting.sample()
        p.compensation = value
        #expect(p.grounded(in: "any").compensation == "")
    }

    @Test func compensationWithANumberIsKept() {
        var p = JobPosting.sample()
        p.compensation = "65-90 USD per hour"
        #expect(p.grounded(in: "any").compensation == "65-90 USD per hour")
    }

    @Test func programmingLanguagesAreNotRequiredHumanLanguages() {
        // Step 7 greedy eval: the model listed "Python (especially web frameworks like FastAPI)" as a
        // required language, and the language gate failed a Strong Fit posting.
        var p = JobPosting.sample(requiredLanguages: [
            LanguageRequirement(language: "English", level: "B2 level or higher"),
            LanguageRequirement(language: "Python", level: "especially web frameworks like FastAPI"),
            LanguageRequirement(language: "LangGraph", level: ""),
            LanguageRequirement(language: " ", level: "fluent"),
        ])
        p.stack = ["python", "langgraph"]
        #expect(p.grounded(in: "Strong English communication skills required.").requiredLanguages == [LanguageRequirement(language: "English", level: "B2 level or higher")])
    }

    @Test(arguments: ["Go", "SQL", "TypeScript", "C#", "Rust", "Java"])
    func commonProgrammingLanguagesAreDroppedEvenOutsideTheStack(name: String) {
        let p = JobPosting.sample(requiredLanguages: [LanguageRequirement(language: name, level: "")])
        #expect(p.grounded(in: "any").requiredLanguages.isEmpty)
    }

    // Holdout eval 2026-09-27 (bytecastle): "Azure DevOps" came back as a required language, and the
    // language gate failed a Good Fit posting. Any name in the FitRubric skill areas is a tool, not a language.
    @Test(arguments: ["Azure DevOps", "Kubernetes", "Docker Compose", "React Native"])
    func toolNamesFromTheSkillAreasAreNotHumanLanguages(name: String) {
        let p = JobPosting.sample(requiredLanguages: [LanguageRequirement(language: name, level: "CI/CD practices")])
        #expect(p.grounded(in: "any").requiredLanguages.isEmpty)
    }

    @Test(arguments: ["German", "Kazakh", "Mandarin"])
    func humanLanguagesStayEvenWhenUnknownToTheRubric(name: String) {
        let p = JobPosting.sample(requiredLanguages: [LanguageRequirement(language: name, level: "C1")])
        #expect(p.grounded(in: "\(name) required, C1 level.").requiredLanguages.map(\.language) == [name])
    }

    // Eval finding 2026-09-28 (Welcome to the Jungle): page chrome "FrançaisEnglish (US)English (UK)" made the
    // model emit "French" as a required language, causing a false language-gate FAIL. Grounding now requires the
    // emitted language name itself in the text; a requirement stated only in translation is lost, same as the
    // model missing it outright (grounding never upgrades).
    @Test func languageNamedOnlyAsPageChromeTranslationIsDropped() {
        let text = "Senior Engineer\n\nFrançaisEnglish (US)English (UK)\n\nAbout the role."
        let p = JobPosting.sample(requiredLanguages: [
            LanguageRequirement(language: "French", level: "fluent"),
            LanguageRequirement(language: "English", level: ""),
        ]).grounded(in: text)
        #expect(p.requiredLanguages.map(\.language) == ["English"])
    }

    @Test func languageStatedAsAPlusIsKept() {
        let p = JobPosting.sample(requiredLanguages: [LanguageRequirement(language: "German", level: "a plus")])
            .grounded(in: "Senior Engineer\n\nGerman is a plus.")
        #expect(p.requiredLanguages.map(\.language) == ["German"])
    }

    @Test func fluentEnglishRequiredIsKept() {
        let p = JobPosting.sample(requiredLanguages: [LanguageRequirement(language: "English", level: "fluent")])
            .grounded(in: "Senior Engineer\n\nFluent English required.")
        #expect(p.requiredLanguages.map(\.language) == ["English"])
    }

    @Test(arguments: [("not specified", ""), ("2026-10-15", "2026-10-15"), ("15.10.2026", ""), ("ASAP", "")])
    func deadlineMustBeAnISODate(value: String, expected: String) {
        var p = JobPosting.sample()
        p.deadline = value
        #expect(p.grounded(in: "any").deadline == expected)
    }
}
