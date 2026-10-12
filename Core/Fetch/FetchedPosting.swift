import Foundation

/// A posting as fetched, before the model extracts fields. Every fetch path returns this shape.
public struct FetchedPosting: Equatable, Sendable {
    public var title: String
    /// The ATS board token (percent-decoded). `/scrape` stores ATS jobs under the same name,
    /// so `JobKey` matches existing `seen_jobs.json` entries.
    public var company: String
    public var url: String
    public var plainText: String
    public var postedAt: Date?

    public init(title: String, company: String, url: String, plainText: String, postedAt: Date?) {
        self.title = title
        self.company = company
        self.url = url
        self.plainText = plainText
        self.postedAt = postedAt
    }

    /// Title and ATS facts first, so the model sees facts the body may not state.
    static func text(title: String, facts: KeyValuePairs<String, String?>, body: String) -> String {
        let lines = facts.compactMap { name, value in
            value.flatMap { $0.isEmpty ? nil : "\(name): \($0)" }
        }
        return ([title] + lines).joined(separator: "\n") + "\n\n" + body
    }
}

public enum FetchError: Error, Equatable {
    case http(status: Int, url: URL)
    case jobNotFound(id: String)
    case badURL(String)
    case notText(String)
}

enum HTTP {
    static func get(_ url: URL, session: URLSession) async throws -> Data {
        var request = URLRequest(url: url)
        // LinkedIn and some careers sites refuse clients without a browser user agent.
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0 Mobile/15E148 Safari/604.1",
                         forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw FetchError.http(status: status, url: url) }
        return data
    }

    static func isoDate(_ string: String?) -> Date? {
        string.flatMap { try? Date($0, strategy: .iso8601) }
    }
}
