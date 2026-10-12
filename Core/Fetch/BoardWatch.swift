import Foundation

/// Company job boards the phone reads directly: public ATS list endpoints, no key, no server.
/// Titles are matched against the profile's target roles; matches go to the normal parse pipeline.
public enum BoardWatch {
    public enum Board: Codable, Hashable, Comparable, Sendable {
        case greenhouse(String), lever(String), ashby(String)

        /// A board or job URL on Greenhouse, Lever or Ashby; nil for anything else.
        public init?(url: String) {
            guard let u = URL(string: url), let host = u.host?.lowercased(),
                  let token = u.pathComponents.dropFirst().first?.lowercased(), !token.isEmpty else { return nil }
            if host.hasSuffix("greenhouse.io") { self = .greenhouse(token) }
            else if host.hasSuffix("lever.co") { self = .lever(token) }
            else if host.hasSuffix("ashbyhq.com") { self = .ashby(token) }
            else { return nil }
        }

        public var token: String {
            switch self { case .greenhouse(let t), .lever(let t), .ashby(let t): t }
        }

        var listURL: URL {
            switch self {
            case .greenhouse(let t): URL(string: "https://boards-api.greenhouse.io/v1/boards/\(t)/jobs")!
            case .lever(let t): URL(string: "https://api.lever.co/v0/postings/\(t)?mode=json&limit=300")!
            case .ashby(let t): AshbyClient.endpoint(board: t)
            }
        }
    }

    public struct Listing: Equatable, Hashable, Sendable {
        public var title: String
        public var url: String
        public var location: String
        public var company: String
    }

    private struct GreenhouseList: Decodable {
        struct Job: Decodable {
            var title: String
            var absolute_url: String
            var location: GreenhouseClient.Job.Location?
        }
        var jobs: [Job]
    }

    public static func listings(_ board: Board, data: Data) throws -> [Listing] {
        let d = JSONDecoder()
        switch board {
        case .greenhouse(let t):
            return try d.decode(GreenhouseList.self, from: data).jobs
                .map { Listing(title: $0.title, url: $0.absolute_url, location: $0.location?.name ?? "", company: t) }
        case .lever(let t):
            return try d.decode([LeverClient.Posting].self, from: data)
                .map { Listing(title: $0.text, url: $0.hostedUrl, location: $0.categories.location ?? "", company: t) }
        case .ashby(let t):
            return try AshbyClient.decode(data).jobs
                .map { Listing(title: $0.title, url: $0.jobUrl, location: $0.location, company: t) }
        }
    }

    public static func listings(_ board: Board, session: URLSession = .shared) async throws -> [Listing] {
        try listings(board, data: try await HTTP.get(board.listURL, session: session))
    }

    /// A listing matches a role when its title contains every word of the role.
    public static func matching(_ listings: [Listing], roles: [String]) -> [Listing] {
        let roleWords = roles.map(words).filter { !$0.isEmpty }
        return listings.filter { l in
            let title = Set(words(l.title))
            return roleWords.contains { $0.allSatisfy(title.contains) }
        }
    }

    public static func boards(fromURLs urls: [String]) -> [Board] {
        Set(urls.compactMap(Board.init(url:))).sorted()
    }

    static func words(_ s: String) -> [String] {
        s.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// One slow board must not hold the search: 20 s per board, then it is skipped.
    public static let searchSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 20
        return URLSession(configuration: config)
    }()

    /// Every board at once, then the matches. A failing board is skipped.
    public static func search(_ boards: [Board], roles: [String], session: URLSession = searchSession) async -> [Listing] {
        await withTaskGroup(of: [Listing].self) { group in
            for board in boards {
                group.addTask { (try? await listings(board, session: session)).map { matching($0, roles: roles) } ?? [] }
            }
            return await group.reduce(into: []) { $0 += $1 }
        }
    }
}
