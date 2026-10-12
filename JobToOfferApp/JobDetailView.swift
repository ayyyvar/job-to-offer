import Core
import SwiftData
import SwiftUI

struct JobDetailView: View {
    let item: IncomingItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var model = ParseModel(client: FoundationModelsClient(), profile: ProfileStore().load())
    @State private var evaluation: Evaluation?
    @State private var alreadyTracked: String?

    var body: some View {
        PaperScreen {
            if evaluation == nil { source }
            switch model.state {
            case .idle:
                VStack(alignment: .leading, spacing: 8) {
                    Button { Task { await parse() } } label: { Label("Check this job", systemImage: "checkmark.seal") }
                        .buttonStyle(PrimaryButtonStyle())
                    Text("Runs on your iPhone. Nothing leaves it.").font(.footnote).foregroundStyle(Ink.muted).padding(.horizontal, 4)
                }
            case .fetching: steps(1)
            case .extracting: steps(2)
            case .scoring: steps(3)
            case .failed(let reason):
                Document {
                    Label(reason, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Ink.burgundy)
                    Button("Try again") { Task { await parse() } }.foregroundStyle(Ink.violet).font(.headline)
                }
            case .done:
                if let binding = Binding($evaluation) {
                    EvaluationView(evaluation: binding, sourceURL: item.url)
                    Button(action: addToTracker) { Label("Add to tracker", systemImage: "tray.and.arrow.down") }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .animation(.snappy, value: evaluation == nil)
        .navigationTitle(evaluation == nil ? "Posting" : "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { FoundationModelsClient().prewarm() }
        .onChange(of: model.state) { _, state in if case .done(let e) = state { evaluation = e } }
        .alert("Already tracked", isPresented: Binding(get: { alreadyTracked != nil }, set: { if !$0 { alreadyTracked = nil } })) {
            Button("OK") {}
        } message: {
            Text(alreadyTracked ?? "")
        }
    }

    private var source: some View {
        Document {
            if let url = item.url, let link = URL(string: url) {
                Link(destination: link) {
                    Label(link.host()?.replacingOccurrences(of: "www.", with: "") ?? url, systemImage: "link")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Ink.violet)
                }
            }
            if let text = item.text { Text(text).font(.subheadline).foregroundStyle(Ink.text).lineLimit(8) }
        }
    }

    private func steps(_ current: Int) -> some View {
        Document {
            ForEach(Array(["Reading the posting", "Pulling out the details", "Scoring your fit"].enumerated()), id: \.offset) { i, label in
                let step = i + 1
                HStack(spacing: 12) {
                    Group {
                        if step < current { Image(systemName: "checkmark.circle.fill").foregroundStyle(Ink.green) }
                        else if step == current { ProgressView().tint(Ink.violet) }
                        else { Image(systemName: "circle").foregroundStyle(Ink.rule) }
                    }
                    .frame(width: 22)
                    Text(label).font(step == current ? .headline : .subheadline)
                        .foregroundStyle(step > current ? Ink.muted : Ink.text)
                }
                .frame(minHeight: 32)
            }
        }
        .animation(.snappy, value: current)
    }

    /// The shared link first. If that fails and the share carried a real posting text (50+ words,
    /// not just a caption), parse the text; otherwise keep the failure visible.
    private func parse() async {
        if let url = item.url {
            await model.run(url: url)
            if case .failed = model.state, let text = item.text, text.split(whereSeparator: \.isWhitespace).count >= 50 {
                await model.run(text: text)
            }
        } else if let text = item.text {
            await model.run(text: text)
        }
    }

    private func addToTracker() {
        guard let evaluation else { return }
        let job = TrackedJob(evaluation, sourceURL: item.url, today: .now, timeZone: .current)
        do {
            switch try SharedStore.add(job, to: context) {
            case .added:
                context.delete(item)
                try context.save()
                dismiss()
            case .alreadyTracked(let existing):
                alreadyTracked = "\(existing.company), \(existing.title): status \(statusLabel(existing.status)), added \(existing.date)."
            }
        } catch {
            alreadyTracked = "Could not save: \(error.localizedDescription)"
        }
    }
}

/// "fullTime" → "Full time".
func readable(_ raw: String) -> String {
    let spaced = raw.reduce(into: "") { s, c in s += c.isUppercase && !s.isEmpty ? " " + c.lowercased() : String(c) }
    return spaced.prefix(1).uppercased() + spaced.dropFirst()
}

/// The verdict and everything the model produced, editable before "Add to tracker". Gates and band re-run on each edit.
struct EvaluationView: View {
    @Binding var evaluation: Evaluation
    let sourceURL: String?
    @State private var editing = false
    @State private var adjusting = false

    private var fit: FitEvaluation { evaluation.fit }
    private var posting: JobPosting { evaluation.posting }

    var body: some View {
        Group {
            JobDocument(
                company: posting.company, title: posting.title,
                facts: [("Place", posting.location), ("Work", posting.remotePolicy == .unspecified ? "" : readable(posting.remotePolicy.rawValue)),
                        ("Type", posting.employmentType == .unspecified ? "" : readable(posting.employmentType.rawValue)),
                        ("Pay", posting.compensation), ("Apply by", posting.deadline)],
                score: fit.overall, band: fit.band.rawValue,
                gates: [("Eligibility", fit.eligibility), ("Language", fit.languageGate), ("Location", fit.locationVerdict)],
                key: JobKey.make(company: posting.company, title: posting.title, url: sourceURL ?? ""),
                date: Date.now.formatted(.iso8601.year().month().day()))
            proof
            BulletBlock(title: "Why you fit", mark: "checkmark", color: Ink.green, items: $evaluation.scores.strengths)
            BulletBlock(title: "What is missing", mark: "minus", color: Ink.amber, items: $evaluation.scores.gaps)
            scores
            Button { editing = true } label: {
                Label("Edit posting details", systemImage: "square.and.pencil").font(.headline).foregroundStyle(Ink.violet)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            Label("Written by the model on this iPhone. Check and edit every field.", systemImage: "sparkles")
                .font(.footnote).foregroundStyle(Ink.muted).padding(.horizontal, 4)
            TailoredResumeBlock(posting: posting, gaps: evaluation.scores.gaps)
        }
        .onChange(of: evaluation.posting) { evaluation.recompute() }
        .onChange(of: evaluation.scores) { evaluation.recompute() }
        .sheet(isPresented: $editing) { PostingEditor(posting: $evaluation.posting) }
    }

    /// The posting's own words under every stamp that is not a clean pass.
    @ViewBuilder private var proof: some View {
        let notes = [("Eligibility", fit.eligibility, fit.eligibilityNote), ("Language", fit.languageGate, fit.languageNote),
                     ("Location", fit.locationVerdict, fit.locationNote)].compactMap { g in g.2.map { (g.0, g.1, $0) } }
        if !notes.isEmpty {
            Block(label: "From the posting") {
                RuledRows(data: notes.map(\.0)) { name in
                    if let note = notes.first(where: { $0.0 == name }) { GateNote(name: note.0, verdict: note.1, note: note.2) }
                }
            }
        }
    }

    private var scores: some View {
        Block(label: "Fit estimate, by part", footer: "An estimate from your resume. Adjust it if it looks wrong.") {
            Document {
                ScoreBar(name: "Technical", value: evaluation.scores.technical)
                ScoreBar(name: "Experience", value: evaluation.scores.experience)
                ScoreBar(name: "Behavioral", value: evaluation.scores.behavioral)
                ScoreBar(name: "Career", value: evaluation.scores.career)
                DisclosureGroup("Adjust", isExpanded: $adjusting) {
                    VStack {
                        Stepper("Technical \(evaluation.scores.technical)", value: $evaluation.scores.technical, in: 0...100, step: 5)
                        Stepper("Experience \(evaluation.scores.experience)", value: $evaluation.scores.experience, in: 0...100, step: 5)
                        Stepper("Behavioral \(evaluation.scores.behavioral)", value: $evaluation.scores.behavioral, in: 0...100, step: 5)
                        Stepper("Career \(evaluation.scores.career)", value: $evaluation.scores.career, in: 0...100, step: 5)
                    }
                    .padding(.top, 8)
                }
                .tint(Ink.violet)
            }
        }
    }
}

/// One gate's reason, with the verdict mark in its stamp ink.
struct GateNote: View {
    let name: String
    let verdict: Verdict
    let note: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: verdict.icon).foregroundStyle(verdict.color)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(name): \(verdict.word)").font(.subheadline.weight(.semibold)).foregroundStyle(Ink.text)
                Text(note).font(.subheadline).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Editable bullet lines (strengths, gaps).
struct BulletBlock: View {
    let title: String, mark: String, color: Color
    @Binding var items: [String]
    var body: some View {
        Block(label: title) {
            Document {
                ForEach(items.indices, id: \.self) { i in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: mark).font(.footnote.weight(.bold)).foregroundStyle(color)
                        TextField(title, text: Binding(get: { i < items.count ? items[i] : "" }, set: { if i < items.count { items[i] = $0 } }),
                                  axis: .vertical)
                            .font(.subheadline).foregroundStyle(Ink.text)
                        Button("Remove", systemImage: "xmark") { _ = withAnimation(.snappy) { items.remove(at: i) } }
                            .labelStyle(.iconOnly).font(.caption).foregroundStyle(Ink.muted).frame(minWidth: 32, minHeight: 32)
                    }
                }
                Button("Add a line", systemImage: "plus") { items.append("") }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Ink.violet).frame(minHeight: 32)
            }
        }
    }
}

/// Every extracted field, as a system form in a sheet.
struct PostingEditor: View {
    @Binding var posting: JobPosting
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $posting.title)
                    TextField("Company", text: $posting.company)
                    TextField("Location", text: $posting.location)
                    Picker("Remote policy", selection: $posting.remotePolicy) {
                        ForEach(RemotePolicy.allCases, id: \.self) { Text(readable($0.rawValue)).tag($0) }
                    }
                    Picker("Employment", selection: $posting.employmentType) {
                        ForEach(EmploymentType.allCases, id: \.self) { Text(readable($0.rawValue)).tag($0) }
                    }
                    TextField("Must be in (comma-separated)", text: $posting.locationRequirement.commaSeparated)
                }
                Section {
                    Picker("Visa", selection: $posting.visaSponsorship) {
                        ForEach(VisaStance.allCases, id: \.self) { Text(readable($0.rawValue)).tag($0) }
                    }
                    TextField("Eligibility quote", text: $posting.eligibilityQuote, axis: .vertical)
                }
                Section {
                    ForEach(posting.requiredLanguages.indices, id: \.self) { i in
                        HStack {
                            TextField("Language", text: languageBinding(i, \.language))
                            TextField("Level", text: languageBinding(i, \.level))
                        }
                    }
                    .onDelete { posting.requiredLanguages.remove(atOffsets: $0) }
                    Button("Add language") { posting.requiredLanguages.append(LanguageRequirement(language: "", level: "")) }
                } header: {
                    FieldLabel("Languages the job needs")
                }
                Section {
                    TextField("Stack (comma-separated)", text: $posting.stack.commaSeparated)
                    Stepper("Years required: \(posting.minYearsExperience)", value: $posting.minYearsExperience, in: 0...30)
                    TextField("Compensation", text: $posting.compensation)
                    TextField("Deadline (YYYY-MM-DD)", text: $posting.deadline)
                }
            }
            .paperList()
            .tint(Ink.violet)
            .navigationTitle("Posting details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    /// Bounds-checked: a row being deleted can still read or write its old index.
    private func languageBinding(_ i: Int, _ field: WritableKeyPath<LanguageRequirement, String>) -> Binding<String> {
        Binding(get: { i < posting.requiredLanguages.count ? posting.requiredLanguages[i][keyPath: field] : "" },
                set: { if i < posting.requiredLanguages.count { posting.requiredLanguages[i][keyPath: field] = $0 } })
    }
}

extension Binding where Value == [String] {
    /// Comma-separated editing. Elements keep their spaces, so typing a comma does not jump the cursor.
    var commaSeparated: Binding<String> {
        Binding<String>(get: { wrappedValue.joined(separator: ",") },
                        set: { wrappedValue = $0.isEmpty ? [] : $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) })
    }
}
