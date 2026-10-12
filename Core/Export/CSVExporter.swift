/// Writes rows for `job_search_tracker.csv`: RFC 4180 quoting, LF line ends, no BOM
/// (the repo file uses LF and `tools/rank_state.py` reads it with `csv.DictReader`).
public enum CSVExporter {
    public static let header = [
        "date", "company", "sector", "role", "role_type", "channel", "status", "contact_person",
        "fit_rating", "notes", "cv_file", "cover_letter_file", "source", "deadline",
    ]

    /// With `includeHeader: false` the result can be appended to an existing tracker file.
    public static func csv(_ jobs: [TrackedJob], includeHeader: Bool = true) -> String {
        let rows = (includeHeader ? [header] : []) + jobs.map(fields)
        return rows.map { $0.map(escape).joined(separator: ",") + "\n" }.joined()
    }

    static func fields(_ job: TrackedJob) -> [String] {
        [
            job.date, job.company, job.sector, job.title, job.roleType, job.channel,
            job.trackerStatus?.rawValue ?? job.status, job.contactPerson,
            job.rankScore.map(String.init) ?? "", // bare number: /upskill does arithmetic on it
            job.notes, job.cvFile, job.coverLetterFile, job.url, job.deadline ?? "",
        ]
    }

    static func escape(_ field: String) -> String {
        // `\.isNewline`, not "\n": "\r\n" is one Character that equals neither "\n" nor "\r".
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacing("\"", with: "\"\"") + "\""
    }
}

extension String {
    /// Every line break (LF, CR, CRLF, U+2028) → one space. Tracker notes stay on one line: /outcome edits rows line by line.
    public var singleLine: String { split(whereSeparator: \.isNewline).joined(separator: " ") }
}
