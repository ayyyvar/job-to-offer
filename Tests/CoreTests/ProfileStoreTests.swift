@testable import Core
import Foundation
import Testing

@Suite struct ProfileStoreTests {
    @Test func profileAndResumeTextRoundTrip() {
        let suite = "ProfileStoreTests.\(UUID().uuidString)"
        let store = ProfileStore(suiteName: suite)
        defer { store.defaults.removePersistentDomain(forName: suite) }

        #expect(store.load() == .empty)
        store.save(.fixture)
        #expect(store.load() == .fixture)

        #expect(store.loadResumeText() == nil)
        store.saveResumeText("Senior Engineer, Python")
        #expect(store.loadResumeText() == "Senior Engineer, Python")
    }
}
