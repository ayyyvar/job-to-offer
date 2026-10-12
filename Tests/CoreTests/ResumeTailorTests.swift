@testable import Core
import Foundation
import Testing

@Suite struct ResumeTailorTests {
    @Test func bulletLinesBecomeExperienceItems() {
        let text = "Jane Doe\nExperience\n- Built a RAG pipeline\n• Led 3 engineers\n* Shipped iOS app\nPlain line"
        let items = ExperienceItem.bullets(in: text)
        #expect(items.map(\.text) == ["Built a RAG pipeline", "Led 3 engineers", "Shipped iOS app"])
        #expect(items.allSatisfy { $0.kind == .experience })
    }

    @Test func wrappedPDFLinesJoinTheirBulletUntilAHeading() {
        let text = "- Search service finds public records on the\nweb: 40% more matches\nFabrikam Labs, Inc. Almaty\n- Next"
        let items = ExperienceItem.bullets(in: text)
        #expect(items.map(\.text) == ["Search service finds public records on the web: 40% more matches", "Next"])
    }

    @Test func ranksByCosineToTheQueryAndKeepsTheLimit() {
        // Fake 2-d embedding: axis 0 = "ai", axis 1 = "office".
        let embed: ResumeTailor.Embed = { $0.contains("ai") ? [1, 0] : [0, 1] }
        let items = ["office party", "ai agents", "ai evals"].map { ExperienceItem(kind: .experience, text: $0) }
        let picked = ResumeTailor.select(items, for: "ai engineer", limit: 2, embed: embed)
        #expect(picked.map(\.text) == ["ai agents", "ai evals"])
    }

    @Test func fallsBackToWordOverlapWithoutEmbeddings() {
        let items = ["Organized events", "Python FastAPI services"].map { ExperienceItem(kind: .experience, text: $0) }
        let picked = ResumeTailor.select(items, for: "python backend", limit: 1, embed: { _ in nil })
        #expect(picked.map(\.text) == ["Python FastAPI services"])
    }

    @Test func realSentenceEmbeddingPrefersTheRelevantBullet() throws {
        guard ResumeTailor.sentenceEmbed("test") != nil else { return print("skip: no English sentence embedding") }
        let items = ["Organized the office holiday party", "Built a retrieval-augmented generation service on pgvector"]
            .map { ExperienceItem(kind: .experience, text: $0) }
        let picked = ResumeTailor.select(items, for: "LLM engineer, RAG, vector database", limit: 1)
        #expect(picked.first?.text.contains("retrieval") == true)
    }

    @Test func libraryRoundTripsThroughProfileStore() {
        let suite = "ResumeTailorTests.\(UUID().uuidString)"
        let store = ProfileStore(suiteName: suite)
        defer { store.defaults.removePersistentDomain(forName: suite) }
        #expect(store.loadLibrary().isEmpty)
        let library = [ExperienceItem(kind: .skill, text: "Swift"), ExperienceItem(kind: .answer, text: "Why us: ...")]
        store.saveLibrary(library)
        #expect(store.loadLibrary() == library)
    }
}
