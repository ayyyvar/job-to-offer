import CryptoKit
import Foundation

/// Canonical dedup key for a job posting: a port of `tools/job_key.py` from the ai-job-search repo.
/// The same posting must give the same key in both, because the app and the Python tools
/// share `seen_jobs.json`. `JobKeyTests` pins the Python outputs.
public enum JobKey {
    static let companyMax = 40
    static let titleMax = 60
    static let hashLength = 6

    public static func make(company: String, title: String, url: String = "") -> String {
        var companySlug = cap(slugify(company), limit: companyMax)
        if companySlug.isEmpty {
            // An absent name stays unknown; a non-Latin name still has an identity.
            // `folding(.caseInsensitive)` + NFC matches Python's `casefold()` + NFC.
            let name = company.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: .caseInsensitive, locale: nil)
                .precomposedStringWithCanonicalMapping
            companySlug = name.isEmpty ? "unknown-company" : "company-\(sha1(name))"
        }
        var titleSlug = cap(slugify(title), limit: titleMax)
        if titleSlug.isEmpty {
            // No Latin characters in the title. The portal's own numeric id is the only
            // stable handle left; never emit a bare "company_" prefix.
            if let id = url.firstMatch(of: /\d{6,}/) {
                titleSlug = String(id.output)
            } else {
                let basis = slugify(title.isEmpty ? url : title)
                titleSlug = basis.isEmpty ? "untitled-\(sha1(title + url))" : basis
            }
        }
        return "\(companySlug)_\(titleSlug)"
    }

    /// Structurally safe as a dedup key and as an archive folder name:
    /// `<company-slug>_<title-slug>`. Stricter than Python, whose `$` also accepts a trailing "\n".
    public static func isCanonical(_ key: String) -> Bool {
        key.wholeMatch(of: /[a-z0-9][a-z0-9-]*_[a-z0-9][a-z0-9-]*/) != nil
    }

    /// Lowercase ASCII slug: NFKD, drop non-ASCII, every run outside `[a-z0-9]` becomes "-".
    /// Non-Latin scripts legitimately reduce to "".
    static func slugify(_ text: String) -> String {
        let ascii = String(String.UnicodeScalarView(
            text.decomposedStringWithCompatibilityMapping.unicodeScalars.filter(\.isASCII)
        ))
        return ascii.lowercased()
            .replacing(/[^a-z0-9]+/, with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Caps the length and appends a hash of the full slug, so a long title always gives
    /// the same key and two different long titles never collide.
    static func cap(_ slug: String, limit: Int) -> String {
        guard slug.count > limit else { return slug }
        var head = String(slug.prefix(limit))
        while head.hasSuffix("-") { head.removeLast() }
        return "\(head)-\(sha1(slug))"
    }

    static func sha1(_ text: String) -> String {
        let hex = Insecure.SHA1.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(hashLength))
    }
}
