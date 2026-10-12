import Core
import SwiftData
import SwiftUI

/// Company boards on Greenhouse, Lever and Ashby that the Inbox search reads.
struct BoardsView: View {
    private let store = ProfileStore()
    @State private var boards: [BoardWatch.Board] = ProfileStore().loadBoards()
    @State private var newURL = ""
    @State private var showImporter = false
    @State private var status: String?
    @Query private var tracked: [TrackedJob]

    var body: some View {
        List {
            Section {
                TextField("https://jobs.lever.co/company", text: $newURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .onSubmit(addURL)
                Button("Add from tracked jobs", systemImage: "list.bullet.rectangle") {
                    merge(BoardWatch.boards(fromURLs: tracked.map(\.url)))
                }
                Button("Import seen_jobs.json", systemImage: "square.and.arrow.down") { showImporter = true }
                    .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { importSeenJobs($0) }
                if let status {
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }
            } footer: {
                Text("Paste a Greenhouse, Lever or Ashby link. No account needed.")
            }
            Section {
                ForEach(boards, id: \.self) { board in
                    HStack(spacing: 12) {
                        Text(board.token).font(.headline).foregroundStyle(Ink.text)
                        Spacer()
                        InkTag(text: board.vendor, color: Ink.muted)
                    }
                }
                .onDelete { boards.remove(atOffsets: $0) }
            } header: {
                FieldLabel("Watching \(boards.count)")
            }
        }
        .paperList()
        .animation(.snappy, value: boards)
        .navigationTitle("Company boards")
        .onChange(of: boards) { _, new in store.saveBoards(new) }
    }

    private func addURL() {
        guard let board = BoardWatch.Board(url: newURL.trimmingCharacters(in: .whitespaces)) else {
            status = "Not a Greenhouse, Lever or Ashby link."
            return
        }
        merge([board])
        newURL = ""
    }

    private func merge(_ new: [BoardWatch.Board]) {
        let before = boards.count
        boards = Array(Set(boards + new)).sorted()
        status = "Added \(boards.count - before) boards."
    }

    private func importSeenJobs(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { status = "Could not open the file."; return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        struct Seen: Decodable { struct Entry: Decodable { var url: String? }; var seen: [String: Entry] }
        guard let data = try? Data(contentsOf: url), let seen = try? JSONDecoder().decode(Seen.self, from: data) else {
            status = "Not a seen_jobs.json file."
            return
        }
        merge(BoardWatch.boards(fromURLs: seen.seen.values.compactMap(\.url)))
    }
}

/// Inbox block: search every watched board for the target roles, add matches to the Inbox.
struct BoardSearchBlock: View {
    let roles: [String]
    @Environment(\.modelContext) private var context
    @Query private var items: [IncomingItem]
    @Query private var tracked: [TrackedJob]
    @State private var results: [BoardWatch.Listing] = []
    @State private var searching = false
    @State private var searched = false

    var body: some View {
        let boards = ProfileStore().loadBoards()
        let known = Set(items.compactMap(\.url) + tracked.map(\.url))
        let fresh = results.filter { !known.contains($0.url) }
        Block(label: "Company boards",
              footer: boards.isEmpty ? "Add company boards in Profile." : "Titles that contain every word of a target role.") {
            Button {
                Task {
                    searching = true
                    results = await BoardWatch.search(boards, roles: roles)
                    searching = false
                    searched = true
                }
            } label: {
                HStack(spacing: 8) {
                    if searching { ProgressView().tint(.white) } else { Image(systemName: "building.2") }
                    Text(searching ? "Searching \(boards.count) boards" : "Search \(boards.count) company boards")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(searching || boards.isEmpty || roles.isEmpty)
            if searched && fresh.isEmpty {
                Text("No new matches.").font(.subheadline).foregroundStyle(Ink.muted).padding(.horizontal, 4)
            }
            if !fresh.isEmpty {
                RuledRows(data: fresh.map(\.url)) { url in
                    if let listing = fresh.first(where: { $0.url == url }) { row(listing) }
                }
            }
        }
    }

    private func row(_ listing: BoardWatch.Listing) -> some View {
        let place = [listing.company, listing.location].filter { !$0.isEmpty }.joined(separator: ", ")
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title).font(.subheadline.weight(.semibold)).foregroundStyle(Ink.text)
                Text(place).font(.caption).foregroundStyle(Ink.muted)
            }
            Spacer()
            Button("Add to Inbox", systemImage: "plus.circle") {
                context.insert(IncomingItem(SharedPayload(url: listing.url, text: nil)))
            }
            .labelStyle(.iconOnly).font(.title3).foregroundStyle(Ink.violet)
            .frame(minWidth: 44, minHeight: 44)
        }
    }
}

extension BoardWatch.Board {
    var vendor: String {
        switch self { case .greenhouse: "Greenhouse"; case .lever: "Lever"; case .ashby: "Ashby" }
    }
}
