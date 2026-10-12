/// What the on-device model reports at launch. The app fills it from `SystemLanguageModel`;
/// Core only formats it, so the probe screen stays testable without Apple Intelligence.
public struct ModelCapability: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case available
        case unavailable(reason: String)
    }

    public var status: Status
    public var contextSize: Int
    public var supportedLanguages: [String]

    public init(status: Status, contextSize: Int, supportedLanguages: [String]) {
        self.status = status
        self.contextSize = contextSize
        self.supportedLanguages = supportedLanguages
    }

    public var statusText: String {
        switch status {
        case .available: "Available"
        case .unavailable(let reason): "Unavailable: \(reason)"
        }
    }
}
