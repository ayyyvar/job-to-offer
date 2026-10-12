import Core
import Foundation
import Testing

@Suite struct AshbyClientTests {
    static let id = "03bce1ad-e59b-4037-bb1c-32e4c3fb7916"

    static func board() throws -> AshbyClient.Board {
        try AshbyClient.decode(Fixture.load("ATS/ashby_2026-09-27.json"))
    }

    @Test func endpointIsTheJobBoardAPIWithCompensation() {
        #expect(AshbyClient.endpoint(board: "variantly").absoluteString
            == "https://api.ashbyhq.com/posting-api/job-board/variantly?includeCompensation=true")
    }

    @Test func endpointPercentEncodesABoardNameWithSpaces() {
        #expect(AshbyClient.endpoint(board: "Quickwrite Platform Inc").absoluteString
            == "https://api.ashbyhq.com/posting-api/job-board/Quickwrite%20Platform%20Inc?includeCompensation=true")
    }

    @Test func decodeYieldsTheDocumentedFieldsForTheJobPickedById() throws {
        let job = try #require(AshbyClient.job(in: try Self.board(), id: Self.id))
        #expect(job.title == "Backend Engineer (Python)")
        #expect(job.location == "Remote - Europe Time Zones")
        #expect(job.isRemote == true)
        #expect(job.descriptionPlain.hasPrefix("Variantly is a global software company"))
        #expect(job.jobUrl == "https://jobs.ashbyhq.com/variantly/\(Self.id)")
        #expect(job.publishedAt == "2026-09-16T14:11:08.103+00:00")
        #expect(job.employmentType == "FullTime")
    }

    @Test func boardHasAllSevenJobs() throws {
        #expect(try Self.board().jobs.count == 7)
    }

    @Test func pickingAMissingIdGivesNil() throws {
        #expect(AshbyClient.job(in: try Self.board(), id: "00000000-0000-0000-0000-000000000000") == nil)
    }

    @Test func fetchedPostingIsPlainTextWithTheStructuredFacts() throws {
        let job = try #require(AshbyClient.job(in: try Self.board(), id: Self.id))
        let fetched = AshbyClient.posting(job, board: "variantly")
        #expect(fetched.title == "Backend Engineer (Python)")
        #expect(fetched.company == "variantly")
        #expect(fetched.url == "https://jobs.ashbyhq.com/variantly/\(Self.id)")
        #expect(fetched.plainText.hasPrefix("Backend Engineer (Python)\nLocation: Remote - Europe Time Zones\nWorkplace: Remote\nEmployment: FullTime\n\nVariantly is"))
        #expect(!fetched.plainText.contains("Compensation:"))
        #expect(fetched.postedAt == (try Date("2026-09-16T14:11:08.103Z", strategy: .iso8601)))
    }
}
