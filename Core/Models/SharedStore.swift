import Foundation
import SwiftData

/// The SwiftData store both targets open through the App Group container.
public enum SharedStore {
    /// `APP_GROUP_ID` from Signing.xcconfig, which the entitlements read too. The app and the
    /// extension carry it in Info.plist as `JobToOfferAppGroupID`.
    public static let appGroupID = appGroupID(info: Bundle.main.infoDictionary ?? [:])

    static func appGroupID(info: [String: Any]) -> String {
        (info["JobToOfferAppGroupID"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "group.com.example.job-to-offer"
    }

    public enum AddResult: Equatable {
        case added
        case alreadyTracked(TrackedJob)
    }

    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([IncomingItem.self, TrackedJob.self])
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID))
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// Dedup by `JobKey` before insert. `@Attribute(.unique)` alone would upsert and overwrite the
    /// existing row (its status and notes), so an existing key is reported instead.
    public static func add(_ job: TrackedJob, to context: ModelContext) throws -> AddResult {
        let key = job.key
        if let existing = try context.fetch(FetchDescriptor<TrackedJob>(predicate: #Predicate { $0.key == key })).first {
            return .alreadyTracked(existing)
        }
        context.insert(job)
        try context.save()
        return .added
    }
}

extension TrackedJob {
    /// A tracker row from a finished evaluation, in the repo's conventions:
    /// `rank_verdict` = band of the score, vetoes through `location_verdict` / `language_gate`
    /// (rank_state.py). The eligibility gate folds into `location_verdict`: the repo's Location rule
    /// already fails on citizenship or clearance. `fit`: Strong/Good → high, Moderate → medium, else low.
    public convenience init(_ e: Evaluation, sourceURL: String?, today: Date, timeZone: TimeZone) {
        let url = e.fetched?.url ?? sourceURL ?? ""
        let company = e.fetched.flatMap { $0.company.isEmpty ? nil : $0.company } ?? e.posting.company
        let day = Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day()
        let fit = e.fit
        let band = Band(for: fit.overall)
        let vetoed = [fit.eligibility, fit.languageGate, fit.locationVerdict].contains(.fail)
        self.init(title: e.posting.title, company: company, url: url, portal: Self.portal(url), firstSeen: today.formatted(day),
                  fit: vetoed ? "low" : [.strong, .good].contains(band) ? "high" : band == .moderate ? "medium" : "low")
        location = e.posting.location.isEmpty ? nil : e.posting.location
        postedDate = e.fetched?.postedAt?.formatted(day)
        deadline = e.posting.deadline.isEmpty ? nil : e.posting.deadline
        rankScore = fit.overall
        rankVerdict = band.rawValue
        rankDate = today.formatted(day)
        let place = [fit.eligibility, fit.locationVerdict]
        locationVerdict = (place.contains(.fail) ? Verdict.fail : place.contains(.flag) ? .flag : .pass).rawValue
        languageGate = fit.languageGate.rawValue
        languageNote = fit.languageGate == .pass ? nil : fit.languageNote
        strengths = fit.scores.strengths
        gaps = fit.scores.gaps
    }

    static func portal(_ url: String) -> String {
        guard let parsed = URL(string: url), let host = parsed.host() else { return "pasted" }
        return switch ATSDetector.detect(parsed) {
        case .greenhouse: "greenhouse"
        case .lever: "lever"
        case .ashby: "ashby"
        case .html: host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
    }
}
