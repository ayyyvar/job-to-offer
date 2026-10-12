import Foundation

/// Ashby public Job Posting API (no auth). There is no single-job endpoint:
/// fetch the board and pick the job by id (the UUID in `jobs.ashbyhq.com/<board>/<id>`).
public enum AshbyClient {
    public struct Board: Decodable, Equatable, Sendable {
        public var jobs: [Job]
    }

    public struct Job: Decodable, Equatable, Sendable {
        public struct Compensation: Decodable, Equatable, Sendable {
            public var compensationTierSummary: String?
        }
        public var id: String
        public var title: String
        public var location: String
        public var isRemote: Bool?
        public var descriptionPlain: String
        public var jobUrl: String
        public var publishedAt: String?
        public var employmentType: String?
        public var workplaceType: String?
        public var compensation: Compensation?
    }

    public static func endpoint(board: String) -> URL {
        let encoded = board.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? board
        return URL(string: "https://api.ashbyhq.com/posting-api/job-board/\(encoded)?includeCompensation=true")!
    }

    public static func decode(_ data: Data) throws -> Board {
        try JSONDecoder().decode(Board.self, from: data)
    }

    public static func job(in board: Board, id: String) -> Job? {
        board.jobs.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }
    }

    public static func posting(_ job: Job, board: String) -> FetchedPosting {
        FetchedPosting(
            title: job.title,
            company: board,
            url: job.jobUrl,
            plainText: FetchedPosting.text(title: job.title, facts: [
                "Location": job.location,
                "Workplace": job.workplaceType,
                "Employment": job.employmentType,
                "Compensation": job.compensation?.compensationTierSummary,
            ], body: job.descriptionPlain.trimmingCharacters(in: .whitespacesAndNewlines)),
            postedAt: HTTP.isoDate(job.publishedAt)
        )
    }

    public static func fetch(board: String, id: String, session: URLSession = .shared) async throws -> FetchedPosting {
        let decoded = try decode(try await HTTP.get(endpoint(board: board), session: session))
        guard let job = job(in: decoded, id: id) else { throw FetchError.jobNotFound(id: id) }
        return posting(job, board: board)
    }
}
