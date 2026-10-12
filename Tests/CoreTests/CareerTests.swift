@testable import Core
import Foundation
import Testing

@Suite struct CareerTests {
    @Test func oldProfileJSONWithoutTargetRolesStillDecodes() throws {
        let old = #"{"regions":["kazakhstan"],"languages":{"english":"fluent"},"skills":{"strong":[],"moderate":[],"weak":["rust"]}}"#
        let profile = try JSONDecoder().decode(CandidateProfile.self, from: Data(old.utf8))
        #expect(profile.targetRoles.isEmpty)
        #expect(profile.regions == ["kazakhstan"])
    }

    @Test func addingASkillMovesItOutOfWeakOnce() {
        var profile = CandidateProfile(regions: [], languages: [:], skills: SkillTiers(strong: [], moderate: [], weak: ["rust"]))
        profile.addSkill("Rust")
        profile.addSkill("rust")
        #expect(profile.skills.moderate == ["rust"])
        #expect(profile.skills.weak.isEmpty)
    }

    @Test func linkedInSearchLinkIsRemoteAndNewestFirst() {
        let url = JobSearch.linkedIn(role: "AI Engineer")
        #expect(url.absoluteString == "https://www.linkedin.com/jobs/search/?keywords=AI%20Engineer&f_WT=2&sortBy=DD")
    }

    @Test func weakSpotsCountRepeatsAcrossJobsAndSkipIgnored() {
        let spots = WeakSpots.rank(gaps: [["Kubernetes", "Go"], ["kubernetes"], ["Go "]], reasons: ["Kubernetes"], ignored: ["go"])
        #expect(spots.first == WeakSpots.Spot(name: "kubernetes", count: 3))
        #expect(!spots.contains { $0.name == "go" })
    }

    @Test func trackedJobStartsWithoutRejectionReason() {
        let job = TrackedJob(title: "AI Engineer", company: "Acme", url: "https://acme.dev/1", portal: "web", firstSeen: "2026-10-08", fit: "high")
        #expect(job.rejectionReason.isEmpty)
        #expect(job.ignoredGaps.isEmpty)
    }

    @Test func starPromptMatchesTheGoldenAndKeepsTheStoryOutOfInstructions() throws {
        let story = "At Acme the crawler missed sources. I built a benchmark."
        let rendered = try PromptRenderer.star(story: story)
        #expect(!rendered.instructions.contains(story))
        #expect(rendered.transcript == (try Fixture.string("Golden/star_prompt.txt")))
    }

    @Test func fakeClientReturnsTheStarFixture() async throws {
        var fake = try await ParseModelTests.fake()
        fake.star = StarStory(situation: "s", task: "t", action: "a", result: "r", missing: ["a number in the result"])
        #expect(try await fake.star(story: "x").missing == ["a number in the result"])
    }
}
