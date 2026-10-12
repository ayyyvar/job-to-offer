import SwiftData

/// One job in the tracker. The columns mirror `job_search_tracker.csv` and the `seen_jobs.json`
/// entry, so both exports are plain mappings. Dates are `YYYY-MM-DD` strings, as in those files.
@Model
public final class TrackedJob {
    @Attribute(.unique) public var key: String
    public var title: String
    public var company: String
    public var url: String
    public var location: String?
    /// Where the posting came from, e.g. `greenhouse`, `lever`, `ashby`, or the URL host.
    public var portal: String
    public var firstSeen: String
    public var postedDate: String?
    public var deadline: String?
    /// `high` / `medium` / `low`, as in `seen_jobs.json`.
    public var fit: String

    // Tracker columns
    public var date: String
    /// Tracker status string; use `trackerStatus` for the typed value.
    public var status: String
    public var sector = ""
    public var roleType = ""
    public var channel = ""
    public var contactPerson = ""
    public var notes = ""
    public var cvFile = ""
    public var coverLetterFile = ""

    // Ranking: `rankScore == nil` means the job is not scored yet.
    public var rankScore: Int?
    public var rankVerdict: String?
    public var rankDate: String?
    public var locationVerdict: String?
    public var languageGate: String?
    public var languageNote: String?
    public var strengths: [String] = []
    public var gaps: [String] = []
    /// What the user thinks was missing, for a rejected job.
    public var rejectionReason = ""
    /// Gaps the user chose to ignore; `WeakSpots` skips them.
    public var ignoredGaps: [String] = []

    public init(title: String, company: String, url: String, portal: String, firstSeen: String, fit: String,
                status: TrackerStatus = .drafted) {
        key = JobKey.make(company: company, title: title, url: url)
        self.title = title
        self.company = company
        self.url = url
        self.portal = portal
        self.firstSeen = firstSeen
        self.fit = fit
        date = firstSeen
        self.status = status.rawValue
    }

    /// `nil` when the stored string is not in the tracker vocabulary. Setting `nil` changes nothing.
    public var trackerStatus: TrackerStatus? {
        get { TrackerStatus(rawValue: status) }
        set { if let newValue { status = newValue.rawValue } }
    }
}
