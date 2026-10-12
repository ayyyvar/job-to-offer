import Core
import Foundation
import Testing

@Suite struct SeenJobsExporterTests {
    static let baseFields: Set = [
        "title", "company", "url", "first_seen", "posted_date", "deadline",
        "fit", "status", "portal", "source", "location",
    ]
    static let rankFields: Set = [
        "rank_score", "rank_verdict", "rank_date", "location_verdict", "language_gate", "strengths", "gaps",
    ]

    static func unranked() -> TrackedJob {
        TrackedJob(title: "ML Engineer", company: "Beta", url: "https://boards.greenhouse.io/beta/jobs/4012345",
                   portal: "greenhouse", firstSeen: "2026-09-27", fit: "medium")
    }

    static func ranked() -> TrackedJob {
        let job = TrackedJob(title: "Senior AI Engineer", company: "Acme Corp", url: "https://jobs.lever.co/acme/1",
                             portal: "lever", firstSeen: "2026-09-27", fit: "high")
        job.location = "Remote"
        job.rankScore = 80
        job.rankVerdict = "Strong Fit"
        job.rankDate = "2026-09-27"
        job.locationVerdict = "PASS"
        job.languageGate = "PASS"
        job.strengths = ["Production RAG in Python"]
        job.gaps = ["No team-lead experience"]
        return job
    }

    static func entries(_ jobs: [TrackedJob]) throws -> [String: [String: Any]] {
        let object = try JSONSerialization.jsonObject(with: SeenJobsExporter.json(jobs), options: [.fragmentsAllowed])
        let top = try #require(object as? [String: Any])
        #expect(Set(top.keys) == ["seen"])
        return try #require(top["seen"] as? [String: [String: Any]])
    }

    @Test func entriesAreKeyedByTheCanonicalJobKey() throws {
        let seen = try Self.entries([Self.ranked(), Self.unranked()])
        #expect(Set(seen.keys) == ["acme-corp_senior-ai-engineer", "beta_ml-engineer"])
        #expect(seen.keys.allSatisfy(JobKey.isCanonical))
    }

    @Test func rankedEntryHasTheBaseAndRankFieldNames() throws {
        let entry = try #require(try Self.entries([Self.ranked()])["acme-corp_senior-ai-engineer"])
        #expect(Set(entry.keys) == Self.baseFields.union(Self.rankFields))
        #expect(entry["status"] as? String == "ranked")
        #expect(entry["rank_score"] as? Int == 80)
        #expect(entry["rank_verdict"] as? String == "Strong Fit")
        #expect(entry["source"] as? String == "job-to-offer")
        #expect(entry["strengths"] as? [String] == ["Production RAG in Python"])
    }

    @Test func unrankedEntryIsNewWithNullDatesAndNoRankFields() throws {
        let entry = try #require(try Self.entries([Self.unranked()])["beta_ml-engineer"])
        #expect(Set(entry.keys) == Self.baseFields)
        #expect(entry["status"] as? String == "new")
        // null = "the posting states none"; an absent key would mean "predates the field".
        #expect(entry["deadline"] is NSNull)
        #expect(entry["posted_date"] is NSNull)
        #expect(entry["location"] is NSNull)
    }

    @Test func languageNoteIsWrittenOnlyWhenPresent() throws {
        let job = Self.ranked()
        job.languageGate = "FLAG"
        job.languageNote = "English: native speaker required"
        let entry = try #require(try Self.entries([job])["acme-corp_senior-ai-engineer"])
        #expect(entry["language_note"] as? String == "English: native speaker required")
    }

    @Test func outputIsUTF8WithUnescapedSlashesAndATrailingNewline() throws {
        let job = Self.unranked()
        job.location = "Алматы"
        let text = String(decoding: try SeenJobsExporter.json([job]), as: UTF8.self)
        #expect(text.contains("Алматы"))
        #expect(text.contains("https://boards.greenhouse.io/beta/jobs/4012345"))
        #expect(text.hasSuffix("\n"))
    }

    @Test func exportDecodesBackToTheSameEntries() throws {
        let jobs = [Self.ranked(), Self.unranked()]
        let decoded = try SeenJobsExporter.decode(SeenJobsExporter.json(jobs))
        #expect(decoded == Dictionary(uniqueKeysWithValues: jobs.map { ($0.key, SeenJobEntry($0)) }))
    }

    /// One entry per shape in the repo's seen_jobs.json: ranked, ranked with a language note,
    /// new (nulls), skipped with only a location verdict.
    @Test func repoShapedSeenJobsFileDecodesWithoutError() throws {
        let seen = try SeenJobsExporter.decode(Fixture.load("SeenJobs/seen_jobs_2026-10-11.json"))
        #expect(seen.count == 4)
        #expect(seen.values.filter { $0.rankScore != nil }.count == 2)
        let ranked = try #require(seen.values.first { $0.company == "Corvel AI" && $0.rankScore == 80 })
        #expect(ranked.rankVerdict == "Strong Fit")
        #expect(ranked.gaps?.count == 3)
        #expect(seen["orbis-bank_ml-engineer"]?.languageNote?.hasPrefix("Posting requires Kazakh") == true)
        #expect(seen["keepsafe_backend-engineer"]?.postedDate == nil)
        #expect(seen["lattice-motion_senior-ai-engineer"]?.locationVerdict == "FAIL")
    }
}
