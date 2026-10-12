import Core
import SwiftData
import SwiftUI

struct TrackerView: View {
    @Query(sort: \TrackedJob.date, order: .reverse) private var jobs: [TrackedJob]
    @State private var exports: [URL] = []

    var body: some View {
        NavigationStack {
            PaperScreen {
                if jobs.isEmpty {
                    ContentUnavailableView("Tracker is empty", systemImage: "list.bullet.rectangle",
                                           description: Text("Check a posting in the Inbox and add it to the tracker."))
                        .padding(.top, 60)
                }
                ForEach(sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            InkTag(text: statusLabel(section.title), color: statusColor(section.title))
                            Text("\(section.jobs.count)").font(.system(.subheadline, weight: .semibold).width(.condensed)).foregroundStyle(Ink.muted)
                        }
                        RuledRows(data: section.jobs.map(\.key)) { key in
                            if let job = section.jobs.first(where: { $0.key == key }) {
                                NavigationLink(value: job) { TrackerRow(job: job) }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .animation(.snappy, value: jobs.map(\.status))
            .navigationTitle("Tracker")
            .navigationDestination(for: TrackedJob.self) { TrackedJobView(job: $0) }
            .toolbar {
                if !exports.isEmpty {
                    ShareLink(items: exports) { Label("Export", systemImage: "square.and.arrow.up") }
                }
            }
            .task(id: CSVExporter.csv(jobs)) { exports = (try? writeExports()) ?? [] }
        }
    }

    /// Canonical statuses in vocabulary order; any other stored value last.
    private var sections: [(title: String, jobs: [TrackedJob])] {
        (TrackerStatus.allCases.map { status in (status.rawValue, jobs.filter { $0.trackerStatus == status }) }
            + [("other", jobs.filter { $0.trackerStatus == nil })])
            .filter { !$0.1.isEmpty }
    }

    /// Files for the share sheet ("Save to Files" included). Append to the repo tracker with
    /// `tail -n +2 job_search_tracker_export.csv >> job_search_tracker.csv`.
    private func writeExports() throws -> [URL] {
        let directory = FileManager.default.temporaryDirectory
        let csv = directory.appending(path: "job_search_tracker_export.csv")
        try CSVExporter.csv(jobs).write(to: csv, atomically: true, encoding: .utf8)
        let json = directory.appending(path: "seen_jobs_export.json")
        try SeenJobsExporter.json(jobs).write(to: json)
        return [csv, json]
    }
}

struct TrackerRow: View {
    let job: TrackedJob
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(job.title).font(.headline).foregroundStyle(Ink.text)
                Text(job.company).font(.subheadline).foregroundStyle(Ink.muted)
            }
            Spacer()
            if let score = job.rankScore {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(score)").font(.display(.title2)).foregroundStyle(scoreColor(score)).monospacedDigit()
                    if let band = job.rankVerdict { Text(band).font(.caption2).foregroundStyle(Ink.muted) }
                }
            }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Ink.muted)
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}

struct TrackedJobView: View {
    @Bindable var job: TrackedJob
    private var visibleGaps: [String] { job.gaps.filter { !job.ignoredGaps.contains($0) } }

    var body: some View {
        PaperScreen {
            JobDocument(company: job.company, title: job.title,
                        facts: [("Place", job.location ?? ""), ("Added", job.date), ("Apply by", job.deadline ?? "")],
                        score: job.rankScore, band: job.rankVerdict,
                        gates: [("Language", job.languageGate), ("Location", job.locationVerdict)]
                            .compactMap { g in g.1.flatMap(Verdict.init(rawValue:)).map { (g.0, $0) } },
                        key: job.key, date: job.date)
            Block(label: "Status") {
                Document {
                    Menu {
                        Picker("Status", selection: Binding(get: { job.trackerStatus ?? .drafted }, set: { job.trackerStatus = $0 })) {
                            ForEach(TrackerStatus.allCases, id: \.self) { Text(statusLabel($0.rawValue)).tag($0) }
                        }
                    } label: {
                        HStack {
                            InkTag(text: statusLabel(job.status), color: statusColor(job.status))
                            Spacer()
                            Text("Change").font(.subheadline.weight(.semibold)).foregroundStyle(Ink.violet)
                        }
                        .frame(minHeight: 44)
                    }
                    Rectangle().fill(Ink.rule).frame(height: 1)
                    // One line: /outcome edits the tracker row by row, so notes never carry a line break.
                    TextField("Notes", text: Binding(get: { job.notes }, set: { job.notes = $0.singleLine })).font(.subheadline)
                }
                .animation(.snappy, value: job.status)
            }
            if job.trackerStatus == .rejected {
                Block(label: "Why rejected", footer: "Feeds Gaps from jobs in Skills.") {
                    Document {
                        TextField("What was missing", text: Binding(get: { job.rejectionReason }, set: { job.rejectionReason = $0.singleLine }))
                            .font(.subheadline)
                        if !visibleGaps.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(visibleGaps, id: \.self) { gap in
                                    Button { job.rejectionReason = gap } label: { InkTag(text: gap, color: Ink.burgundy) }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            if let note = job.languageNote, let verdict = job.languageGate.flatMap(Verdict.init(rawValue:)) {
                Block(label: "From the posting") { Document { GateNote(name: "Language", verdict: verdict, note: note) } }
            }
            if let url = URL(string: job.url), !job.url.isEmpty {
                Link(destination: url) {
                    Label("Open posting", systemImage: "safari").font(.headline).foregroundStyle(Ink.violet).frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            if !job.strengths.isEmpty {
                Block(label: "Why you fit") {
                    Document {
                        ForEach(job.strengths, id: \.self) { line in
                            Label { Text(line).font(.subheadline).foregroundStyle(Ink.text) } icon: {
                                Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(Ink.green)
                            }
                        }
                    }
                }
            }
            if !visibleGaps.isEmpty {
                Block(label: "What is missing", footer: "Add a gap you have closed to your profile, or ignore it.") {
                    RuledRows(data: visibleGaps) { gap in
                        HStack {
                            Text(gap).font(.subheadline).foregroundStyle(Ink.text)
                            Spacer()
                            Button("Add to profile", systemImage: "plus.circle") {
                                addGapToProfile(gap)
                                job.gaps.removeAll { $0 == gap }
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            Button("Ignore", systemImage: "eye.slash") { job.ignoredGaps.append(gap) }
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .labelStyle(.iconOnly).foregroundStyle(Ink.violet)
                    }
                }
            }
            TailoredResumeBlock(title: job.title, company: job.company, terms: job.strengths + job.gaps)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// "no_response" → "No Response": the tracker stores raw values, the screen shows words.
func statusLabel(_ status: String) -> String { status.replacingOccurrences(of: "_", with: " ").capitalized }

func statusColor(_ status: String) -> Color {
    switch status {
    case "applied": Ink.violet
    case "interview", "offer", "hired": Ink.green
    case "rejected", "no_response", "no response": Ink.burgundy
    case "drafted": Ink.amber
    default: Ink.muted
    }
}

