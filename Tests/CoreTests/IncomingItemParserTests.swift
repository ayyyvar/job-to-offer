import Core
import Foundation
import Testing

@Suite struct IncomingItemParserTests {
    static let url = "https://job-boards.greenhouse.io/sandboxly/jobs/4005254009"

    @Test func urlPayloadGivesTheURL() async throws {
        let provider = NSItemProvider(object: try #require(URL(string: Self.url)) as NSURL)
        #expect(await IncomingItemParser.parse([provider]) == SharedPayload(url: Self.url, text: nil))
    }

    @Test func pastedURLArrivingAsTextIsParsedAsAURL() async {
        let provider = NSItemProvider(object: "  \(Self.url)\n" as NSString)
        #expect(await IncomingItemParser.parse([provider]) == SharedPayload(url: Self.url, text: nil))
    }

    @Test func textWithAURLAndADescriptionKeepsBoth() async {
        let text = "Senior Applied AI Engineer at Zapp.new, remote: \(Self.url) apply by Friday"
        #expect(await IncomingItemParser.parse([NSItemProvider(object: text as NSString)]) == SharedPayload(url: Self.url, text: text))
    }

    @Test func plainTextWithoutAURLKeepsTheText() async {
        let text = "Senior AI Engineer\nRequirements\n- Python"
        #expect(await IncomingItemParser.parse([NSItemProvider(object: text as NSString)]) == SharedPayload(url: nil, text: text))
    }

    @Test func urlAndTitleProvidersFromSafariGiveTheURLAndTheText() async throws {
        let providers = [NSItemProvider(object: try #require(URL(string: Self.url)) as NSURL),
                         NSItemProvider(object: "Senior Applied AI Engineer - Zapp.new" as NSString)]
        #expect(await IncomingItemParser.parse(providers) == SharedPayload(url: Self.url, text: "Senior Applied AI Engineer - Zapp.new"))
    }

    @Test(arguments: ["", "   \n"])
    func emptyPayloadGivesNil(text: String) async {
        #expect(await IncomingItemParser.parse([NSItemProvider(object: text as NSString)]) == nil)
        #expect(await IncomingItemParser.parse([]) == nil)
    }

    @Test func nonWebURLIsKeptAsTextOnly() async {
        #expect(await IncomingItemParser.parse([NSItemProvider(object: "mailto:hr@example.com" as NSString)])
            == SharedPayload(url: nil, text: "mailto:hr@example.com"))
    }
}
