import Foundation

public enum ATSSource: Equatable, Sendable {
    case greenhouse(board: String, id: String)
    case lever(site: String, id: String)
    case ashby(board: String, id: String)
    case html
}

/// Maps a posting URL to the ATS JSON API that serves it. Hosts come from real URLs
/// in `seen_jobs.json`. EU Lever (`jobs.eu.lever.co`) needs `api.eu.lever.co`; not handled yet, so `.html`.
public enum ATSDetector {
    static let greenhouseHosts: Set = [
        "boards.greenhouse.io", "job-boards.greenhouse.io", "boards.eu.greenhouse.io", "job-boards.eu.greenhouse.io",
    ]

    public static func detect(_ url: URL) -> ATSSource {
        let host = url.host()?.lowercased() ?? ""
        let path = url.pathComponents.filter { $0 != "/" }
        switch host {
        case _ where greenhouseHosts.contains(host):
            if path.count >= 3, path[1] == "jobs", path[2].allSatisfy(\.isASCII), Int(path[2]) != nil {
                return .greenhouse(board: path[0], id: path[2])
            }
        case "jobs.lever.co":
            if path.count >= 2, UUID(uuidString: path[1]) != nil { return .lever(site: path[0], id: path[1]) }
        case "jobs.ashbyhq.com":
            if path.count >= 2, UUID(uuidString: path[1]) != nil { return .ashby(board: path[0], id: path[1]) }
        default:
            break
        }
        return .html
    }
}
