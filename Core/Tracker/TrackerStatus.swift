/// The tracker CSV `status` vocabulary from `/outcome` ("Tracker status vocabulary").
public enum TrackerStatus: String, Codable, CaseIterable, Sendable {
    case drafted, applied, interview, offer, hired, rejected
    case noResponse = "no_response"
    case offerDeclined = "offer_declined"
    case withdrawn

    /// Also reads the legacy space spellings `no response` / `offer declined`,
    /// so existing trackers load without a migration. `rawValue` never writes them.
    public init?(rawValue: String) {
        switch rawValue {
        case "drafted": self = .drafted
        case "applied": self = .applied
        case "interview": self = .interview
        case "offer": self = .offer
        case "hired": self = .hired
        case "rejected": self = .rejected
        case "no_response", "no response": self = .noResponse
        case "offer_declined", "offer declined": self = .offerDeclined
        case "withdrawn": self = .withdrawn
        default: return nil
        }
    }

    /// The application is closed. `drafted` is open: nothing was sent.
    public var isFinal: Bool {
        switch self {
        case .hired, .rejected, .noResponse, .offerDeclined, .withdrawn: true
        case .drafted, .applied, .interview, .offer: false
        }
    }
}
