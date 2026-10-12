import Foundation
import SwiftData

public struct SharedPayload: Equatable, Sendable {
    public var url: String?
    public var text: String?

    public init(url: String?, text: String?) {
        self.url = url
        self.text = text
    }
}

/// A shared URL or text waiting in the Inbox. The share extension writes it; the app parses it.
@Model
public final class IncomingItem {
    public var url: String?
    public var text: String?
    public var receivedAt: Date

    public init(_ payload: SharedPayload, receivedAt: Date = .now) {
        url = payload.url
        text = payload.text
        self.receivedAt = receivedAt
    }
}

/// Share sheet payloads → one `SharedPayload`. A pasted URL arrives as plain text, so the text is
/// searched for an http(s) link. `NSDataDetector` is not used: it reads "Zapp.new" as a link.
public enum IncomingItemParser {
    /// `nonisolated(nonsending)`: runs on the caller's actor, because `NSItemProvider` is not `Sendable`.
    nonisolated(nonsending) public static func parse(_ providers: [NSItemProvider]) async -> SharedPayload? {
        var url: String?
        var texts: [String] = []
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self), let value = await load(URL.self, from: provider),
               ["http", "https"].contains(value.scheme?.lowercased() ?? "") {
                url = url ?? value.absoluteString
            } else if provider.canLoadObject(ofClass: String.self), let value = await load(String.self, from: provider) {
                texts.append(value)
            }
        }
        return payload(url: url, texts: texts)
    }

    /// The text part of `parse`, also used by the Inbox paste button.
    public static func payload(url: String?, texts: [String]) -> SharedPayload? {
        var url = url
        let text = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "\n")
        if url == nil, let match = text.firstMatch(of: /https?:\/\/[^\s<>"]+/) {
            url = String(match.output).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?)]}'"))
        }
        guard url != nil || !text.isEmpty else { return nil }
        return SharedPayload(url: url, text: text.isEmpty || text == url ? nil : text)
    }

    nonisolated(nonsending) static func load<T: _ObjectiveCBridgeable & Sendable>(_ type: T.Type, from provider: NSItemProvider) async -> T?
    where T._ObjectiveCType: NSItemProviderReading {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: type) { value, _ in continuation.resume(returning: value) }
        }
    }
}
