import Core
import Foundation
import Testing

@Suite struct GreenhouseClientTests {
    static func job() throws -> GreenhouseClient.Job {
        try GreenhouseClient.decode(Fixture.load("ATS/greenhouse_2026-09-27.json"))
    }

    @Test func endpointIsTheBoardsAPIWithContent() {
        #expect(GreenhouseClient.endpoint(board: "sandboxly", id: "4005254009").absoluteString
            == "https://boards-api.greenhouse.io/v1/boards/sandboxly/jobs/4005254009?content=true")
    }

    @Test func decodeYieldsTheDocumentedFields() throws {
        let job = try Self.job()
        #expect(job.title == "Senior Applied AI Engineer")
        #expect(job.location.name == "Remote")
        #expect(job.absoluteURL == "https://job-boards.greenhouse.io/sandboxly/jobs/4005254009")
        #expect(job.updatedAt == "2026-09-14T21:11:27-04:00")
        #expect(job.firstPublished == "2025-06-25T00:17:58-04:00")
    }

    @Test func decodeTurnsTheEntityEncodedContentIntoHTML() throws {
        let content = try Self.job().content
        #expect(content.hasPrefix("<h4"))
        #expect(!content.contains("&lt;"))
        #expect(!content.contains("&quot;"))
    }

    @Test func postingIsPlainTextWithTitleLocationAndBody() throws {
        let posting = GreenhouseClient.posting(try Self.job(), board: "sandboxly")
        #expect(posting.title == "Senior Applied AI Engineer")
        #expect(posting.company == "sandboxly")
        #expect(posting.url == "https://job-boards.greenhouse.io/sandboxly/jobs/4005254009")
        #expect(posting.plainText.hasPrefix("Senior Applied AI Engineer\nLocation: Remote\n\n"))
        #expect(posting.plainText.contains("About Us"))
        #expect(!posting.plainText.contains("<"))
        #expect(!posting.plainText.contains("&nbsp;"))
        #expect(posting.postedAt == (try Date("2025-06-25T04:17:58Z", strategy: .iso8601)))
    }
}
