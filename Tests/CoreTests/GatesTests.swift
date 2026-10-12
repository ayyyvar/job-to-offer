@testable import Core
import Testing

extension JobPosting {
    /// A remote, English-only posting that passes every gate; tests change one field at a time.
    static func sample(
        location: String = "Remote",
        remotePolicy: RemotePolicy = .remote,
        locationRequirement: [String] = [],
        visaSponsorship: VisaStance = .silent,
        eligibilityQuote: String = "",
        requiredLanguages: [LanguageRequirement] = []
    ) -> JobPosting {
        JobPosting(title: "Senior AI Engineer", company: "Acme", location: location, remotePolicy: remotePolicy,
                   employmentType: .fullTime, locationRequirement: locationRequirement, visaSponsorship: visaSponsorship,
                   eligibilityQuote: eligibilityQuote, requiredLanguages: requiredLanguages, stack: ["python"],
                   minYearsExperience: 5, compensation: "", deadline: "")
    }
}

@Suite struct GatesTests {
    // Eligibility Gate table, 04-job-evaluation.md.
    @Test(arguments: [
        (VisaStance.citizenshipOrPRRequired, Verdict.fail),
        (.clearanceRequired, .fail),
        (.sponsors, .pass),
        (.silent, .pass),
        (.authorizationRequired, .flag),
    ])
    func eligibilityVerdictFollowsTheVisaStance(stance: VisaStance, expected: Verdict) {
        #expect(Gates.eligibility(.sample(visaSponsorship: stance)).verdict == expected)
    }

    @Test(arguments: [VisaStance.citizenshipOrPRRequired, .clearanceRequired])
    func eligibilityFailQuotesThePostingWording(stance: VisaStance) {
        let quote = "Candidates must be U.S. citizens and able to obtain a Secret clearance."
        let result = Gates.eligibility(.sample(visaSponsorship: stance, eligibilityQuote: quote))
        #expect(result.verdict == .fail)
        #expect(result.note?.contains("\"\(quote)\"") == true)
    }

    @Test func silentEligibilityPassesButIsMarkedUnverified() {
        #expect(Gates.eligibility(.sample(visaSponsorship: .silent)).note?.contains("unverified") == true)
    }

    // Language Gate table, 04-job-evaluation.md; the candidate lists English (fluent), Russian and Tatar (native).
    static let languageCases: [([(String, String)], Verdict)] = [
        ([("Polish", "fluent")], .fail),
        ([("German", "")], .fail),
        ([("English", "native")], .flag),
        ([("English", "C2")], .flag),
        ([("English", "native speaker")], .flag),
        ([("English", "fluent")], .pass),
        ([("English", "professional working proficiency")], .pass),
        ([("English", "")], .pass),
        ([("English", "B2")], .pass),
        ([("Russian", "native")], .pass),
        ([("Tatar", "")], .pass),
        ([], .pass),
        ([("English", "native"), ("Polish", "fluent")], .fail),
        // Review findings 5 and 9: blank rows, optional languages, "non-native welcome".
        ([("", "")], .pass),
        ([("German", "a plus")], .flag),
        ([("Polish", "nice to have")], .flag),
        ([("English", "non-native speakers welcome")], .pass),
    ]

    @Test(arguments: languageCases)
    func languageVerdictFollowsTheCandidateLanguages(required: [(String, String)], expected: Verdict) {
        let posting = JobPosting.sample(requiredLanguages: required.map { LanguageRequirement(language: $0.0, level: $0.1) })
        #expect(Gates.language(posting, profile: .fixture).verdict == expected)
    }

    @Test func languageFailQuotesTheRequirement() {
        let result = Gates.language(.sample(requiredLanguages: [LanguageRequirement(language: "Polish", level: "fluent")]), profile: .fixture)
        #expect(result.note?.contains("Polish (fluent)") == true)
    }

    @Test func languageFlagNamesTheDeclaredLevel() {
        let result = Gates.language(.sample(requiredLanguages: [LanguageRequirement(language: "English", level: "native")]), profile: .fixture)
        #expect(result.note?.contains("English (native)") == true)
        #expect(result.note?.contains("fluent") == true)
    }

    // Location rules, 04-job-evaluation.md "Location & Logistics" and CLAUDE.md §2.
    static let locationCases: [(String, RemotePolicy, [String], VisaStance, Verdict)] = [
        ("Remote", .remote, [], .silent, .pass),
        ("Almaty, Kazakhstan", .hybrid, [], .silent, .pass),
        ("Almaty, Kazakhstan", .onsite, [], .silent, .pass),
        ("Berlin, Germany", .onsite, [], .sponsors, .pass),
        ("Berlin, Germany", .onsite, [], .silent, .flag),
        ("Berlin, Germany", .hybrid, [], .silent, .flag),
        ("Remote", .remote, ["United States"], .silent, .flag),
        ("Remote", .remote, ["Poland", "Germany"], .silent, .flag),
        ("Remote", .remote, ["Kazakhstan"], .silent, .pass),
        ("Remote", .remote, ["Worldwide"], .silent, .pass),
        ("Remote", .remote, ["GMT+5"], .silent, .pass),
        ("Remote", .remote, ["United States"], .sponsors, .pass),
        ("Remote", .unspecified, [], .silent, .flag),
        // Review finding 4: any listed candidate region is enough; "anywhere in X" names X.
        ("Remote", .remote, ["Kazakhstan", "Uzbekistan", "Georgia"], .silent, .pass),
        ("Remote", .remote, ["Anywhere in the United States"], .silent, .flag),
        ("Remote", .remote, ["Anywhere"], .silent, .pass),
        // Review finding 5: blank entries (an empty edit field) are ignored.
        ("Remote", .remote, [""], .silent, .pass),
    ]

    @Test(arguments: locationCases)
    func locationVerdictFollowsPolicyPlaceAndSponsorship(location: String, policy: RemotePolicy, requirement: [String],
                                                          visa: VisaStance, expected: Verdict) {
        let posting = JobPosting.sample(location: location, remotePolicy: policy, locationRequirement: requirement, visaSponsorship: visa)
        #expect(Gates.location(posting, profile: .fixture).verdict == expected)
    }

    @Test func locationFlagQuotesTheRequirement() {
        let result = Gates.location(.sample(locationRequirement: ["United States"]), profile: .fixture)
        #expect(result.note?.contains("United States") == true)
    }

    @Test func runReportsAnyFail() {
        #expect(Gates.run(.sample(), profile: .fixture).anyFail == false)
        #expect(Gates.run(.sample(visaSponsorship: .clearanceRequired), profile: .fixture).anyFail)
        #expect(Gates.run(.sample(requiredLanguages: [LanguageRequirement(language: "Polish", level: "")]), profile: .fixture).anyFail)
    }

    @Test func twoHundredRandomPostingsNeverCrashAndEveryNonPassHasANote() {
        var rng = SplitMix64(seed: 2026_09_27)
        let words = ["", "Remote", "Almaty", "Berlin", "native", "C2", "fluent", "English", "Polish", "Kazakhstan", "GMT+5", "🚀", "ü"]
        func word() -> String { words.randomElement(using: &rng)! }
        for _ in 0..<200 {
            let posting = JobPosting(
                title: word(), company: word(), location: word(),
                remotePolicy: [.remote, .hybrid, .onsite, .unspecified].randomElement(using: &rng)!,
                employmentType: [.fullTime, .partTime, .contract, .freelance, .unspecified].randomElement(using: &rng)!,
                locationRequirement: (0..<Int.random(in: 0...3, using: &rng)).map { _ in word() },
                visaSponsorship: [.sponsors, .citizenshipOrPRRequired, .clearanceRequired, .authorizationRequired, .silent].randomElement(using: &rng)!,
                eligibilityQuote: word(),
                requiredLanguages: (0..<Int.random(in: 0...3, using: &rng)).map { _ in LanguageRequirement(language: word(), level: word()) },
                stack: [], minYearsExperience: Int.random(in: -5...50, using: &rng), compensation: word(), deadline: word())
            let report = Gates.run(posting, profile: .fixture)
            for gate in [report.eligibility, report.language, report.location] where gate.verdict != .pass {
                #expect(gate.note?.isEmpty == false)
            }
        }
    }
}

/// Seeded generator so the fuzz test is reproducible.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
