import AppIntents
import Core
import SwiftData

/// Spike, not V1: does Siri hand the text of the post on screen (LinkedIn, Telegram) to JobScout?
/// Full text → Siri handoff works; a shorter paraphrase → gates lose the exact wording;
/// Siri asks for the text → no handoff. Delete this file after the device check.
struct ProbeIntent: AppIntent {
    static let title: LocalizedStringResource = "Check this post"
    static let description = IntentDescription("Saves the post text to the JobScout Inbox and reports what arrived.")
    static let openAppWhenRun = true

    // Optional: Siri runs the intent even without text, so "no handoff" shows up as a row, not as a prompt.
    @Parameter(title: "Post text")
    var text: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = text ?? ""
        // Always write a row: the Inbox shows that the intent ran even if Siri drops the dialog.
        // Same path as the share extension, so the full text can be compared with the post.
        let payload = IncomingItemParser.payload(url: nil, texts: [text]) ?? SharedPayload(url: nil, text: "ProbeIntent ran without text")
        let context = ModelContext(try SharedStore.container())
        context.insert(IncomingItem(payload))
        try context.save()
        return .result(dialog: text.isEmpty ? "JobScout got no text." : "JobScout got \(text.count) characters. Starts with: \(String(text.prefix(80)))")
    }
}

struct JobScoutShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ProbeIntent(),
            phrases: ["Check this post with \(.applicationName)", "Send this to \(.applicationName)",
                      "Do I qualify for this job in \(.applicationName)", "Check this job with \(.applicationName)"],
            shortTitle: "Check this post",
            systemImageName: "text.magnifyingglass"
        )
    }
}
