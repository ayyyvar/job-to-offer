import Foundation

/// URL → `FetchedPosting`: the ATS JSON API when the URL points at one, else the page as HTML.
/// One fetch per call; nothing here follows links (CLAUDE.md rule 7).
public enum PostingFetcher {
    @Sendable public static func fetch(_ urlString: String) async throws -> FetchedPosting {
        guard let url = URL(string: urlString), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            throw FetchError.badURL(urlString)
        }
        switch ATSDetector.detect(url) {
        case .greenhouse(let board, let id): return try await GreenhouseClient.fetch(board: board, id: id)
        case .lever(let site, let id): return try await LeverClient.fetch(site: site, id: id)
        case .ashby(let board, let id): return try await AshbyClient.fetch(board: board, id: id)
        case .html:
            return try page(data: try await HTTP.get(url, session: .shared), url: urlString)
        }
    }

    /// A page that is not UTF-8 text (a PDF, an image) is rejected instead of scored as garbage.
    public static func page(data: Data, url: String) throws -> FetchedPosting {
        guard let html = String(data: data, encoding: .utf8) else { throw FetchError.notText(url) }
        return HTMLText.posting(html: html, url: url)
    }
}
