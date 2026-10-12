import Core
import SwiftData
import SwiftUI

@main
struct JobScoutApp: App {
    let container: ModelContainer
    let storeError: String?
    @State private var launching = true

    init() {
        styleNavigationTitles()
        #if DEBUG
        if MockData.enabled { container = MockData.container(); storeError = nil; return }
        #endif
        do {
            container = try SharedStore.container()
            storeError = nil
        } catch {
            // Without the App Group (e.g. signing without the capability) the app still works on a
            // local store; only items from the share extension stay invisible.
            container = try! ModelContainer(for: IncomingItem.self, TrackedJob.self)
            storeError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Inbox", systemImage: "tray") { InboxView() }
                Tab("Tracker", systemImage: "list.bullet.rectangle") { TrackerView() }
                Tab("Profile", systemImage: "person.crop.circle") {
                    NavigationStack {
                        ProfileView()
                            .toolbar {
                                NavigationLink { SettingsView(storeError: storeError) } label: { Label("Settings", systemImage: "gearshape") }
                            }
                    }
                }
                Tab("Skills", systemImage: "star.fill") { SkillsView() }
            }
            .tint(Ink.violet)
            .overlay { if launching { LaunchOverlay(shown: $launching).transition(.opacity) } }
        }
        .modelContainer(container)
    }
}
