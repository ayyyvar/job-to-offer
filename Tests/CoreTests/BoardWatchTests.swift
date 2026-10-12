@testable import Core
import Foundation
import Testing

@Suite struct BoardWatchTests {
    @Test(arguments: [
        ("https://boards.greenhouse.io/acme", BoardWatch.Board.greenhouse("acme")),
        ("https://job-boards.eu.greenhouse.io/quantaops/jobs/123", .greenhouse("quantaops")),
        ("https://jobs.lever.co/paperwave", .lever("paperwave")),
        ("https://jobs.ashbyhq.com/variantly/abc", .ashby("variantly")),
    ])
    func boardFromURL(url: String, board: BoardWatch.Board) {
        #expect(BoardWatch.Board(url: url) == board)
    }

    @Test func otherSitesAreNotBoards() {
        #expect(BoardWatch.Board(url: "https://www.linkedin.com/jobs/view/1") == nil)
    }

    @Test func greenhouseListDecodes() throws {
        let listings = try BoardWatch.listings(.greenhouse("sandboxly"), data: Fixture.load("ATS/greenhouse_list_2026-10-08.json"))
        #expect(listings.count == 7)
        #expect(listings.allSatisfy { $0.url.hasPrefix("https://") && !$0.title.isEmpty })
    }

    @Test func leverListDecodes() throws {
        let listings = try BoardWatch.listings(.lever("paperwave"), data: Fixture.load("ATS/lever_list_2026-10-08.json"))
        #expect(listings.count == 13)
        #expect(listings.contains { $0.title == "B2B Demand Generation Leader" })
    }

    @Test func ashbyListDecodes() throws {
        let listings = try BoardWatch.listings(.ashby("variantly"), data: Fixture.load("ATS/ashby_2026-09-27.json"))
        #expect(!listings.isEmpty)
    }

    @Test func titleMatchesWhenEveryRoleWordIsPresent() {
        let l = { BoardWatch.Listing(title: $0, url: "https://x/\($0)", location: "", company: "x") }
        let picked = BoardWatch.matching([l("Senior AI Engineer"), l("Staff ML Engineer"), l("AI Product Manager")],
                                         roles: ["AI Engineer", "LLM Engineer"])
        #expect(picked.map(\.title) == ["Senior AI Engineer"])
    }

    @Test func boardsFromSeenJobsAreUniqueAndSorted() {
        let urls = ["https://jobs.lever.co/b/1", "https://boards.greenhouse.io/a/jobs/2", "https://jobs.lever.co/b/3", "https://x.com"]
        #expect(BoardWatch.boards(fromURLs: urls) == [.greenhouse("a"), .lever("b")])
    }

    @Test func boardsRoundTripThroughProfileStore() {
        let suite = "BoardWatchTests.\(UUID().uuidString)"
        let store = ProfileStore(suiteName: suite)
        defer { store.defaults.removePersistentDomain(forName: suite) }
        #expect(store.loadBoards().isEmpty)
        store.saveBoards([.ashby("brevia"), .greenhouse("acme")])
        #expect(store.loadBoards() == [.ashby("brevia"), .greenhouse("acme")])
    }
}
