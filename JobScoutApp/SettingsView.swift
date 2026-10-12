import Core
import SwiftUI

struct SettingsView: View {
    let storeError: String?
    @State private var capability = FoundationModelsClient().capability()
    @State private var localeSupported = FoundationModelsClient().supportsCurrentLocale()
    private let telemetry = BudgetTelemetry.shared
    var body: some View {
        List {
                Section {
                    let ok: Bool = { if case .unavailable = capability.status { return false }; return localeSupported }()
                    HStack(spacing: 14) {
                        Image(systemName: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.largeTitle).foregroundStyle(ok ? Ink.green : Ink.amber)
                            .symbolEffect(.bounce, value: ok)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ok ? "Ready to check jobs" : "Checking is off").font(.display(.title3))
                            Text(ok ? "Apple Intelligence runs on this iPhone." : capability.statusText).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                Section {
                  DisclosureGroup("Technical details") {
                    LabeledContent("Availability", value: capability.statusText)
                        .accessibilityIdentifier("probe.availability")
                    LabeledContent("Context size", value: "\(capability.contextSize) tokens")
                        .accessibilityIdentifier("probe.contextSize")
                    LabeledContent("Languages", value: capability.supportedLanguages.joined(separator: ", "))
                        .accessibilityIdentifier("probe.languages")
                    LabeledContent("Device language", value: localeSupported ? "supported" : "not supported")
                    LabeledContent("Last prompt", value: telemetry.promptTokens.map { "\($0) tokens" } ?? "none yet")
                    LabeledContent("Truncated", value: telemetry.promptTokens == nil ? "-" : telemetry.truncated ? "yes" : "no")
                    LabeledContent("App Group store", value: storeError == nil ? "shared" : "local only")
                  }
                } footer: {
                    if case .unavailable = capability.status {
                        Text("Parsing needs the on-device model. The Inbox still keeps everything you share, so you can parse it later.")
                    } else if !localeSupported {
                        Text("Set the device and Siri language to a supported language (for example English) to parse postings.")
                    }
                }
                if let storeError {
                    Section { Label("Shared links cannot reach the app: \(storeError)", systemImage: "exclamationmark.triangle").foregroundStyle(Ink.amber) }
                }
        }
        .paperList()
        .navigationTitle("Settings")
        .refreshable {
            capability = FoundationModelsClient().capability()
            localeSupported = FoundationModelsClient().supportsCurrentLocale()
        }
    }
}
