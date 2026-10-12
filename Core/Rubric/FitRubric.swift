/// Technical, experience, behavioral and career scores from a `PostingDigest`, for this candidate
/// (04-job-evaluation.md). Deterministic: the on-device model rated almost every posting "good" or
/// better when it saw the profile, so it only describes the posting (docs/MODEL_BEHAVIOR.md §7).
public enum FitRubric {
    public enum Skill: Equatable, Sendable { case strong, moderate, weak, unknown }

    public static func scores(digest: PostingDigest, stack: [String], skills tiers: SkillTiers) -> DimensionScores {
        let requirements = digest.mustHave + stack
        let skills = requirements.compactMap { skill(of: $0, in: tiers) }
        let value: [Skill: Double] = [.strong: 1, .moderate: 0.65, .weak: 0.25, .unknown: 0.5]
        let mean: Double = skills.map { value[$0]! }.reduce(0, +) / Double(max(skills.count, 1))
        let technical = skills.isEmpty ? 60 : Int((20 + 75 * mean).rounded())

        let base: [RoleFocus: Int] = [.llmApplications: 85, .backend: 70, .fullStack: 65, .consulting: 60, .mlModeling: 55,
                                      .aiTrainingData: 40, .dataEngineering: 35, .management: 30, .other: 50]
        let experience = base[digest.roleFocus]! + (digest.llmWork == .core && digest.roleFocus != .llmApplications ? 5 : 0)
        // Career goal: senior applied-LLM engineer. These roles do not build toward it, whatever their LLM share.
        let cap: [RoleFocus: Int] = [.mlModeling: 50, .aiTrainingData: 40, .dataEngineering: 35, .management: 30]
        let career = min([LLMWork.core: 85, .part: 65, .none: 45][digest.llmWork]!, cap[digest.roleFocus] ?? 100)
        let behavioral = [RoleFocus.consulting: 55, .management: 50][digest.roleFocus] ?? 65

        func lexicon(_ wanted: Skill) -> [String] { [.strong: tiers.strong, .moderate: tiers.moderate, .weak: tiers.weak][wanted]! }
        func terms(_ wanted: Skill) -> String {
            var seen: [String] = []
            for r in requirements where skill(of: r, in: tiers) == wanted {
                for t in matchedTerms(r, in: lexicon(wanted)) where !seen.contains(t) { seen.append(t) }
            }
            return seen.prefix(5).joined(separator: ", ")
        }
        let primary = terms(.strong), secondary = terms(.moderate), weak = terms(.weak)
        let strengths = [primary.isEmpty ? nil : "Asks for primary skills: \(primary)",
                         digest.llmWork == .core ? "LLM work is the main job" : nil,
                         secondary.isEmpty ? nil : "Asks for secondary skills: \(secondary)"].compactMap { $0 }
        let unknown = digest.mustHave.first { skill(of: $0, in: tiers) == .unknown }
        let gaps = [weak.isEmpty ? nil : "Asks for weak areas: \(weak)",
                    unknown.map { "Not in the profile: \($0.count > 100 ? String($0.prefix(100)) + "…" : $0)" },
                    digest.llmWork == .none ? "No LLM work named" : nil].compactMap { $0 }
        return DimensionScores(technical: technical, experience: experience, behavioral: behavioral, career: career,
                               strengths: Array(strengths.prefix(3)), gaps: Array(gaps.prefix(3)))
    }

    /// The rubric area a requirement names; `nil` for soft skills, degrees and languages. A weak area wins
    /// over a strong word in the same requirement ("fine-tuning LLMs" is fine-tuning). `tiers` is the
    /// candidate's own lexicon (`CandidateProfile.skills`); this app ships no personal skill list.
    public static func skill(of requirement: String, in tiers: SkillTiers) -> Skill? {
        let lexicon: [Skill: [String]] = [.strong: tiers.strong, .moderate: tiers.moderate, .weak: tiers.weak]
        for area in [Skill.weak, .strong, .moderate] where !matchedTerms(requirement, in: lexicon[area]!).isEmpty { return area }
        return matchedTerms(requirement, in: soft).isEmpty ? .unknown : nil
    }

    static let soft = ["communicat*", "english", "team*", "collaborat*", "problem solv*", "mindset", "autonom*", "independen*",
                       "ownership", "degree", "bachelor*", "master*", "curio*", "attitude", "self starter", "detail*",
                       "fast paced", "written", "verbal", "explain*"]

    /// Lowercased words; separators are anything but letters, digits and `+#.`; a trailing `.` ends a sentence.
    static func words(_ text: String) -> [Substring] {
        text.lowercased().split { !($0.isLetter || $0.isNumber || "+#.".contains($0)) }.map { w in
            var w = w[...]
            while w.count > 1, w.last == "." { w = w.dropLast() }
            return w
        }
    }

    /// Total occurrences of one term (not just whether it matches at all), for `SkillTiers.derived`.
    static func termCount(_ text: String, of term: String) -> Int {
        let tokens = words(text)
        let parts = term.split(separator: " ")
        guard tokens.count >= parts.count else { return 0 }
        var count = 0
        for start in 0...(tokens.count - parts.count) {
            let hit = parts.indices.allSatisfy { i in
                let part = parts[i], token = tokens[start + i]
                return part.hasSuffix("*") ? token.hasPrefix(part.dropLast()) : token == part
            }
            if hit { count += 1 }
        }
        return count
    }

    static func matchedTerms(_ text: String, in terms: [String]) -> [String] {
        let tokens = words(text)
        return terms.compactMap { term in
            let parts = term.split(separator: " ")
            guard tokens.count >= parts.count else { return nil }
            for start in 0...(tokens.count - parts.count) {
                let hit = parts.indices.allSatisfy { i in
                    let part = parts[i], token = tokens[start + i]
                    return part.hasSuffix("*") ? token.hasPrefix(part.dropLast()) : token == part
                }
                if hit { return tokens[start..<start + parts.count].joined(separator: " ") }
            }
            return nil
        }
    }
}
