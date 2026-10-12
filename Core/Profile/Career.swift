import Foundation

/// Search links for the user's target roles. The app opens them; it never scrapes LinkedIn (CLAUDE.md rule 7).
public enum JobSearch {
    public static func linkedIn(role: String) -> URL {
        var c = URLComponents(string: "https://www.linkedin.com/jobs/search/")!
        c.queryItems = [.init(name: "keywords", value: role), .init(name: "f_WT", value: "2"), .init(name: "sortBy", value: "DD")]
        return c.url!
    }
}

/// Gaps and rejection reasons that repeat across tracked jobs, most frequent first.
public enum WeakSpots {
    public struct Spot: Equatable, Sendable {
        public var name: String
        public var count: Int
    }

    public static func rank(gaps: [[String]], reasons: [String], ignored: [String]) -> [Spot] {
        let skip = Set(ignored.map(normalized))
        var counts: [String: Int] = [:]
        for name in (gaps.flatMap { $0 } + reasons).map(normalized) where !name.isEmpty && !skip.contains(name) {
            counts[name, default: 0] += 1
        }
        return counts.map { Spot(name: $0.key, count: $0.value) }
            .sorted { ($0.count, $1.name) > ($1.count, $0.name) }
    }

    static func normalized(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
}
