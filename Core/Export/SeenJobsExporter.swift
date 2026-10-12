import Foundation

/// One `seen_jobs.json` entry: the `/scrape` base fields plus the `/rank` extension.
public struct SeenJobEntry: Codable, Equatable, Sendable {
    public var title: String
    public var company: String
    public var url: String
    public var firstSeen: String
    public var postedDate: String?
    public var deadline: String?
    public var fit: String
    /// `seen_jobs.json` vocabulary (`new` / `skipped` / `ranked` / `expired`), not `TrackerStatus`.
    public var status: String
    public var portal: String?
    public var source: String?
    public var location: String?
    public var rankScore: Int?
    public var rankVerdict: String?
    public var rankDate: String?
    public var locationVerdict: String?
    public var languageGate: String?
    public var languageNote: String?
    public var strengths: [String]?
    public var gaps: [String]?

    enum CodingKeys: String, CodingKey {
        case title, company, url, fit, status, portal, source, location, deadline, strengths, gaps
        case firstSeen = "first_seen", postedDate = "posted_date"
        case rankScore = "rank_score", rankVerdict = "rank_verdict", rankDate = "rank_date"
        case locationVerdict = "location_verdict", languageGate = "language_gate", languageNote = "language_note"
    }

    public init(_ job: TrackedJob) {
        let ranked = job.rankScore != nil
        title = job.title
        company = job.company
        url = job.url
        firstSeen = job.firstSeen
        postedDate = job.postedDate
        deadline = job.deadline
        fit = job.fit
        status = ranked ? "ranked" : "new"
        portal = job.portal
        source = "job-to-offer"
        location = job.location
        rankScore = job.rankScore
        rankVerdict = job.rankVerdict
        rankDate = job.rankDate
        locationVerdict = job.locationVerdict
        languageGate = job.languageGate
        languageNote = job.languageNote
        strengths = ranked ? job.strengths : nil
        gaps = ranked ? job.gaps : nil
    }

    /// Base date and location fields are written as `null` when unknown: in the repo, `null` means
    /// "the posting states none" and a missing key means "the entry predates the field".
    /// Decoding reads both as `nil`. Rank fields are written only when present.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(company, forKey: .company)
        try c.encode(url, forKey: .url)
        try c.encode(firstSeen, forKey: .firstSeen)
        try c.encode(postedDate, forKey: .postedDate)
        try c.encode(deadline, forKey: .deadline)
        try c.encode(fit, forKey: .fit)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(portal, forKey: .portal)
        try c.encodeIfPresent(source, forKey: .source)
        try c.encode(location, forKey: .location)
        try c.encodeIfPresent(rankScore, forKey: .rankScore)
        try c.encodeIfPresent(rankVerdict, forKey: .rankVerdict)
        try c.encodeIfPresent(rankDate, forKey: .rankDate)
        try c.encodeIfPresent(locationVerdict, forKey: .locationVerdict)
        try c.encodeIfPresent(languageGate, forKey: .languageGate)
        try c.encodeIfPresent(languageNote, forKey: .languageNote)
        try c.encodeIfPresent(strengths, forKey: .strengths)
        try c.encodeIfPresent(gaps, forKey: .gaps)
    }
}

/// Writes and reads `{"seen": {<job key>: {...}}}`, the `job_scraper/seen_jobs.json` shape.
public enum SeenJobsExporter {
    public static func json(_ jobs: [TrackedJob]) throws -> Data {
        let seen = Dictionary(jobs.map { ($0.key, SeenJobEntry($0)) }, uniquingKeysWith: { first, _ in first })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(["seen": seen]) + Data("\n".utf8)
    }

    public static func decode(_ data: Data) throws -> [String: SeenJobEntry] {
        try JSONDecoder().decode([String: [String: SeenJobEntry]].self, from: data)["seen"] ?? [:]
    }
}
