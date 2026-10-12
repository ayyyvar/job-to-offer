/// The candidate this app scores postings for. No longer hard-coded: built from resume import or
/// user settings (`ProfileStore`). `Gates` and `FitRubric` take it as a parameter.
public struct CandidateProfile: Codable, Equatable, Sendable {
    /// Lowercase match tokens for the Location gate, e.g. ["kazakhstan", "almaty", "gmt+5", "utc+5"].
    public var regions: [String]
    /// Language name (lowercase) → level ("native" or "fluent"), for the Language gate.
    public var languages: [String: String]
    public var skills: SkillTiers
    /// Job titles the user searches for, e.g. ["AI Engineer", "LLM Engineer"].
    public var targetRoles: [String] = []

    public init(regions: [String], languages: [String: String], skills: SkillTiers) {
        self.regions = regions
        self.languages = languages
        self.skills = skills
    }

    enum CodingKeys: String, CodingKey { case regions, languages, skills, targetRoles }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        regions = try c.decode([String].self, forKey: .regions)
        languages = try c.decode([String: String].self, forKey: .languages)
        skills = try c.decode(SkillTiers.self, forKey: .skills)
        targetRoles = try c.decodeIfPresent([String].self, forKey: .targetRoles) ?? []
    }

    /// A gap the user closed: the term joins the moderate tier and leaves the weak one.
    public mutating func addSkill(_ term: String) {
        let t = term.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty, !skills.strong.contains(t), !skills.moderate.contains(t) else { return }
        skills.weak.removeAll { $0 == t }
        skills.moderate.append(t)
    }

    public static let empty = CandidateProfile(regions: [], languages: [:], skills: SkillTiers(strong: [], moderate: [], weak: []))
}
