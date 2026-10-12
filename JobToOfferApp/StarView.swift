import Core
import SwiftUI

/// Turns a spoken or typed work story into STAR form and saves it to the library as an answer.
struct StarView: View {
    @State private var story = ""
    @State private var star: StarStory?
    @State private var working = false
    @State private var error: String?
    @State private var saved = false

    var body: some View {
            Form {
                Section {
                    TextEditor(text: $story).frame(minHeight: 140)
                        .overlay(alignment: .topLeading) {
                            if story.isEmpty {
                                Text("What happened, what you did, what changed.")
                                    .foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                            }
                        }
                    Button {
                        Task { await structure() }
                    } label: {
                        if working { ProgressView() } else { Text("Structure as STAR") }
                    }
                    .disabled(working || story.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let error { Text(error).foregroundStyle(.red) }
                } header: {
                    Text("Your story")
                } footer: {
                    Text("Tap the mic on the keyboard to dictate.")
                }

                if let star = Binding($star) {
                    Section {
                        LabeledContent("Situation") { TextField("Situation", text: star.situation, axis: .vertical) }
                        LabeledContent("Task") { TextField("Task", text: star.task, axis: .vertical) }
                        LabeledContent("Action") { TextField("Action", text: star.action, axis: .vertical) }
                        LabeledContent("Result") { TextField("Result", text: star.result, axis: .vertical) }
                    } header: {
                        Label("STAR, AI-generated", systemImage: "sparkles")
                    } footer: {
                        Text("Written by the on-device model. Check and edit every field.")
                    }
                    if !star.wrappedValue.missing.isEmpty {
                        Section("Missing") { ForEach(star.wrappedValue.missing, id: \.self, content: Text.init) }
                    }
                    Section {
                        Button(saved ? "Saved to library" : "Save", systemImage: saved ? "checkmark" : "tray.and.arrow.down") {
                            save(star.wrappedValue)
                        }
                        .disabled(saved)
                        .symbolEffect(.bounce, value: saved)
                        .sensoryFeedback(.success, trigger: saved)
                    }
                }
            }
            .paperList()
            .tint(Ink.violet)
            .navigationTitle("STAR stories")
            .animation(.snappy, value: star == nil)
    }

    private func structure() async {
        working = true
        error = nil
        saved = false
        defer { working = false }
        let client = FoundationModelsClient()
        if case .unavailable(let reason) = client.capability().status {
            error = reason
            return
        }
        do { star = try await client.star(story: story) } catch LLMError.failed(let reason) { error = reason } catch { self.error = error.localizedDescription }
    }

    private func save(_ s: StarStory) {
        let store = ProfileStore()
        let text = "Situation: \(s.situation)\nTask: \(s.task)\nAction: \(s.action)\nResult: \(s.result)"
        store.saveLibrary(store.loadLibrary() + [ExperienceItem(kind: .answer, text: text)])
        saved = true
    }
}
