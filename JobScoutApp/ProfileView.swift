import Core
import SwiftData
import SwiftUI

/// A closed gap becomes a library skill line (the profile tier is updated by the caller).
func addSkillToLibrary(_ term: String) {
    let store = ProfileStore()
    var library = store.loadLibrary()
    guard !library.contains(where: { $0.kind == .skill && $0.text.lowercased() == term.lowercased() }) else { return }
    library.append(ExperienceItem(kind: .skill, text: term))
    store.saveLibrary(library)
}

/// Gap action outside ProfileView: profile tier + library.
func addGapToProfile(_ term: String) {
    let store = ProfileStore()
    var profile = store.load()
    profile.addSkill(term)
    store.save(profile)
    addSkillToLibrary(term)
}
import UniformTypeIdentifiers

struct ProfileView: View {
    private let store = ProfileStore()
    @State private var profile: CandidateProfile = ProfileStore().load()
    @Query private var jobs: [TrackedJob]
    @State private var regionsText = ""
    @State private var rolesText = ""
    @State private var languagesText = ""
    @State private var showImporter = false
    @State private var showPaste = false
    @State private var pasteText = ""
    @State private var importError: String?
    @State private var importStatus: String?

    var body: some View {
        PaperScreen {
            if !jobs.isEmpty {
                Document {
                    CountLine(counts: [("Tracked", jobs.count, Ink.text),
                                       ("Applied", jobs.filter { $0.trackerStatus == .applied }.count, Ink.violet),
                                       ("Interviews", jobs.filter { $0.trackerStatus == .interview || $0.trackerStatus == .offer }.count, Ink.green)])
                }
            }
            Block(label: "Where you can work", footer: "Places or time zones, comma-separated.") {
                Document {
                    TextField("Kazakhstan, Almaty, GMT+5", text: $regionsText)
                        .onChange(of: regionsText) { _, new in
                            profile.regions = new.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
                        }
                }
            }
            Block(label: "Roles you want", footer: "Comma-separated. Inbox searches use them.") {
                Document {
                    TextField("iOS Engineer, ML Engineer", text: $rolesText)
                        .onChange(of: rolesText) { _, new in
                            profile.targetRoles = new.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        }
                }
            }
            Block(label: "Languages", footer: "Language: level, comma-separated.") {
                Document {
                    TextField("English: fluent, Russian: native", text: $languagesText)
                        .onChange(of: languagesText) { _, new in profile.languages = parseLanguages(new) }
                }
            }
            Block(label: "Resume", footer: "PDF, text or LaTeX. Skills fill in automatically.") {
                Document {
                    Button("Import resume file", systemImage: "doc.badge.plus") { showImporter = true }
                        .fileImporter(
                            isPresented: $showImporter,
                            allowedContentTypes: [.pdf, .plainText, .text, UTType(filenameExtension: "tex")].compactMap { $0 }
                        ) { result in
                            handleImport(result)
                        }
                        .frame(minHeight: 32)
                    Rectangle().fill(Ink.rule).frame(height: 1)
                    Button("Paste resume text", systemImage: "doc.on.clipboard") { pasteText = store.loadResumeText() ?? ""; showPaste = true }
                        .frame(minHeight: 32)
                    if let importError {
                        Text(importError).font(.subheadline).foregroundStyle(Ink.burgundy)
                    }
                    if let importStatus {
                        Label(importStatus, systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(Ink.green)
                            .transition(.opacity)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Ink.violet)
            }
            Document { MenuRow("Company boards", "Greenhouse, Lever, Ashby", "building.2") { BoardsView() } }
        }
        .animation(.snappy, value: importStatus)
        .navigationTitle("Profile")
        .onAppear {
            regionsText = profile.regions.joined(separator: ", ")
            rolesText = profile.targetRoles.joined(separator: ", ")
            languagesText = profile.languages.map { "\($0.key.capitalized): \($0.value)" }.joined(separator: ", ")
        }
        .onDisappear { store.save(profile) }
        .onChange(of: profile) { _, new in store.save(new) }
        .sheet(isPresented: $showPaste) {
            NavigationStack {
                TextEditor(text: $pasteText)
                    .padding()
                    .navigationTitle("Paste resume text")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                applyResumeText(pasteText)
                                showPaste = false
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showPaste = false }
                        }
                    }
            }
        }
    }

    private func parseLanguages(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for entry in text.split(separator: ",") {
            let parts = entry.split(separator: ":", maxSplits: 1)
            guard let name = parts.first?.trimmingCharacters(in: .whitespaces).lowercased(), !name.isEmpty else { continue }
            let level = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces).lowercased() : "fluent"
            result[name] = level.isEmpty ? "fluent" : level
        }
        return result
    }

    private func handleImport(_ result: Result<URL, Error>) {
        importError = nil
        importStatus = nil
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let text = try ResumeImporter.text(from: data, type: ResumeFileType(fileExtension: url.pathExtension))
                applyResumeText(text)
            } catch {
                importError = "Could not read that file: \(error)"
            }
        }
    }

    private func applyResumeText(_ text: String) {
        store.saveResumeText(text)
        profile.skills = SkillTiers.derived(from: text)
        store.save(profile)
        var library = store.loadLibrary()
        let known = Set(library.map(\.text))
        let added = ExperienceItem.bullets(in: text).filter { !known.contains($0.text) }
        library += added
        store.saveLibrary(library)
        importStatus = "Imported \(text.split(whereSeparator: \.isWhitespace).count) words, \(profile.skills.strong.count + profile.skills.moderate.count) skills, \(added.count) new library items."
    }
}
