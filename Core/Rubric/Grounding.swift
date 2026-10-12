extension JobPosting {
    /// Drops permissive claims the posting text does not support. The on-device model fills fields a
    /// posting never states (visa sponsorship, remote, full-time, "not specified"); gates must not act on
    /// those. Restrictive claims stay: a wrong FAIL is visible and editable, a wrong PASS is silent.
    /// It never upgrades a field: a stance the model missed stays missed.
    public func grounded(in text: String) -> JobPosting {
        var p = self
        let lower = text.lowercased()
        func says(_ words: [String]) -> Bool { words.contains { lower.contains($0) } }
        func says(in sentence: String, _ words: [String]) -> Bool {
            let s = sentence.lowercased()
            return words.contains { s.contains($0) }
        }
        let sentences = Self.sentences(text)
        func mentioning(_ words: [String]) -> [String] { sentences.filter { s in words.contains { s.lowercased().contains($0) } } }

        switch p.visaSponsorship {
        case .silent:
            p.eligibilityQuote = ""
        case .sponsors:
            let mentions = mentioning(Self.visaWords[.sponsors]!)
            // A bare "sponsor" (events, community sponsorships, sponsored content) does not support the
            // permissive claim: require the sentence to also name the immigration domain and offer it
            // ("- Jobs with Visa Sponsorship" menu line has the domain word but offers nothing).
            let permissive = mentions.filter { says(in: $0, Self.immigrationDomainWords) && says(in: $0, Self.offerWords) }
            if let negated = mentions.first(where: { $0.contains(/\b(no|not|unable|cannot|unavailable|without)\b|n['’]t\b/.ignoresCase()) }) {
                p.visaSponsorship = .authorizationRequired
                p.eligibilityQuote = negated
            } else if let sentence = permissive.first {
                p.eligibilityQuote = sentence
            } else {
                p.visaSponsorship = .silent
                p.eligibilityQuote = ""
            }
        case .citizenshipOrPRRequired, .clearanceRequired, .authorizationRequired:
            // Quote only words the posting contains; never show the model's paraphrase as a quote.
            let squash = { (s: String) in s.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            if let sentence = mentioning(Self.visaWords[p.visaSponsorship]!).first {
                p.eligibilityQuote = sentence
            } else if p.eligibilityQuote.isEmpty || !squash(text).contains(squash(p.eligibilityQuote)) {
                p.eligibilityQuote = ""
            }
        }

        // Gate injection eval 2026-09-27: the model returned `.silent` for 8 of 9 stated restrictions. A sentence
        // that states one upgrades the stance and becomes the quote; a stricter stance is never lowered.
        if let (stance, sentence) = Self.statedRestriction(in: sentences), stance.strictness > p.visaSponsorship.strictness {
            p.visaSponsorship = stance
            p.eligibilityQuote = sentence
        }

        let policyWords: [RemotePolicy: [String]] = [
            .remote: ["remote", "work from anywhere", "work from home", "distributed team"],
            .hybrid: ["hybrid"],
            .onsite: ["on-site", "onsite", "on site", "in-office", "in office", "office-based", "in the office"],
        ]
        if let words = policyWords[p.remotePolicy], !says(words) { p.remotePolicy = .unspecified }

        let employmentWords: [EmploymentType: [String]] = [
            .fullTime: ["full-time", "full time", "fulltime", "permanent"],
            .partTime: ["part-time", "part time", "parttime"],
            .contract: ["contract", "b2b"],
            .freelance: ["freelance"],
        ]
        if let words = employmentWords[p.employmentType], !says(words) { p.employmentType = .unspecified }

        // Human languages only: the model lists programming languages and tools here too ("Azure DevOps").
        let stack = Set(p.stack.map { $0.lowercased() })
        p.requiredLanguages = p.requiredLanguages.filter { requirement in
            let name = requirement.language.trimmingCharacters(in: .whitespaces).lowercased()
            let tool = !FitRubric.matchedTerms(name, in: SkillTiers.catalog).isEmpty
            // Page chrome ("FrançaisEnglish (US)English (UK)") can make the model emit a language that is
            // only named in translation ("Français" for "French"); require the emitted name itself in the text.
            return !name.isEmpty && !stack.contains(name) && !Self.programmingLanguages.contains(name) && !tool && lower.contains(name)
        }
        // Places stay even when paraphrased ("US only" → "United States"): a dropped one is a silent PASS.
        p.locationRequirement = p.locationRequirement.filter {
            let place = $0.trimmingCharacters(in: .whitespaces).lowercased()
            return !place.isEmpty && place != "remote"
        }
        if !p.compensation.contains(where: \.isNumber) { p.compensation = "" }
        if p.deadline.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) == nil { p.deadline = "" }
        return p
    }

    /// The strictest restriction a sentence states. Equal-opportunity boilerplate ("regardless of citizenship"),
    /// welcomes and "company-sponsored trips" do not count.
    static func statedRestriction(in sentences: [String]) -> (VisaStance, String)? {
        let rules: [(VisaStance, Regex<Substring>)] = [
            (.citizenshipOrPRRequired, /\bcitizens?\b|\bcitizenship\b|permanent resid|green card/),
            (.clearanceRequired, /security clearance|\b(?:secret|ts\/sci|active|dv|sc|baseline)\s+(?:security\s+)?clearance|clearance\s+(?:is\s+)?required/),
            (.authorizationRequired, /right to work|authori[sz]ed to work|eligible to work|work authori[sz]ation|\b(?:unable|cannot|can['’]t|not|no)\b[^.]{0,40}\bsponsor|sponsorship\s+(?:is\s+)?(?:not|unavailable)/),
        ]
        let exempt = /regardless|without regard|irrespective|equal opportunit|welcome|not required|any nationality/
        for (stance, rule) in rules {
            if let s = sentences.first(where: { $0.contains(rule.ignoresCase()) && !$0.contains(exempt.ignoresCase()) }) { return (stance, s) }
        }
        return nil
    }

    static let programmingLanguages: Set = [
        "python", "java", "javascript", "typescript", "go", "golang", "rust", "c", "c++", "c#", "sql", "kotlin",
        "swift", "ruby", "php", "scala", "r", "bash", "html", "css",
    ]

    /// Words that separate an immigration-related "sponsor" from events, communities or sponsored content.
    static let immigrationDomainWords = ["visa", "work permit", "immigration", "relocation", "international applicant"]

    /// A permissive "sponsor" sentence must also offer it, not just list the topic (a job-board filter menu).
    static let offerWords = ["offer", "provide", "support", "available", "we sponsor", "can sponsor", "will sponsor"]

    static let visaWords: [VisaStance: [String]] = [
        .sponsors: ["sponsor", "visa", "relocation", "international applicants", "work permit"],
        .citizenshipOrPRRequired: ["citizen", "permanent resid", "green card"],
        .clearanceRequired: ["clearance", "cleared", "ts/sci", "security vetting"],
        .authorizationRequired: ["authoriz", "authoris", "right to work", "eligible to work", "work permit", "sponsor"],
    ]

    /// Lines, then sentences: a split after `.!?` only when a capital letter follows, so "U.S. citizens" stays whole.
    static func sentences(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).flatMap { line -> [String] in
            var result: [String] = [], current = ""
            let chars = Array(line)
            for (i, c) in chars.enumerated() {
                current.append(c)
                if ".!?".contains(c), i + 2 < chars.count, chars[i + 1] == " ", chars[i + 2].isUppercase {
                    result.append(current)
                    current = ""
                }
            }
            result.append(current)
            return result.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
    }
}

private extension VisaStance {
    var strictness: Int {
        switch self {
        case .silent, .sponsors: 0
        case .authorizationRequired: 1
        case .clearanceRequired, .citizenshipOrPRRequired: 2
        }
    }
}
