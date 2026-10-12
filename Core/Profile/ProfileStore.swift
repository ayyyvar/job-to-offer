import Foundation

/// Persists the candidate profile and the raw resume text it was derived from, in the App Group
/// suite so the app and the share extension see the same profile.
public struct ProfileStore: Sendable {
    let suiteName: String
    var defaults: UserDefaults { UserDefaults(suiteName: suiteName) ?? .standard }

    public init(suiteName: String = SharedStore.appGroupID) {
        self.suiteName = suiteName
    }

    public func load() -> CandidateProfile {
        guard let data = defaults.data(forKey: "candidateProfile"),
              let profile = try? JSONDecoder().decode(CandidateProfile.self, from: data) else { return .empty }
        return profile
    }

    public func save(_ profile: CandidateProfile) {
        defaults.set(try? JSONEncoder().encode(profile), forKey: "candidateProfile")
    }

    public func loadLibrary() -> [ExperienceItem] {
        guard let data = defaults.data(forKey: "experienceLibrary") else { return [] }
        return (try? JSONDecoder().decode([ExperienceItem].self, from: data)) ?? []
    }

    public func saveLibrary(_ items: [ExperienceItem]) {
        defaults.set(try? JSONEncoder().encode(items), forKey: "experienceLibrary")
    }

    public func loadBoards() -> [BoardWatch.Board] {
        guard let data = defaults.data(forKey: "watchedBoards") else { return [] }
        return (try? JSONDecoder().decode([BoardWatch.Board].self, from: data)) ?? []
    }

    public func saveBoards(_ boards: [BoardWatch.Board]) {
        defaults.set(try? JSONEncoder().encode(boards), forKey: "watchedBoards")
    }

    public func loadResumeText() -> String? { defaults.string(forKey: "resumeText") }

    public func saveResumeText(_ text: String) {
        defaults.set(text, forKey: "resumeText")
    }
}
