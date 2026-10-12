/// HTML to plain text without UIKit / AppKit (Core must not import them).
/// Step 3 scope: ATS HTML fragments. Step 4 checks it against full pages.
public enum HTMLText {
    public static func plainText(_ html: String) -> String {
        var text = html
            // Not rendered (script, style, head, template) or site chrome (nav, footer).
            // ponytail: non-greedy match, so a nested <nav> leaks its tail; use a parser if a page shows it.
            .replacing(/<(script|style|head|template|nav|footer)\b.*?<\/\1\s*>/.ignoresCase().dotMatchesNewlines(), with: "")
            .replacing(/<!--.*?-->/.dotMatchesNewlines(), with: "")
            // Source line breaks are spaces in HTML; only tags break lines.
            .replacing(/\s+/, with: " ")
            .replacing(/<br\s*\/?>/.ignoresCase(), with: "\n")
            .replacing(/<li\b[^>]*>/.ignoresCase(), with: "\n\(bullet)")
            .replacing(/<\/?(p|div|h[1-6]|ul|ol|tr|table|section|article|header|blockquote)\b[^>]*>/.ignoresCase(), with: "\n")
            .replacing(/<[^>]*>/, with: "")
        // `<li><p>text` puts a block break after the bullet; keep the bullet on the text's line.
        text = text.replacing(/\x{E000}\s*/, with: "- ")
        text = decodeEntities(text).replacing("\u{00A0}", with: " ")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map {
            $0.replacing(/[ \t]+/, with: " ").trimmingCharacters(in: .whitespaces)
        }
        return lines.joined(separator: "\n")
            .replacing(/\n{3,}/, with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A non-ATS page: `<title>` as the title, the body as text. The company stays empty:
    /// page titles mix it with other words, so the model extracts it.
    public static func posting(html: String, url: String) -> FetchedPosting {
        let title = html.firstMatch(of: /<title\b[^>]*>(.*?)<\/title\s*>/.ignoresCase().dotMatchesNewlines())
            .map { decodeEntities(String($0.output.1)).replacing(/\s+/, with: " ").trimmingCharacters(in: .whitespaces) } ?? ""
        return FetchedPosting(title: title, company: "", url: url,
                              plainText: FetchedPosting.text(title: title, facts: [:], body: linkedInBody(html) ?? plainText(html)),
                              postedAt: nil)
    }

    /// LinkedIn guest pages wrap the job in sign-in forms (1 654 words on the Step 4 fixture);
    /// the description and the criteria list ("Employment type") are 510 of them.
    static func linkedInBody(_ html: String) -> String? {
        guard let description = html.firstMatch(of: /<div class="show-more-less-html__markup[^"]*"[^>]*>(.*?)<\/div>/.dotMatchesNewlines())
        else { return nil }
        let criteria = html.firstMatch(of: /<ul class="description__job-criteria-list[^"]*"[^>]*>(.*?)<\/ul>/.dotMatchesNewlines())
        return [description.output.1, criteria?.output.1].compactMap { $0.map { plainText(String($0)) } }.joined(separator: "\n\n")
    }

    /// Private-use placeholder for a list bullet while tags are replaced.
    static let bullet = "\u{E000}"

    public static func decodeEntities(_ text: String) -> String {
        text.replacing(/&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/) { match in
            let name = String(match.output.1)
            let scalar: Unicode.Scalar? = if name.hasPrefix("#x") || name.hasPrefix("#X") {
                UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init)
            } else if name.hasPrefix("#") {
                UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init)
            } else {
                named[name]
            }
            return scalar.map { String(Character($0)) } ?? String(match.output.0)
        }
    }

    static let named: [String: Unicode.Scalar] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "ndash": "\u{2013}", "mdash": "\u{2014}", "lsquo": "\u{2018}", "rsquo": "\u{2019}",
        "ldquo": "\u{201C}", "rdquo": "\u{201D}", "hellip": "\u{2026}", "bull": "\u{2022}",
        "middot": "\u{00B7}", "euro": "\u{20AC}", "pound": "\u{00A3}", "copy": "\u{00A9}",
        "reg": "\u{00AE}", "trade": "\u{2122}",
    ]
}
