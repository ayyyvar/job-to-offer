import Core
import Foundation
import SwiftData
import Testing

/// Step 8: what the share extension writes to the App Group store, the app reads.
/// Two containers on the same group store stand in for the two processes.
@MainActor
@Suite struct SharedStoreIntegrationTests {
    @Test func itemWrittenToTheAppGroupStoreIsVisibleToASecondContainer() throws {
        #expect(FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedStore.appGroupID) != nil)
        let marker = "https://job-boards.greenhouse.io/sandboxly/jobs/\(UUID().uuidString)"
        let writer = ModelContext(try SharedStore.container())
        let item = IncomingItem(SharedPayload(url: marker, text: nil))
        writer.insert(item)
        try writer.save()

        let reader = ModelContext(try SharedStore.container())
        let found = try reader.fetch(FetchDescriptor<IncomingItem>(predicate: #Predicate { $0.url == marker }))
        #expect(found.count == 1)

        writer.delete(item)
        try writer.save()
    }
}
