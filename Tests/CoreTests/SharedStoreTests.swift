@testable import Core
import Foundation
import SwiftData
import Testing

@MainActor
@Suite struct SharedStoreTests {
    @Test func appGroupIDComesFromTheInfoPlistKey() {
        #expect(SharedStore.appGroupID(info: ["JobToOfferAppGroupID": "group.org.fork.job-to-offer"]) == "group.org.fork.job-to-offer")
    }

    @Test(arguments: [[:], ["JobToOfferAppGroupID": ""]] as [[String: String]])
    func appGroupIDFallsBackToTheExampleIDWithoutTheKey(info: [String: String]) {
        #expect(SharedStore.appGroupID(info: info) == "group.com.example.job-to-offer")
    }

    static func evaluation(eligibility: VisaStance = .sponsors, band scores: [Int] = [90, 80, 70, 80]) throws -> Evaluation {
        var posting = JobPosting.sample(visaSponsorship: eligibility)
        posting.company = "Zapp.new"
        posting.deadline = "2026-10-15"
        let dims = DimensionScores(technical: scores[0], experience: scores[1], behavioral: scores[2], career: scores[3],
                                   strengths: ["Python"], gaps: ["No team lead"])
        let fetched = FetchedPosting(title: "Senior Applied AI Engineer", company: "sandboxly",
                                     url: "https://job-boards.greenhouse.io/sandboxly/jobs/4005254009", plainText: "",
                                     postedAt: try Date("2025-06-25T04:17:58Z", strategy: .iso8601))
        return Evaluation(fetched: fetched, posting: posting, scores: dims,
                          fit: Scoring.evaluate(scores: dims, gates: Gates.run(posting, profile: .fixture)), profile: .fixture)
    }

    @Test func incomingItemWrittenInOneContextIsVisibleInAnother() throws {
        let container = try SharedStore.container(inMemory: true)
        let writer = ModelContext(container)
        writer.insert(IncomingItem(SharedPayload(url: "https://jobs.lever.co/a/1", text: nil)))
        try writer.save()
        let items = try ModelContext(container).fetch(FetchDescriptor<IncomingItem>())
        #expect(items.map(\.url) == ["https://jobs.lever.co/a/1"])
    }

    @Test func evaluationBecomesATrackerRowWithRepoConventions() throws {
        let today = try Date("2026-09-27T10:00:00+05:00", strategy: .iso8601)
        let job = TrackedJob(try Self.evaluation(), sourceURL: nil, today: today, timeZone: TimeZone(identifier: "Asia/Almaty")!)
        #expect(job.key == "sandboxly_senior-ai-engineer") // board token + extracted title, like /scrape
        #expect(job.company == "sandboxly")
        #expect(job.url == "https://job-boards.greenhouse.io/sandboxly/jobs/4005254009")
        #expect(job.portal == "greenhouse")
        #expect(job.firstSeen == "2026-09-27")
        #expect(job.date == "2026-09-27")
        #expect(job.postedDate == "2025-06-25")
        #expect(job.deadline == "2026-10-15")
        #expect(job.rankScore == 82)
        #expect(job.rankVerdict == "Strong Fit")
        #expect(job.rankDate == "2026-09-27")
        #expect(job.fit == "high")
        #expect(job.locationVerdict == "PASS")
        #expect(job.languageGate == "PASS")
        #expect(job.strengths == ["Python"])
        #expect(job.trackerStatus == .drafted)
    }

    @Test func eligibilityFailIsExportedAsLocationFailWithTheScoreBand() throws {
        // rank_state.py keeps rank_verdict = band(score) and vetoes through location_verdict /
        // language_gate; its Location rule already fails on citizenship or clearance.
        let job = TrackedJob(try Self.evaluation(eligibility: .clearanceRequired), sourceURL: nil, today: .now, timeZone: .current)
        #expect(job.locationVerdict == "FAIL")
        #expect(job.rankVerdict == "Strong Fit")
        #expect(job.fit == "low")
    }

    @Test(arguments: [([60, 60, 60, 60], "high"), ([50, 50, 50, 50], "medium"), ([40, 40, 40, 40], "low")])
    func fitFollowsTheBand(scores: [Int], fit: String) throws {
        let job = TrackedJob(try Self.evaluation(band: scores), sourceURL: nil, today: .now, timeZone: .current)
        #expect(job.fit == fit)
    }

    @Test func addingANewJobInsertsIt() throws {
        let context = ModelContext(try SharedStore.container(inMemory: true))
        let job = TrackedJob(try Self.evaluation(), sourceURL: nil, today: .now, timeZone: .current)
        #expect(try SharedStore.add(job, to: context) == .added)
        #expect(try context.fetchCount(FetchDescriptor<TrackedJob>()) == 1)
    }

    @Test func addingTheSameKeyTwiceReportsTheExistingRowAndKeepsIt() throws {
        let context = ModelContext(try SharedStore.container(inMemory: true))
        let first = TrackedJob(try Self.evaluation(), sourceURL: nil, today: .now, timeZone: .current)
        first.notes = "applied via portal"
        _ = try SharedStore.add(first, to: context)
        let again = TrackedJob(try Self.evaluation(), sourceURL: nil, today: .now, timeZone: .current)
        guard case .alreadyTracked(let existing) = try SharedStore.add(again, to: context) else {
            Issue.record("expected alreadyTracked"); return
        }
        #expect(existing.notes == "applied via portal")
        #expect(try context.fetchCount(FetchDescriptor<TrackedJob>()) == 1)
    }
}
