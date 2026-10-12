import Foundation

/// Lever Postings API (no auth). `GET /v0/postings/SITE/POSTING-ID` is documented in
/// https://github.com/lever/postings-api ("Get a specific job posting", checked 2026-09-27).
public enum LeverClient {
    public struct Posting: Decodable, Equatable, Sendable {
        public struct ListItem: Decodable, Equatable, Sendable {
            public var text: String
            /// Unstyled HTML of `<li>` elements.
            public var content: String
        }
        public struct Categories: Decodable, Equatable, Sendable {
            public var location: String?
            public var commitment: String?
        }
        public struct SalaryRange: Decodable, Equatable, Sendable {
            public var min: Double?
            public var max: Double?
            public var currency: String?
            public var interval: String?
        }
        public var id: String
        public var text: String
        public var descriptionPlain: String
        public var additionalPlain: String?
        public var lists: [ListItem]
        public var categories: Categories
        public var hostedUrl: String
        /// Milliseconds since 1970.
        public var createdAt: Int64?
        public var workplaceType: String?
        public var salaryRange: SalaryRange?
    }

    public static func endpoint(site: String, id: String) -> URL {
        URL(string: "https://api.lever.co/v0/postings/\(site)/\(id)?mode=json")!
    }

    public static func decode(_ data: Data) throws -> Posting {
        try JSONDecoder().decode(Posting.self, from: data)
    }

    public static func posting(_ p: Posting, site: String) -> FetchedPosting {
        let lists = p.lists.map { "\($0.text)\n\(HTMLText.plainText($0.content))" }
        let body = ([p.descriptionPlain.trimmingCharacters(in: .whitespacesAndNewlines)] + lists + [p.additionalPlain ?? ""])
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return FetchedPosting(
            title: p.text,
            company: site,
            url: p.hostedUrl,
            plainText: FetchedPosting.text(title: p.text, facts: [
                "Location": p.categories.location,
                "Workplace": p.workplaceType == "unspecified" ? nil : p.workplaceType,
                "Commitment": p.categories.commitment,
                "Compensation": p.salaryRange.flatMap(salary),
            ], body: body),
            postedAt: p.createdAt.map { Date(timeIntervalSince1970: Double($0) / 1000) }
        )
    }

    public static func fetch(site: String, id: String, session: URLSession = .shared) async throws -> FetchedPosting {
        posting(try decode(try await HTTP.get(endpoint(site: site, id: id), session: session)), site: site)
    }

    static func salary(_ range: Posting.SalaryRange) -> String? {
        func number(_ value: Double) -> String { value == value.rounded() ? String(Int(value)) : String(value) }
        let amount = [range.min, range.max].compactMap { $0.map(number) }.joined(separator: "-")
        guard !amount.isEmpty else { return nil }
        return [amount, range.currency, range.interval].compactMap { $0 }.joined(separator: " ")
    }
}
