import Core
import Foundation
import Testing

/// Live calls to the public ATS APIs. Each test reads its board from the environment and is skipped
/// without it, so the repo names no real board:
///
///     JOBSCOUT_GREENHOUSE_BOARD=<token> JOBSCOUT_LEVER_SITE=<site> JOBSCOUT_ASHBY_BOARD=<board> \
///     swift test --filter LiveATSTests
///
/// Each test picks a current job from the board list, so an expired posting cannot break it.
@Suite(.tags(.network))
struct LiveATSTests {
    static let env = ProcessInfo.processInfo.environment
    static let greenhouse = env["JOBSCOUT_GREENHOUSE_BOARD"] ?? ""
    static let lever = env["JOBSCOUT_LEVER_SITE"] ?? ""
    static let ashby = env["JOBSCOUT_ASHBY_BOARD"] ?? ""

    static func get(_ string: String) async throws -> Data {
        try await URLSession.shared.data(from: try #require(URL(string: string))).0
    }

    @Test(.enabled(if: !greenhouse.isEmpty, "set JOBSCOUT_GREENHOUSE_BOARD"))
    func greenhouseLiveCallGivesAPosting() async throws {
        struct List: Decodable { struct Job: Decodable { let id: Int }; let jobs: [Job] }
        let list = try JSONDecoder().decode(List.self, from: try await Self.get("https://boards-api.greenhouse.io/v1/boards/\(Self.greenhouse)/jobs"))
        let id = try #require(list.jobs.first).id
        let posting = try await GreenhouseClient.fetch(board: Self.greenhouse, id: String(id))
        #expect(!posting.title.isEmpty)
        #expect(posting.plainText.count > 200)
    }

    @Test(.enabled(if: !lever.isEmpty, "set JOBSCOUT_LEVER_SITE"))
    func leverLiveCallGivesAPosting() async throws {
        struct Item: Decodable { let id: String; let descriptionPlain: String }
        let list = try JSONDecoder().decode([Item].self, from: try await Self.get("https://api.lever.co/v0/postings/\(Self.lever)?mode=json"))
        // Skip placeholders such as ".INTERNAL TALENT POOL", which have an empty description.
        let id = try #require(list.first { !$0.descriptionPlain.isEmpty }).id
        let posting = try await LeverClient.fetch(site: Self.lever, id: id)
        #expect(!posting.title.isEmpty)
        #expect(posting.plainText.count > 200)
    }

    @Test(.enabled(if: !ashby.isEmpty, "set JOBSCOUT_ASHBY_BOARD"))
    func ashbyLiveCallGivesAPosting() async throws {
        let board = try AshbyClient.decode(try await Self.get(AshbyClient.endpoint(board: Self.ashby).absoluteString))
        let id = try #require(board.jobs.first).id
        let posting = try await AshbyClient.fetch(board: Self.ashby, id: id)
        #expect(!posting.title.isEmpty)
        #expect(posting.plainText.count > 200)
    }

    @Test(.enabled(if: !greenhouse.isEmpty, "set JOBSCOUT_GREENHOUSE_BOARD"))
    func postingFetcherRoutesAGreenhouseURLToTheJSONAPI() async throws {
        struct List: Decodable { struct Job: Decodable { let absolute_url: String }; let jobs: [Job] }
        let list = try JSONDecoder().decode(List.self, from: try await Self.get("https://boards-api.greenhouse.io/v1/boards/\(Self.greenhouse)/jobs"))
        let url = try #require(list.jobs.first).absolute_url
        let posting = try await PostingFetcher.fetch(url)
        #expect(posting.company == Self.greenhouse) // board token: the JSON path, not the HTML page
    }

    @Test(.enabled(if: !greenhouse.isEmpty && !lever.isEmpty && !ashby.isEmpty, "set all three board variables"))
    func boardSearchFindsEngineerRolesOnLiveBoards() async throws {
        let boards: [BoardWatch.Board] = [.greenhouse(Self.greenhouse), .lever(Self.lever), .ashby(Self.ashby)]
        let found = await BoardWatch.search(boards, roles: ["Engineer"])
        print("live board search: \(found.count) matches", found.prefix(5).map(\.title))
        #expect(!found.isEmpty)
    }
}
