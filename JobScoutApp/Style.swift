import Core
import SwiftUI
import UIKit

// Passport-control world: cool security paper, guilloche green, stamp inks, one violet tint.
// Rule: job documents are custom cards (10 pt, hairline, no shadow); settings-shaped forms stay
// system grouped lists on the same paper. Tags are capsules; buttons share the 10 pt corner.

extension Color {
    init(light: UInt32, dark: UInt32) {
        func ui(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

enum Ink {
    static let paper = Color(light: 0xF3F5F4, dark: 0x0F1513)
    static let card = Color(light: 0xFFFFFF, dark: 0x18201D)
    static let text = Color(light: 0x1E2622, dark: 0xE6ECE9)
    static let muted = Color(light: 0x56645E, dark: 0x9AAAA3)
    static let rule = Color(light: 0xD5DCD8, dark: 0x2C3833)
    static let green = Color(light: 0x2F6F5E, dark: 0x6DBFA3)
    static let amber = Color(light: 0xA86300, dark: 0xF2A93B)
    static let burgundy = Color(light: 0x8A2333, dark: 0xF07A8A)
    static let violet = Color(light: 0x5B3FA8, dark: 0xA894F0)
}

extension Font {
    /// Heavy condensed SF for document titles; follows Dynamic Type.
    static func display(_ style: Font.TextStyle) -> Font { .system(style, weight: .heavy).width(.condensed) }
}

/// Large and inline navigation titles in the document face. Call once at launch.
@MainActor func styleNavigationTitles() {
    func font(_ size: CGFloat, _ style: UIFont.TextStyle) -> UIFont {
        UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: size, weight: .heavy, width: .condensed))
    }
    let bar = UINavigationBar.appearance()
    bar.largeTitleTextAttributes = [.font: font(36, .largeTitle), .foregroundColor: UIColor(Ink.text)]
    bar.titleTextAttributes = [.font: font(18, .headline), .foregroundColor: UIColor(Ink.text)]
}

extension Verdict {
    var color: Color { switch self { case .pass: Ink.green; case .flag: Ink.amber; case .fail: Ink.burgundy } }
    var icon: String { switch self { case .pass: "checkmark.circle.fill"; case .flag: "questionmark.circle.fill"; case .fail: "xmark.circle.fill" } }
    /// FLAG reads "check": the app is not sure and the user should look.
    var word: String { switch self { case .pass: "Pass"; case .flag: "Check"; case .fail: "Fail" } }
}

func scoreColor(_ score: Int?) -> Color {
    switch score ?? 0 { case 75...: Ink.green; case 60...: Ink.violet; case 45...: Ink.amber; default: Ink.burgundy }
}

/// Field label, as on a passport page.
struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(.caption, weight: .semibold).width(.condensed))
            .tracking(0.8)
            .foregroundStyle(Ink.muted)
    }
}

/// Fine security-print lines, drawn once per size.
struct Guilloche: View {
    var color: Color = Ink.green
    var body: some View {
        Canvas { context, size in
            for i in 0..<14 {
                var path = Path()
                let phase = Double(i) * .pi / 7, amp = size.height * 0.36
                for x in stride(from: 0.0, through: size.width, by: 2) {
                    let t = x / size.width * .pi * 6
                    let y = size.height / 2 + amp * sin(t + phase) * cos(t / 3 - phase)
                    x == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                }
                context.stroke(path, with: .color(color.opacity(0.22)), lineWidth: 0.6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A document card: white paper, hairline rule, 10 pt corners.
struct Document<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.card, in: .rect(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Ink.rule, lineWidth: 1) }
    }
}

/// A labeled block of a scrolling screen.
struct Block<Content: View>: View {
    let label: String
    var footer: String? = nil
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(label).padding(.leading, 4)
            content
            if let footer { Text(footer).font(.footnote).foregroundStyle(Ink.muted).padding(.horizontal, 4) }
        }
    }
}

/// Paper ground for every screen.
struct PaperScreen<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) { content }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 32)
        }
        .background(Ink.paper.ignoresSafeArea())
    }
}

extension View {
    /// System grouped list on the document paper: for settings-shaped screens.
    func paperList() -> some View {
        scrollContentBackground(.hidden).background(Ink.paper.ignoresSafeArea())
    }
}

/// Full-width violet action with a press response.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Ink.violet.opacity(enabled ? 1 : 0.4), in: .rect(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

/// Outlined ink tag: tracker status, skills.
struct InkTag: View {
    let text: String, color: Color
    var body: some View {
        Text(text)
            .font(.system(.subheadline, weight: .semibold).width(.condensed))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .overlay { Capsule().strokeBorder(color.opacity(0.6), lineWidth: 1.2) }
    }
}

/// A gate verdict stamped on the job document. Stamps land one after another.
struct Stamp: View {
    let gate: String
    let verdict: Verdict
    let index: Int
    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 1) {
            Text(gate.uppercased()).font(.system(.caption2, weight: .bold).width(.condensed)).tracking(0.6)
            Text(verdict.word.uppercased()).font(.display(.title3))
        }
        .foregroundStyle(verdict.color)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(minWidth: 84)
        .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(verdict.color, lineWidth: 2) }
        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(verdict.color.opacity(0.7), lineWidth: 0.75).padding(4) }
        .rotationEffect(.degrees([-5, 3, -2][index % 3]))
        .scaleEffect(landed || reduceMotion ? 1 : 1.3)
        .opacity(landed ? 0.92 : 0)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.32, bounce: 0.2).delay(Double(index) * 0.07), value: landed)
        .sensoryFeedback(.impact(weight: .light), trigger: landed)
        .onAppear { landed = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(gate): \(verdict.word)")
    }
}

/// Machine-readable lines built from the real dedup key, as at the foot of a passport page.
struct MRZ: View {
    let key: String
    let date: String
    let score: Int?
    var body: some View {
        let line1 = pad("J<SCOUT<<" + key.uppercased().map { $0.isLetter || $0.isNumber ? String($0) : "<" }.joined())
        let line2 = pad(date.filter(\.isNumber) + "<<" + (score.map { String(format: "%03d", $0) } ?? "<<<"))
        VStack(alignment: .leading, spacing: 2) { Text(line1); Text(line2) }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(Ink.muted)
            .lineLimit(1).minimumScaleFactor(0.6)
            .accessibilityHidden(true)
    }
    private func pad(_ s: String) -> String { String((s + String(repeating: "<", count: 44)).prefix(44)) }
}

/// The job as a document page: issuer band, title, fields, stamps, machine line.
struct JobDocument: View {
    let company: String
    let title: String
    let facts: [(String, String)]
    let score: Int?
    let band: String?
    let gates: [(String, Verdict)]
    let key: String
    let date: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                Guilloche()
                Text((company.isEmpty ? "Employer not named" : company).uppercased())
                    .font(.system(.footnote, weight: .bold).width(.condensed)).tracking(1.2)
                    .foregroundStyle(Ink.green)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Ink.card, in: .rect(cornerRadius: 3))
                    .padding(.horizontal, 10)
            }
            .frame(height: 44)
            .background(Ink.green.opacity(0.06))
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Text(title).font(.display(.title)).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    if let score {
                        VStack(alignment: .trailing, spacing: 0) {
                            FieldLabel("Fit estimate")
                            Text("\(score)").font(.display(.largeTitle)).foregroundStyle(scoreColor(score)).monospacedDigit()
                                .contentTransition(.numericText())
                            if let band { Text(band).font(.caption.weight(.semibold)).foregroundStyle(Ink.muted) }
                        }
                        .animation(.snappy, value: score)
                    }
                }
                let shown = facts.filter { !$0.1.isEmpty }
                if !shown.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], alignment: .leading, spacing: 10) {
                        ForEach(shown, id: \.0) { fact in
                            VStack(alignment: .leading, spacing: 2) {
                                FieldLabel(fact.0)
                                Text(fact.1).font(.subheadline).foregroundStyle(Ink.text).lineLimit(2)
                            }
                        }
                    }
                }
                if !gates.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(gates.enumerated()), id: \.offset) { i, gate in Stamp(gate: gate.0, verdict: gate.1, index: i) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                MRZ(key: key, date: date, score: score)
            }
            .padding(16)
        }
        .background(Ink.card)
        .clipShape(.rect(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Ink.rule, lineWidth: 1) }
    }
}

/// One horizontal bar per score dimension. Flat fill over a hairline, no track.
struct ScoreBar: View {
    let name: String
    let value: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(name).font(.subheadline).foregroundStyle(Ink.text)
                Spacer()
                Text("\(value)").font(.system(.subheadline, weight: .bold).width(.condensed)).monospacedDigit().contentTransition(.numericText())
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Ink.rule).frame(height: 1)
                    Rectangle().fill(scoreColor(value)).frame(width: g.size.width * CGFloat(value) / 100, height: 4)
                }
            }
            .frame(height: 4)
        }
        .animation(.snappy, value: value)
    }
}

/// A row that opens another screen: violet symbol, title, subtitle.
struct MenuRow<Destination: View>: View {
    let title: String, subtitle: String, icon: String
    let destination: () -> Destination
    init(_ title: String, _ subtitle: String, _ icon: String, @ViewBuilder destination: @escaping () -> Destination) {
        (self.title, self.subtitle, self.icon, self.destination) = (title, subtitle, icon, destination)
    }
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title3).foregroundStyle(Ink.violet).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(Ink.text)
                    Text(subtitle).font(.subheadline).foregroundStyle(Ink.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Ink.muted)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Rows inside one document, split by hairlines.
struct RuledRows<Data: RandomAccessCollection, Row: View>: View where Data.Element: Hashable {
    let data: Data
    @ViewBuilder let row: (Data.Element) -> Row
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.enumerated()), id: \.element) { i, element in
                if i > 0 { Rectangle().fill(Ink.rule).frame(height: 1) }
                row(element).padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 4)
        .background(Ink.card, in: .rect(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Ink.rule, lineWidth: 1) }
    }
}

/// Inline count line ("7 tracked · 2 applied"): replaces stat tiles.
struct CountLine: View {
    let counts: [(String, Int, Color)]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(counts.enumerated()), id: \.offset) { i, c in
                if i > 0 { Rectangle().fill(Ink.rule).frame(width: 1, height: 36) }
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(c.1)").font(.display(.title)).foregroundStyle(c.2).monospacedDigit().contentTransition(.numericText())
                    FieldLabel(c.0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, i > 0 ? 14 : 0)
            }
        }
        .animation(.snappy, value: counts.map(\.1))
    }
}
