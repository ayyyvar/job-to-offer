import Core
import SwiftData
import SwiftUI
import UIKit

/// "Add to JobScout": stores the shared link or text in the App Group store and closes.
/// The fetch and the model run in the app, not here (extension memory limits).
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        let host = UIHostingController(rootView: ShareView(providers: providers) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

struct ShareView: View {
    let providers: [NSItemProvider]
    let done: () -> Void
    @State private var payload: SharedPayload?
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                if let payload {
                    if let url = payload.url { LabeledContent("Link", value: url) }
                    if let text = payload.text { Text(text).lineLimit(8) }
                } else if loaded {
                    Text("Nothing to add. Share a link or text.")
                } else {
                    ProgressView()
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Add to JobScout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: done) }
                ToolbarItem(placement: .confirmationAction) { Button("Add", action: add).disabled(payload == nil) }
            }
        }
        .task {
            payload = await IncomingItemParser.parse(providers)
            loaded = true
        }
    }

    private func add() {
        guard let payload else { return }
        do {
            let context = ModelContext(try SharedStore.container())
            context.insert(IncomingItem(payload))
            try context.save()
            done()
        } catch {
            self.error = "Could not save: \(error.localizedDescription)"
        }
    }
}
