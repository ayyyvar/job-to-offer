import Foundation

/// Greenhouse Job Board API (no auth). EU boards (`job-boards.eu.greenhouse.io`) use the same
/// API host: `boards-api.eu.greenhouse.io` does not resolve (checked 2026-09-27).
public enum GreenhouseClient {
    public struct Job: Decodable, Equatable, Sendable {
        public struct Location: Decodable, Equatable, Sendable { public var name: String }
        public var title: String
        public var location: Location
        /// HTML. The API sends it entity-encoded; `decode` turns it back into HTML.
        public var content: String
        public var absoluteURL: String
        public var updatedAt: String
        public var firstPublished: String?

        enum CodingKeys: String, CodingKey {
            case title, location, content
            case absoluteURL = "absolute_url", updatedAt = "updated_at", firstPublished = "first_published"
        }
    }

    public static func endpoint(board: String, id: String) -> URL {
        URL(string: "https://boards-api.greenhouse.io/v1/boards/\(board)/jobs/\(id)?content=true")!
    }

    public static func decode(_ data: Data) throws -> Job {
        var job = try JSONDecoder().decode(Job.self, from: data)
        job.content = HTMLText.decodeEntities(job.content)
        return job
    }

    public static func posting(_ job: Job, board: String) -> FetchedPosting {
        FetchedPosting(
            title: job.title,
            company: board,
            url: job.absoluteURL,
            plainText: FetchedPosting.text(title: job.title, facts: ["Location": job.location.name],
                                           body: HTMLText.plainText(job.content)),
            // Publication date only; `updated_at` is not when the job was posted.
            postedAt: HTTP.isoDate(job.firstPublished)
        )
    }

    public static func fetch(board: String, id: String, session: URLSession = .shared) async throws -> FetchedPosting {
        posting(try decode(try await HTTP.get(endpoint(board: board, id: id), session: session)), board: board)
    }
}
