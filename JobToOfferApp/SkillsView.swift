import Core
import SwiftData
import SwiftUI

enum Tier: String, CaseIterable {
    case strong = "Strong", moderate = "Growing", weak = "To learn"
    var color: Color { switch self { case .strong: Ink.green; case .moderate: Ink.amber; case .weak: Ink.burgundy } }
    func terms(_ s: SkillTiers) -> [String] { switch self { case .strong: s.strong; case .moderate: s.moderate; case .weak: s.weak } }
}

/// Skills hub: what you know at a glance, then one submenu per job.
struct SkillsView: View {
    @State private var profile = ProfileStore().load()
    @Query private var jobs: [TrackedJob]
    private var gapCount: Int { WeakSpots.rank(gaps: jobs.map(\.gaps), reasons: jobs.map(\.rejectionReason), ignored: jobs.flatMap(\.ignoredGaps)).count }

    var body: some View {
        NavigationStack {
            PaperScreen {
                Document { CountLine(counts: Tier.allCases.map { ($0.rawValue, $0.terms(profile.skills).count, $0.color) }) }
                if !profile.skills.strong.isEmpty {
                    Block(label: "Your strongest") {
                        Document { ChipFlow(terms: Array(profile.skills.strong.prefix(12)), color: Ink.green) }
                    }
                }
                RuledRows(data: ["all", "gaps", "star", "library"]) { id in
                    switch id {
                    case "all": MenuRow("All skills", "Strong, growing and to learn", "square.grid.2x2") { SkillListView() }
                    case "gaps": MenuRow("Gaps from jobs", gapCount == 0 ? "None yet" : "\(gapCount) to close", "chart.bar") { GapsView() }
                    case "star": MenuRow("STAR stories", "Turn a story into an interview answer", "text.bubble") { StarView() }
                    default: MenuRow("Experience library", "Bullets for tailored resumes", "books.vertical") { LibraryView() }
                    }
                }
            }
            .navigationTitle("Skills")
            .onAppear { profile = ProfileStore().load() }
        }
    }
}

/// Wrapping row of capsules.
struct ChipFlow: View {
    let terms: [String]
    let color: Color
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(terms, id: \.self) { term in
                InkTag(text: term, color: color)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, subviews)
        return CGSize(width: proposal.width ?? 0, height: rows.last.map { $0.y + $0.h } ?? 0)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in rows(width: bounds.width, subviews) {
            for (i, x) in row.items {
                subviews[i].place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + row.y), proposal: ProposedViewSize(subviews[i].sizeThatFits(.unspecified)))
            }
        }
    }
    private func rows(width: CGFloat, _ subviews: Subviews) -> [(y: CGFloat, h: CGFloat, items: [(Int, CGFloat)])] {
        var rows: [(y: CGFloat, h: CGFloat, items: [(Int, CGFloat)])] = []
        var x: CGFloat = 0, y: CGFloat = 0, h: CGFloat = 0, items: [(Int, CGFloat)] = []
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rows.append((y, h, items)); y += h + spacing; x = 0; h = 0; items = []
            }
            items.append((i, x)); x += size.width + spacing; h = max(h, size.height)
        }
        if !items.isEmpty { rows.append((y, h, items)) }
        return rows
    }
}

/// Every skill by tier; add one by hand or swipe to remove.
struct SkillListView: View {
    private let store = ProfileStore()
    @State private var profile = ProfileStore().load()
    @State private var newSkill = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Add a skill you have", text: $newSkill).onSubmit(add)
                    Button("Add", systemImage: "plus.circle.fill", action: add)
                        .labelStyle(.iconOnly).font(.title2).disabled(newSkill.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("Skills come from your resume. New ones join Growing.")
            }
            ForEach(Tier.allCases, id: \.self) { tier in
                let terms = tier.terms(profile.skills)
                if !terms.isEmpty {
                    Section {
                        ChipFlow(terms: terms, color: tier.color)
                    } header: {
                        FieldLabel("\(tier.rawValue) · \(terms.count)")
                    }
                }
            }
        }
        .paperList()
        .tint(Ink.violet)
        .navigationTitle("All skills")
        .overlay {
            if profile.skills.strong.isEmpty && profile.skills.moderate.isEmpty && profile.skills.weak.isEmpty {
                ContentUnavailableView("No skills yet", systemImage: "doc.text.magnifyingglass",
                                       description: Text("Import your resume in Profile."))
            }
        }
        .sensoryFeedback(.success, trigger: profile.skills.moderate.count)
    }

    private func add() {
        withAnimation(.snappy) { profile.addSkill(newSkill) }
        addSkillToLibrary(newSkill)
        store.save(profile)
        newSkill = ""
    }
}

/// Gaps and rejection reasons that repeat across tracked jobs.
struct GapsView: View {
    @Query private var jobs: [TrackedJob]
    @State private var added: Set<String> = []

    var body: some View {
        let spots = Array(WeakSpots.rank(gaps: jobs.map(\.gaps), reasons: jobs.map(\.rejectionReason),
                                         ignored: jobs.flatMap(\.ignoredGaps)).prefix(15))
        let top = max(spots.first?.count ?? 1, 1)
        List {
            Section {
                ForEach(spots, id: \.name) { spot in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(spot.name).font(.headline)
                            GeometryReader { g in
                                Rectangle().fill(Ink.amber)
                                    .frame(width: g.size.width * CGFloat(spot.count) / CGFloat(top))
                            }
                            .frame(height: 4)
                            Text("in \(spot.count) job\(spot.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                        }
                        Button(added.contains(spot.name) ? "Added" : "I have it",
                               systemImage: added.contains(spot.name) ? "checkmark.circle.fill" : "plus.circle") {
                            addGapToProfile(spot.name)
                            withAnimation(.snappy) { _ = added.insert(spot.name) }
                        }
                        .labelStyle(.iconOnly).font(.title2).buttonStyle(.borderless)
                        .tint(added.contains(spot.name) ? Ink.green : Ink.violet)
                        .symbolEffect(.bounce, value: added.contains(spot.name))
                        .disabled(added.contains(spot.name))
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("Tap + when you close a gap. It moves to your skills.")
            }
        }
        .paperList()
        .navigationTitle("Gaps from jobs")
        .overlay {
            if spots.isEmpty {
                ContentUnavailableView("No gaps yet", systemImage: "chart.bar",
                                       description: Text("Track a few jobs. Repeating gaps show up here."))
            }
        }
        .sensoryFeedback(.success, trigger: added.count)
    }
}
