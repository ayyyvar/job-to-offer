import Core
import SwiftData
import SwiftUI

struct InboxView: View {
    @Query(sort: \IncomingItem.receivedAt, order: .reverse) private var items: [IncomingItem]
    @Environment(\.modelContext) private var context
    @State private var roles: [String] = []

    var body: some View {
        NavigationStack {
            PaperScreen {
                if items.isEmpty && roles.isEmpty {
                    ContentUnavailableView("No jobs yet", systemImage: "tray",
                                           description: Text("Share a job link to job-to-offer from Safari or LinkedIn, or tap paste."))
                        .padding(.top, 60)
                }
                if !items.isEmpty {
                    Block(label: "To check · \(items.count)", footer: "Touch and hold a posting to delete it.") {
                        VStack(spacing: 10) {
                            ForEach(items) { item in
                                NavigationLink(value: item) { InboxStub(item: item) }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            withAnimation(.snappy) { context.delete(item) }
                                        }
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }
                if !roles.isEmpty {
                    Block(label: "Find on LinkedIn", footer: "Share a posting back to job-to-offer.") {
                        FlowLayout(spacing: 8) {
                            ForEach(roles, id: \.self) { role in
                                Link(destination: JobSearch.linkedIn(role: role)) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "magnifyingglass")
                                        Text(role)
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Ink.violet)
                                    .padding(.horizontal, 12).frame(minHeight: 36)
                                    .overlay { Capsule().strokeBorder(Ink.violet.opacity(0.5), lineWidth: 1.2) }
                                }
                            }
                        }
                    }
                }
                BoardSearchBlock(roles: roles)
            }
            .animation(.snappy, value: items.count)
            .navigationTitle("Inbox")
            .onAppear { roles = ProfileStore().load().targetRoles }
            .navigationDestination(for: IncomingItem.self) { JobDetailView(item: $0) }
            .toolbar {
                ToolbarItem {
                    PasteButton(payloadType: String.self) { strings in
                        if let payload = IncomingItemParser.payload(url: nil, texts: strings) {
                            context.insert(IncomingItem(payload))
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.circle)
                    .tint(Ink.violet)
                }
                // PasteButton draws its own background; the glass circle around it doubled it.
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }
}

/// A shared posting waiting for its check.
struct InboxStub: View {
    let item: IncomingItem
    var body: some View {
        let host = item.url.flatMap { URL(string: $0)?.host() }?.replacingOccurrences(of: "www.", with: "")
        Document {
            HStack {
                FieldLabel(host ?? "Pasted text")
                Spacer()
                Text(item.receivedAt, format: .relative(presentation: .named)).font(.caption).foregroundStyle(Ink.muted)
            }
            HStack(alignment: .center, spacing: 12) {
                Text(item.text ?? item.url ?? "").font(.subheadline).foregroundStyle(Ink.text).lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Ink.muted)
            }
        }
    }
}
