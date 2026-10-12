import Core
import Testing

@Suite struct CSVExporterTests {
    static let header = "date,company,sector,role,role_type,channel,status,contact_person,fit_rating,notes,cv_file,cover_letter_file,source,deadline"

    static func job() -> TrackedJob {
        let job = TrackedJob(title: "Senior AI Engineer", company: "Acme Corp", url: "https://jobs.lever.co/acme/1",
                             portal: "lever", firstSeen: "2026-09-27", fit: "high")
        job.channel = "portal"
        job.rankScore = 80
        job.deadline = "2026-10-15"
        return job
    }

    @Test func headerIsTheExact14ColumnTrackerHeader() {
        #expect(CSVExporter.header.joined(separator: ",") == Self.header)
        #expect(CSVExporter.header.count == 14)
    }

    @Test func headerMatchesTheRealTrackerFile() throws {
        let tracker = try Fixture.string("Tracker/job_search_tracker_2026-10-11.csv")
        #expect(tracker.split(separator: "\n").first.map(String.init) == Self.header)
    }

    @Test func rowPutsEachFieldInItsColumn() throws {
        let rows = CSVParser.parse(CSVExporter.csv([Self.job()]))
        #expect(rows.count == 2)
        let row = Dictionary(uniqueKeysWithValues: zip(rows[0], rows[1]))
        #expect(row["date"] == "2026-09-27")
        #expect(row["company"] == "Acme Corp")
        #expect(row["role"] == "Senior AI Engineer")
        #expect(row["channel"] == "portal")
        #expect(row["status"] == "drafted")
        #expect(row["fit_rating"] == "80")
        #expect(row["source"] == "https://jobs.lever.co/acme/1")
        #expect(row["deadline"] == "2026-10-15")
        #expect(row["notes"] == "")
    }

    @Test func unscoredJobHasAnEmptyFitRating() {
        let job = Self.job()
        job.rankScore = nil
        #expect(CSVParser.parse(CSVExporter.csv([job], includeHeader: false))[0][8] == "")
    }

    @Test func legacyStatusIsWrittenInTheCanonicalSpelling() {
        let job = Self.job()
        job.status = "no response"
        #expect(CSVParser.parse(CSVExporter.csv([job], includeHeader: false))[0][6] == "no_response")
    }

    @Test func notesWithACommaAQuoteAndANewlineRoundTrip() {
        let job = Self.job()
        job.notes = "rejected, \"no feedback\"\nsecond line"
        let rows = CSVParser.parse(CSVExporter.csv([job]))
        #expect(rows.count == 2)
        #expect(rows[1].count == 14)
        #expect(rows[1][9] == job.notes)
    }

    @Test func notesWithCRLFAreQuoted() {
        // "\r\n" is one Character, equal to neither "\n" nor "\r" (review finding 6).
        let job = Self.job()
        job.notes = "line one\r\nline two"
        let rows = CSVParser.parse(CSVExporter.csv([job], includeHeader: false))
        #expect(rows.count == 1)
        #expect(rows[0].count == 14)
    }

    @Test(arguments: ["a\nb", "a\r\nb", "a\rb", "a\u{2028}b"])
    func singleLineReplacesEveryLineBreakWithASpace(text: String) {
        #expect(text.singleLine == "a b")
    }

    @Test func outputUsesLFAndEndsWithANewline() {
        let csv = CSVExporter.csv([Self.job(), Self.job()])
        #expect(!csv.contains("\r"))
        #expect(csv.hasSuffix("\n"))
        #expect(csv.split(separator: "\n").count == 3)
    }

    @Test func withoutHeaderTheOutputIsReadyToAppend() {
        let csv = CSVExporter.csv([Self.job()], includeHeader: false)
        #expect(!csv.hasPrefix("date,"))
        #expect(CSVParser.parse(csv).count == 1)
    }
}
