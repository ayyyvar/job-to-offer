import FoundationModels // only for the macros; Core still compiles for macOS 26+

/// Fields the on-device model extracts from a posting. Swift, not the model, turns them into
/// gate verdicts (`Gates`). `eligibilityQuote` is an addition to CLAUDE.md §4: an eligibility
/// FAIL must quote the posting's wording (04-job-evaluation.md).
@Generable
public struct JobPosting: Codable, Equatable, Sendable {
    @Guide(description: "Job title as written in the posting") public var title: String
    @Guide(description: "Employer name; empty string if the posting hides it") public var company: String
    @Guide(description: "City and country, or 'Remote'") public var location: String
    @Guide(description: "Remote policy") public var remotePolicy: RemotePolicy
    @Guide(description: "Employment type") public var employmentType: EmploymentType
    @Guide(description: "Countries or time zones the candidate must be in; empty if none") public var locationRequirement: [String]
    @Guide(description: "Visa or work-authorization statement") public var visaSponsorship: VisaStance
    @Guide(description: "The posting's sentence about citizenship, residency, security clearance, visa or work authorization, copied word for word; empty if none")
    public var eligibilityQuote: String
    @Guide(description: "Languages the job itself requires, with level words as written") public var requiredLanguages: [LanguageRequirement]
    @Guide(description: "Technologies named in requirements, lowercase") public var stack: [String]
    @Guide(description: "Years of experience required, 0 if not stated") public var minYearsExperience: Int
    @Guide(description: "Salary or rate exactly as written; empty if absent") public var compensation: String
    @Guide(description: "Application deadline as YYYY-MM-DD; empty if absent") public var deadline: String
}

@Generable public enum RemotePolicy: String, Codable, CaseIterable, Sendable { case remote, hybrid, onsite, unspecified }
@Generable public enum EmploymentType: String, Codable, CaseIterable, Sendable { case fullTime, partTime, contract, freelance, unspecified }
@Generable public enum VisaStance: String, Codable, CaseIterable, Sendable {
    case sponsors, citizenshipOrPRRequired, clearanceRequired, authorizationRequired, silent
}

@Generable public struct LanguageRequirement: Codable, Equatable, Sendable {
    public var language: String
    public var level: String

    public init(language: String, level: String) {
        self.language = language
        self.level = level
    }
}
