import Core
import Foundation
import Testing

@Suite struct LeverClientTests {
    static func posting() throws -> LeverClient.Posting {
        try LeverClient.decode(Fixture.load("ATS/lever_2026-09-27.json"))
    }

    @Test func endpointIsTheSinglePostingAPI() {
        #expect(LeverClient.endpoint(site: "stratum3", id: "813b5aeb-dadf-4926-9205-1e26290b8c82").absoluteString
            == "https://api.lever.co/v0/postings/stratum3/813b5aeb-dadf-4926-9205-1e26290b8c82?mode=json")
    }

    @Test func decodeYieldsTheDocumentedFields() throws {
        let posting = try Self.posting()
        #expect(posting.text == "AI Engineer")
        #expect(posting.descriptionPlain.hasPrefix("Stratum Labs is a software development agency"))
        #expect(posting.lists.map(\.text) == ["What you'll do:", "What makes you a great fit:", "Bonus points:"])
        #expect(posting.lists[1].content.contains("<li>5+ years of overall software engineering"))
        #expect(posting.categories.location == "Vilnius, Vilniaus, Lithuania")
        #expect(posting.categories.commitment == "External")
        #expect(posting.hostedUrl == "https://jobs.lever.co/stratum3/813b5aeb-dadf-4926-9205-1e26290b8c82")
        #expect(posting.workplaceType == "remote")
    }

    @Test func fetchedPostingCarriesListsWorkplaceAndSalaryAsPlainText() throws {
        let fetched = LeverClient.posting(try Self.posting(), site: "stratum3")
        #expect(fetched.title == "AI Engineer")
        #expect(fetched.company == "stratum3")
        #expect(fetched.url == "https://jobs.lever.co/stratum3/813b5aeb-dadf-4926-9205-1e26290b8c82")
        let text = fetched.plainText
        #expect(text.hasPrefix("AI Engineer\nLocation: Vilnius, Vilniaus, Lithuania\nWorkplace: remote\nCommitment: External\nCompensation: 30-40 EUR per-hour-wage\n\n"))
        #expect(text.contains("What makes you a great fit:\n- 5+ years of overall software engineering"))
        #expect(!text.contains("<"))
        #expect(fetched.postedAt == Date(timeIntervalSince1970: 1_789_484_727.455))
    }
}
