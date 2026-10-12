import Core
import Foundation
import Testing

@Suite struct PostingFetcherTests {
    @Test(arguments: ["ftp://example.com/job", "not a link", "mailto:hr@example.com"])
    func nonWebLinkIsRejectedWithoutAFetch(url: String) async {
        await #expect(throws: FetchError.badURL(url)) { try await PostingFetcher.fetch(url) }
    }

    @Test func binaryResponseIsRejectedInsteadOfScoredAsText() {
        let pdf = Data([0x25, 0x50, 0x44, 0x46, 0x2D, 0xFF, 0xFE, 0x00, 0xC3, 0x28])
        #expect(throws: FetchError.notText("https://example.com/jd.pdf")) {
            try PostingFetcher.page(data: pdf, url: "https://example.com/jd.pdf")
        }
    }
}
