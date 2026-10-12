public struct GateResult: Equatable, Sendable {
    public var verdict: Verdict
    public var note: String?
}

public struct GateReport: Equatable, Sendable {
    public var eligibility: GateResult
    public var language: GateResult
    public var location: GateResult
    public var anyFail: Bool { [eligibility, language, location].contains { $0.verdict == .fail } }
}

/// The Eligibility, Language and Location gates from 04-job-evaluation.md, for a `CandidateProfile`.
/// Deterministic: the model only extracts `JobPosting` fields.
public enum Gates {
    public static func run(_ p: JobPosting, profile: CandidateProfile) -> GateReport {
        GateReport(eligibility: eligibility(p), language: language(p, profile: profile), location: location(p, profile: profile))
    }

    public static func eligibility(_ p: JobPosting) -> GateResult {
        let quoted = p.eligibilityQuote.isEmpty ? "" : ": \"\(p.eligibilityQuote)\""
        return switch p.visaSponsorship {
        case .citizenshipOrPRRequired: GateResult(verdict: .fail, note: "Requires citizenship or permanent residency\(quoted)")
        case .clearanceRequired: GateResult(verdict: .fail, note: "Requires a security clearance\(quoted)")
        case .authorizationRequired: GateResult(verdict: .flag, note: "Requires existing work authorization\(quoted)")
        case .sponsors: GateResult(verdict: .pass, note: nil)
        case .silent: GateResult(verdict: .pass, note: "Silent on citizenship or residency: unverified")
        }
    }

    public static func language(_ p: JobPosting, profile: CandidateProfile) -> GateResult {
        func named(_ r: LanguageRequirement) -> String { r.level.isEmpty ? r.language : "\(r.language) (\(r.level))" }
        func optional(_ r: LanguageRequirement) -> Bool {
            ["plus", "nice to have", "preferred", "bonus", "advantage", "optional"].contains { r.level.lowercased().contains($0) }
        }
        func candidateLevel(_ r: LanguageRequirement) -> String? {
            let name = r.language.lowercased()
            return profile.languages.first { name.contains($0.key) }?.value
        }
        let listed = p.requiredLanguages.filter { !$0.language.trimmingCharacters(in: .whitespaces).isEmpty }
        if profile.languages.isEmpty {
            return listed.isEmpty ? GateResult(verdict: .pass, note: nil)
                : GateResult(verdict: .flag, note: "Profile has no languages: unverified")
        }
        let unknown = listed.filter { candidateLevel($0) == nil }
        if let required = unknown.first(where: { !optional($0) }) {
            return GateResult(verdict: .fail, note: "Requires \(named(required)); not a candidate language")
        }
        let aboveFluent = listed.filter { r in
            guard candidateLevel(r) == "fluent" else { return false }
            let level = r.level.lowercased()
            return !level.contains("non-native") && !level.contains("non native")
                && ["native", "c2", "mother tongue"].contains { level.contains($0) }
        }
        if !unknown.isEmpty || !aboveFluent.isEmpty {
            let parts = unknown.map { "\(named($0)) is optional and not a candidate language" }
                + aboveFluent.map { "Requires \(named($0)); candidate \($0.language) is fluent" }
            return GateResult(verdict: .flag, note: parts.joined(separator: ". "))
        }
        return GateResult(verdict: .pass, note: nil)
    }

    public static func location(_ p: JobPosting, profile: CandidateProfile) -> GateResult {
        let sponsors = p.visaSponsorship == .sponsors
        switch p.remotePolicy {
        case .remote:
            // Any listed candidate region is enough ("Kazakhstan, Uzbekistan or Georgia").
            let places = p.locationRequirement.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !places.isEmpty, !places.contains(where: { isCandidateRegion($0, profile: profile) }), !sponsors else {
                return GateResult(verdict: .pass, note: nil)
            }
            return GateResult(verdict: .flag, note: "Must be in \(places.joined(separator: ", ")); no sponsorship stated")
        case .hybrid, .onsite:
            if isCandidateRegion(p.location, profile: profile) || sponsors { return GateResult(verdict: .pass, note: nil) }
            return GateResult(verdict: .flag, note: "\(p.remotePolicy.rawValue) in \(p.location) needs relocation; no sponsorship stated")
        case .unspecified:
            return GateResult(verdict: .flag, note: "Remote policy not stated: unverified")
        }
    }

    static func isCandidateRegion(_ text: String, profile: CandidateProfile) -> Bool {
        let t = text.lowercased().replacing(" ", with: "")
        // "Anywhere in the United States" names the United States.
        return profile.regions.contains { t.contains($0) }
            || text.contains(/\b(anywhere|worldwide)\b(?!\s+in\b)/.ignoresCase())
    }
}
