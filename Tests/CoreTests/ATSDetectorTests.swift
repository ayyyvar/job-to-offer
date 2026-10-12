import Core
import Foundation
import Testing

@Suite struct ATSDetectorTests {
    static func detect(_ string: String) throws -> ATSSource {
        ATSDetector.detect(try #require(URL(string: string)))
    }

    // Hosts and paths taken from real URLs in seen_jobs.json.
    @Test(arguments: [
        ("https://boards.greenhouse.io/swatchwell/jobs/7732615003", "swatchwell", "7732615003"),
        ("https://job-boards.greenhouse.io/sandboxly/jobs/4005254009", "sandboxly", "4005254009"),
        ("https://job-boards.eu.greenhouse.io/quantaops/jobs/4986807101", "quantaops", "4986807101"),
        ("https://job-boards.greenhouse.io/halcyon/jobs/5063490007?gh_src=abc", "halcyon", "5063490007"),
    ])
    func greenhouseURLGivesBoardAndId(url: String, board: String, id: String) throws {
        #expect(try Self.detect(url) == .greenhouse(board: board, id: id))
    }

    @Test(arguments: [
        ("https://jobs.lever.co/stratum3/813b5aeb-dadf-4926-9205-1e26290b8c82", "stratum3"),
        ("https://jobs.lever.co/stratum3/813b5aeb-dadf-4926-9205-1e26290b8c82/apply", "stratum3"),
    ])
    func leverURLGivesSiteAndId(url: String, site: String) throws {
        #expect(try Self.detect(url) == .lever(site: site, id: "813b5aeb-dadf-4926-9205-1e26290b8c82"))
    }

    @Test(arguments: [
        ("https://jobs.ashbyhq.com/variantly/03bce1ad-e59b-4037-bb1c-32e4c3fb7916", "variantly"),
        ("https://jobs.ashbyhq.com/variantly/03bce1ad-e59b-4037-bb1c-32e4c3fb7916/application", "variantly"),
    ])
    func ashbyURLGivesBoardAndId(url: String, board: String) throws {
        #expect(try Self.detect(url) == .ashby(board: board, id: "03bce1ad-e59b-4037-bb1c-32e4c3fb7916"))
    }

    @Test func ashbyBoardNameIsPercentDecoded() throws {
        let url = "https://jobs.ashbyhq.com/Quickwrite%20Platform%20Inc/acaeff20-fc22-42fa-b9b1-f960d9d86601"
        #expect(try Self.detect(url) == .ashby(board: "Quickwrite Platform Inc", id: "acaeff20-fc22-42fa-b9b1-f960d9d86601"))
    }

    @Test(arguments: [
        "https://www.linkedin.com/jobs/view/4012345678",
        "https://hh.ru/vacancy/123456789",
        "https://careers.tidewell.ph/jobs/2ebb48b9-16be-40aa-9fa7-6df9bb3adaff",
        "https://job-boards.greenhouse.io/sandboxly",
        "https://job-boards.greenhouse.io/sandboxly/jobs/not-a-number",
        "https://jobs.lever.co/stratum3",
        "https://jobs.lever.co/stratum3/not-a-uuid",
        "https://jobs.eu.lever.co/stratum3/813b5aeb-dadf-4926-9205-1e26290b8c82",
        "https://jobs.ashbyhq.com/variantly",
        "https://evil.example/job-boards.greenhouse.io/sandboxly/jobs/4005254009",
    ])
    func anythingElseIsHTML(url: String) throws {
        #expect(try Self.detect(url) == .html)
    }
}
