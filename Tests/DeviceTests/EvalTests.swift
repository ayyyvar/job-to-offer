import Core
import Foundation
import FoundationModels
@testable import JobScout
import Testing

/// Step 7 eval: the app's band vs the band `/rank` stored for the same posting. Tolerance is one band;
/// the bar is 70 % (7 of 10 on dev). Dev tuned the FitRubric tables; Holdout was scored once with the
/// frozen tables (docs/MODEL_BEHAVIOR.md §7). Do not tune goldens, fixtures or tables to pass Holdout.
@Suite struct EvalTests {
    struct Entry: Decodable {
        let file: String
        let rank_score: Int
        let expected_band: String
    }

    @MainActor
    @Test(.tags(.onDevice), .timeLimit(.minutes(60)), arguments: [
        ("Eval/manifest_2026-09-27.json", 7), ("Eval/Holdout/manifest_holdout_2026-09-27.json", 18),
        ("Eval/Holdout2/manifest_holdout2_2026-09-28.json", 13),
        ("Eval/Low/manifest_low_2026-09-28.json", 12),
    ])
    func evalSetBandsLandWithinOneBand(manifest: String, minHits: Int) async throws {
        guard SystemLanguageModel.default.isAvailable else {
            print("skip: on-device model unavailable: \(SystemLanguageModel.default.availability)")
            return
        }
        let folder = (manifest as NSString).deletingLastPathComponent
        let entries = try JSONDecoder().decode([Entry].self, from: Fixture.load(manifest))
        var rows = ["| Fixture | Expected | Repo score | App band | App overall | T/E/B/C | Gates E/L/Loc | Within 1 |", "|---|---|---|---|---|---|---|---|"]
        var hits = 0, exact = 0, pairs: [(app: Int, ref: Int)] = []
        for entry in entries {
            let model = ParseModel(client: FoundationModelsClient(), profile: CandidateProfile.fixture)
            await model.run(text: try Fixture.string("\(folder)/\(entry.file)"))
            let expected = try #require(Band(rawValue: entry.expected_band))
            switch model.state {
            case .done(let e):
                let distance = abs(Band.allCases.firstIndex(of: e.fit.band)! - Band.allCases.firstIndex(of: expected)!)
                if distance <= 1 { hits += 1 }
                if distance == 0 { exact += 1 }
                pairs.append((e.fit.overall, entry.rank_score))
                let s = e.fit.scores
                rows.append("| \(entry.file) | \(expected.rawValue) | \(entry.rank_score) | \(e.fit.band.rawValue) | \(e.fit.overall) | \(s.technical)/\(s.experience)/\(s.behavioral)/\(s.career) | \(e.fit.eligibility.rawValue)/\(e.fit.languageGate.rawValue)/\(e.fit.locationVerdict.rawValue) | \(distance <= 1 ? "yes" : "no") |")
            default:
                rows.append("| \(entry.file) | \(expected.rawValue) | \(entry.rank_score) | \(model.state) | - | - | - | no |")
            }
        }
        let diffs = pairs.map { Double($0.app - $0.ref) }
        rows.append("Within one band: \(hits) of \(entries.count). Exact band: \(exact). "
            + String(format: "MAE %.1f, bias %+.1f, Spearman %.2f (scored %d)", diffs.map(abs).reduce(0, +) / Double(max(pairs.count, 1)),
                     diffs.reduce(0, +) / Double(max(pairs.count, 1)), Self.spearman(pairs.map(\.app), pairs.map(\.ref)), pairs.count))
        print("EVAL TABLE \(manifest)\n" + rows.joined(separator: "\n") + "\nEND EVAL TABLE")
        #expect(hits >= minHits)
    }

    /// GatesReal: real postings `/scrape` skipped for location. Combined location + eligibility must
    /// not be PASS (docs/MODEL_BEHAVIOR.md §7.3a). First run 15/16, after the `sponsors` fix 16/16.
    @MainActor
    @Test(.tags(.onDevice), .timeLimit(.minutes(60)))
    func gatesRealPostingsAreNeverPlacePass() async throws {
        guard SystemLanguageModel.default.isAvailable else {
            print("skip: on-device model unavailable: \(SystemLanguageModel.default.availability)")
            return
        }
        struct Gate: Decodable { let file: String }
        let manifest = "Eval/GatesReal/manifest_gates_2026-09-28.json"
        let entries = try JSONDecoder().decode([Gate].self, from: Fixture.load(manifest))
        var rows = ["| Fixture | Eligibility | Location | Place verdict |", "|---|---|---|---|"]
        var notPass = 0
        for entry in entries {
            let model = ParseModel(client: FoundationModelsClient(), profile: CandidateProfile.fixture)
            await model.run(text: try Fixture.string("Eval/GatesReal/\(entry.file)"))
            guard case .done(let e) = model.state else {
                rows.append("| \(entry.file) | \(model.state) | - | - |")
                continue
            }
            let place: Verdict = [e.fit.eligibility, e.fit.locationVerdict].contains(.fail) ? .fail
                : [e.fit.eligibility, e.fit.locationVerdict].contains(.flag) ? .flag : .pass
            if place != .pass { notPass += 1 }
            rows.append("| \(entry.file) | \(e.fit.eligibility.rawValue) | \(e.fit.locationVerdict.rawValue) | \(place.rawValue) |")
        }
        print("EVAL TABLE \(manifest)\n" + rows.joined(separator: "\n") + "\nNot PASS: \(notPass) of \(entries.count)\nEND EVAL TABLE")
        #expect(notPass >= 15)
    }

    /// Rank correlation with average ranks for ties: the Inbox sorts by score, so order matters most.
    static func spearman(_ a: [Int], _ b: [Int]) -> Double {
        func ranks(_ x: [Int]) -> [Double] {
            let order = x.indices.sorted { x[$0] < x[$1] }
            var r = [Double](repeating: 0, count: x.count), i = 0
            while i < order.count {
                var j = i
                while j + 1 < order.count, x[order[j + 1]] == x[order[i]] { j += 1 }
                for k in i...j { r[order[k]] = Double(i + j) / 2 + 1 }
                i = j + 1
            }
            return r
        }
        let ra = ranks(a), rb = ranks(b), n = Double(a.count)
        let ma = ra.reduce(0, +) / n, mb = rb.reduce(0, +) / n
        let cov = zip(ra, rb).map { ($0 - ma) * ($1 - mb) }.reduce(0, +)
        let va = ra.map { ($0 - ma) * ($0 - ma) }.reduce(0, +), vb = rb.map { ($0 - mb) * ($0 - mb) }.reduce(0, +)
        return va == 0 || vb == 0 ? 0 : cov / (va * vb).squareRoot()
    }
}
