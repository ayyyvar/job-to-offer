import Core
import Testing

@Suite struct TrackedJobTests {
    static func job() -> TrackedJob {
        TrackedJob(title: "Senior AI Engineer", company: "Acme Corp", url: "https://jobs.lever.co/acme/1",
                   portal: "lever", firstSeen: "2026-09-27", fit: "high")
    }

    @Test func keyIsTheCanonicalJobKey() {
        #expect(Self.job().key == "acme-corp_senior-ai-engineer")
    }

    @Test func newJobIsDraftedOnItsFirstSeenDate() {
        let job = Self.job()
        #expect(job.trackerStatus == .drafted)
        #expect(job.status == "drafted")
        #expect(job.date == "2026-09-27")
    }

    @Test func settingTheTypedStatusStoresTheCanonicalString() {
        let job = Self.job()
        job.trackerStatus = .noResponse
        #expect(job.status == "no_response")
    }

    @Test func legacyStoredStatusReadsAsTheCanonicalValue() {
        let job = Self.job()
        job.status = "offer declined"
        #expect(job.trackerStatus == .offerDeclined)
    }

    @Test func unknownStoredStatusReadsAsNil() {
        let job = Self.job()
        job.status = "ranked"
        #expect(job.trackerStatus == nil)
    }
}
