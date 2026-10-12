#if DEBUG
import Core
import Foundation
import SwiftData

/// Screenshot data (simulator only): launch with `-mockData YES`, or keep it across relaunches with
/// `xcrun simctl spawn booted defaults write <bundle-id> mockData -bool YES`.
/// Uses an in-memory store and overwrites the App Group profile, library and boards.
enum MockData {
    static var enabled: Bool { UserDefaults.standard.bool(forKey: "mockData") }

    @MainActor static func container() -> ModelContainer {
        let container = try! SharedStore.container(inMemory: true)
        let context = container.mainContext
        seedDefaults()

        let now = Date.now
        context.insert(IncomingItem(SharedPayload(url: nil, text: posting), receivedAt: now))
        context.insert(IncomingItem(SharedPayload(url: "https://jobs.lever.co/northvale/4f1c2a90-77d1-4b8e-9a51-0c3e5d2b8f17", text: nil),
                                    receivedAt: now.addingTimeInterval(-3_600)))
        context.insert(IncomingItem(SharedPayload(url: "https://www.linkedin.com/jobs/view/4019283746",
                                                  text: "Applied Scientist, Search Ranking at Halcyon Labs. Remote, EMEA."),
                                    receivedAt: now.addingTimeInterval(-86_400)))

        let jobs: [(String, String, String, TrackerStatus, Int?, String?)] = [
            ("Senior AI Engineer", "Tidewater Analytics", "https://boards.greenhouse.io/tidewater/jobs/7741203", .interview, 82, "Strong Fit"),
            ("ML Platform Engineer", "Northvale", "https://jobs.lever.co/northvale/9b2e1d44", .applied, 71, "Good Fit"),
            ("LLM Applications Engineer", "Variantly", "https://jobs.ashbyhq.com/variantly/1a7c5e93", .applied, 64, "Good Fit"),
            ("Data Scientist, Growth", "Sandboxly", "https://boards.greenhouse.io/sandboxly/jobs/5512098", .drafted, 52, "Moderate Fit"),
            ("Staff Backend Engineer (Go)", "Quarry Systems", "https://jobs.lever.co/quarry/0c9f7e21", .rejected, 38, "Weak Fit"),
            ("AI Solutions Architect", "Brightmoor", "https://brightmoor.io/careers/ai-architect", .noResponse, 58, "Moderate Fit"),
            ("Research Engineer, Agents", "Halcyon Labs", "https://jobs.ashbyhq.com/halcyon/66e0b2f8", .offer, 88, "Strong Fit"),
        ]
        for (i, j) in jobs.enumerated() {
            let job = TrackedJob(title: j.0, company: j.1, url: j.2, portal: "mock",
                                 firstSeen: "2026-10-\(String(format: "%02d", 10 - i))", fit: "high", status: j.3)
            job.rankScore = j.4
            job.rankVerdict = j.5
            job.locationVerdict = i == 4 ? "FLAG" : "PASS"
            job.languageGate = "PASS"
            job.location = "Remote"
            job.strengths = ["4 years shipping Python LLM pipelines to production", "Evaluation harness work matches their eval-first culture"]
            job.gaps = i.isMultiple(of: 2) ? ["kubernetes", "go", "on-call experience"] : ["kubernetes", "spark"]
            job.notes = i == 0 ? "Tech screen Oct 14 with the platform lead" : ""
            if j.3 == .rejected { job.rejectionReason = "go" }
            context.insert(job)
        }
        return container
    }

    private static func seedDefaults() {
        let store = ProfileStore()
        var profile = CandidateProfile(
            regions: ["kazakhstan", "almaty", "gmt+5"],
            languages: ["english": "fluent", "russian": "native", "tatar": "native"],
            skills: SkillTiers(strong: ["python", "pytorch", "llm", "rag", "evaluation", "fastapi", "sql", "docker"],
                               moderate: ["swift", "aws", "airflow", "typescript", "kafka"],
                               weak: ["kubernetes", "go", "spark"]))
        profile.targetRoles = ["AI Engineer", "ML Engineer", "LLM Engineer"]
        store.save(profile)
        store.saveResumeText("Senior ML engineer. Python, PyTorch, RAG, evaluation.")
        store.saveLibrary([
            ExperienceItem(kind: .experience, text: "Built a RAG pipeline over 1.2M support tickets; cut median handle time by 31%"),
            ExperienceItem(kind: .experience, text: "Led an LLM eval harness used by 4 product teams; 600+ regression cases"),
            ExperienceItem(kind: .project, text: "job-to-offer: on-device posting parser and fit scorer for iOS"),
            ExperienceItem(kind: .skill, text: "python"),
            ExperienceItem(kind: .skill, text: "pytorch"),
            ExperienceItem(kind: .language, text: "English (fluent), Russian (native), Tatar (native)"),
            ExperienceItem(kind: .answer, text: "Situation: Ranking quality dropped after a model swap.\nTask: Find the cause in a week.\nAction: Built a 300-case eval set and bisected prompts.\nResult: Restored NDCG@10 to 0.71 in 5 days."),
        ])
        store.saveBoards([.greenhouse("tidewater"), .lever("northvale"), .ashby("variantly"), .greenhouse("sandboxly")])
    }

    static let posting = """
    Senior AI Engineer, Retrieval
    Tidewater Analytics. Remote (worldwide). Full-time. $140,000 - $175,000.

    About the role
    You will build retrieval and ranking systems for our analytics assistant, from data pipelines to evaluation.

    Requirements
    - 5+ years of software engineering, 2+ years with LLM or search systems in production
    - Strong Python; experience with PyTorch and vector databases
    - Experience designing offline and online evaluation for ML systems
    - Fluent English; you will work with customers in the US and EU
    - Kubernetes and AWS are a plus

    We hire anywhere and offer visa sponsorship for relocation to our Lisbon hub if you want it.
    Apply by 2026-11-15.
    """
}
#endif
