import Core
import SwiftUI

/// Skills, resume bullets, projects, languages and past answers that a tailored resume picks from.
struct LibraryView: View {
    private let store = ProfileStore()
    @State private var items: [ExperienceItem] = ProfileStore().loadLibrary()
    @State private var newKind: ExperienceItem.Kind = .experience
    @State private var newText = ""
    @State private var importStatus: String?

    var body: some View {
        List {
            Section {
                Picker("Kind", selection: $newKind) {
                    ForEach(ExperienceItem.Kind.allCases, id: \.self) { Label($0.title, systemImage: $0.icon) }
                }
                TextField("Shipped an iOS app used by 10k people", text: $newText, axis: .vertical)
                Button("Add", systemImage: "plus") {
                    items.append(ExperienceItem(kind: newKind, text: newText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    newText = ""
                }
                .disabled(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Import bullets from resume", systemImage: "doc.text") {
                    guard let resume = store.loadResumeText() else {
                        importStatus = "No resume yet. Import one in Profile first."
                        return
                    }
                    let known = Set(items.map(\.text))
                    let added = ExperienceItem.bullets(in: resume).filter { !known.contains($0.text) }
                    items += added
                    importStatus = added.isEmpty ? "No new bullet lines found in the resume." : "Added \(added.count) items."
                }
                if let importStatus {
                    Text(importStatus).font(.footnote).foregroundStyle(.secondary)
                }
            } footer: {
                Text("A tailored resume picks the items closest to each posting.")
            }

            ForEach(ExperienceItem.Kind.allCases, id: \.self) { kind in
                let indices = items.indices.filter { items[$0].kind == kind }
                if !indices.isEmpty {
                    Section {
                        ForEach(indices, id: \.self) { i in
                            TextField("Text", text: $items[i].text, axis: .vertical)
                        }
                        .onDelete { offsets in
                            items.remove(atOffsets: IndexSet(offsets.map { indices[$0] }))
                        }
                    } header: {
                        FieldLabel("\(kind.title) · \(indices.count)")
                    }
                }
            }
        }
        .paperList()
        .tint(Ink.violet)
        .animation(.snappy, value: items.count)
        .navigationTitle("Experience library")
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("No items yet", systemImage: "tray",
                                       description: Text("Add one above or import the bullets from your resume."))
            }
        }
        .onAppear { items = store.loadLibrary() }
        .onChange(of: items) { _, new in store.saveLibrary(new) }
    }
}

/// Library items closest to the posting, and a one-page PDF of them.
struct TailoredResumeBlock: View {
    let title: String
    let company: String
    let terms: [String]
    @State private var picked: [ExperienceItem] = []

    init(posting: JobPosting, gaps: [String]) {
        self.init(title: posting.title, company: posting.company, terms: posting.stack + gaps)
    }

    init(title: String, company: String, terms: [String]) {
        self.title = title
        self.company = company
        self.terms = terms
    }

    var body: some View {
        Block(label: "Tailored resume", footer: "Picked from your library. Edit or remove any line before export.") {
            Document {
                if picked.isEmpty {
                    Text("Add items in Skills, Experience library.").font(.subheadline).foregroundStyle(Ink.muted)
                } else {
                    ForEach($picked) { $item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            TextField("Text", text: $item.text, axis: .vertical).font(.subheadline).foregroundStyle(Ink.text)
                            Button("Remove", systemImage: "xmark") { withAnimation(.snappy) { picked.removeAll { $0.id == item.id } } }
                                .labelStyle(.iconOnly).font(.caption).foregroundStyle(Ink.muted).frame(minWidth: 32, minHeight: 32)
                        }
                    }
                    if let url = pdf() {
                        ShareLink(item: url) { Label("Export PDF", systemImage: "square.and.arrow.up") }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Ink.violet).frame(minHeight: 32)
                    }
                }
            }
        }
        .task(id: title) {
            let query = ([title] + terms).joined(separator: ", ")
            picked = ResumeTailor.select(ProfileStore().loadLibrary(), for: query, limit: 8)
        }
    }

    // ponytail: plain one-page layout; add templates when users ask for them.
    @MainActor private func pdf() -> URL? {
        let page = VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title2.bold())
            Text(company).foregroundStyle(.secondary)
            Divider()
            ForEach(picked) { Text("• \($0.text)").font(.body) }
            Spacer(minLength: 0)
        }
        .padding(48)
        .frame(width: 612, height: 792, alignment: .topLeading)
        .background(.white)
        .foregroundStyle(.black)

        let url = URL.temporaryDirectory.appending(path: "Resume - \(company.isEmpty ? "posting" : company).pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }
        ImageRenderer(content: page).render { _, draw in
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }
}

extension ExperienceItem.Kind {
    var title: String {
        switch self { case .skill: "Skills"; case .experience: "Experience"; case .project: "Projects"; case .language: "Languages"; case .answer: "Interview answers" }
    }
    var icon: String {
        switch self { case .skill: "star.fill"; case .experience: "briefcase.fill"; case .project: "hammer.fill"; case .language: "globe"; case .answer: "text.bubble.fill" }
    }
}
