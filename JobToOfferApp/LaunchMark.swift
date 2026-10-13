import SwiftUI

/// A logo road: one continuous line that writes words (logos/round5, logos/round6).
struct Road {
    let d: String
    let size: CGSize
    let tittle: CGPoint
    let end: CGPoint
    var origin: CGPoint = .zero

    /// "job" on the app icon (logos/round5/job-c1.svg, translate(6 10) baked in).
    static let job = Road(
        d: "M39.2 377.3 A37 37 0 1 0 111 390 L111 295 C111 248 172 310 188.4 265.8 A56 56 0 0 1 241 229 A56 56 0 0 1 297 285 A56 56 0 0 1 241 341 A56 56 0 0 1 188.4 265.8 A56 56 0 0 1 241 229 L407 229 A56 56 0 0 1 407 341 A56 56 0 0 1 351 285 L351 115",
        size: CGSize(width: 512, height: 512), tittle: CGPoint(x: 111, y: 206), end: CGPoint(x: 351, y: 115))

    /// "job" over "to offer", one road (logos/round7/job-to-offer-2l-v3.svg, viewBox -30 60 1031 760).
    static let jobToOffer = Road(
        d: "M 308.2 377.3 A 37 37 0 1 0 380 390 L 380 295 C 380 248 441 310 457.4 265.8 A 56 56 0 0 1 510 229 A 56 56 0 0 1 566 285 A 56 56 0 0 1 510 341 A 56 56 0 0 1 457.4 265.8 A 56 56 0 0 1 510 229 L 676 229 A 56 56 0 0 1 676 341 A 56 56 0 0 1 620 285 L 620 115 L 620 341 L 676 341 C 716 341 740 365 740 405 C 740 450 710 480 670 480 L 60 480 C 20 480 20 629 61 629 L 136 629 L 96 629 L 96 575 L 96 710 A 31 31 0 0 0 127 741 L 216 741 A 56 56 0 0 0 272 685 A 56 56 0 0 0 216 629 A 56 56 0 0 0 160 685 A 56 56 0 0 0 216 741 A 56 56 0 0 0 272 685 C 320 665 352 705 400 685 A 56 56 0 0 1 456 629 A 56 56 0 0 1 512 685 A 56 56 0 0 1 456 741 A 56 56 0 0 1 400 685 A 56 56 0 0 1 456 629 L 566 629 L 566 570 A 40 40 0 0 1 606 530 A 40 40 0 0 0 566 570 L 566 741 L 566 629 L 701 629 L 666 629 L 666 570 A 40 40 0 0 1 706 530 A 40 40 0 0 0 666 570 L 666 741 C 696 741 720 710 720 685 L 832 685 A 56 56 0 0 0 720 685 A 56 56 0 0 0 815.6 724.6 L 876 741 L 876 629 L 876 679 A 50 50 0 0 1 926 629 L 941 629",
        size: CGSize(width: 1031, height: 760), tittle: CGPoint(x: 380, y: 206), end: CGPoint(x: 941, y: 629),
        origin: CGPoint(x: -30, y: 60))

    /// Absolute M/L/C/A with circular arcs only: enough for these paths.
    var path: Path {
        var p = Path()
        // Commands may come glued to numbers ("M33.2"): split them off first.
        let t = d.replacing(/([MLCA])/) { " \($0.1) " }.split(separator: " ")
        var i = 0, cur = CGPoint.zero
        func num() -> CGFloat { defer { i += 1 }; return CGFloat(Double(t[i])!) }
        func pt() -> CGPoint { let x = num(); return CGPoint(x: x, y: num()) }
        while i < t.count {
            let cmd = t[i]; i += 1
            switch cmd {
            case "M": cur = pt(); p.move(to: cur)
            case "L": cur = pt(); p.addLine(to: cur)
            case "C": let c1 = pt(), c2 = pt(); cur = pt(); p.addCurve(to: cur, control1: c1, control2: c2)
            case "A":
                let r = num(); _ = num(); _ = num()
                let large = num() == 1, sweep = num() == 1
                let end = pt()
                // SVG endpoint arc → center.
                let mid = CGPoint(x: (cur.x + end.x) / 2, y: (cur.y + end.y) / 2)
                let dx = end.x - cur.x, dy = end.y - cur.y, chord = hypot(dx, dy)
                let h = sqrt(max(r * r - chord * chord / 4, 0)) * (large == sweep ? -1 : 1)
                let center = CGPoint(x: mid.x - h * dy / chord, y: mid.y + h * dx / chord)
                let a0 = atan2(cur.y - center.y, cur.x - center.x), a1 = atan2(end.y - center.y, end.x - center.x)
                // SwiftUI's flag is mirrored in y-down space: SVG sweep 1 = clockwise false.
                p.addArc(center: center, radius: r, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: !sweep)
                cur = end
            default: return p
            }
        }
        return p
    }
}

private let paper = Color(light: 0xF3F5F4, dark: 0xF3F5F4), green = Color(light: 0x2F6F5E, dark: 0x2F6F5E)
private let violet = Color(light: 0x5B3FA8, dark: 0x5B3FA8), amber = Color(light: 0xE0A23B, dark: 0xE0A23B)

/// A road mark; `progress` 0…1 draws the road behind the violet dot, the amber dot lights at the end.
struct LogoMark: View {
    var road: Road = .job
    var progress: CGFloat = 1

    var body: some View {
        let path = road.path
        Canvas { context, size in
            let s = min(size.width / road.size.width, size.height / road.size.height)
            context.scaleBy(x: s, y: s)
            context.translateBy(x: -road.origin.x, y: -road.origin.y)
            let drawn = path.trimmedPath(from: 0, to: max(progress, 0.0001))
            context.stroke(drawn, with: .color(paper), style: StrokeStyle(lineWidth: 32, lineCap: .round, lineJoin: .round))
            context.stroke(drawn, with: .color(green), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [12, 12]))
            func dot(_ c: CGPoint, _ color: Color) {
                context.fill(Path(ellipseIn: CGRect(x: c.x - 19, y: c.y - 19, width: 38, height: 38)), with: .color(color))
            }
            dot(road.tittle, paper)
            if progress >= 1 { dot(road.end, amber) } else { dot(drawn.currentPoint ?? .zero, violet) }
        }
        .aspectRatio(road.size.width / road.size.height, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Launch overlay: the dot travels from "job" down to "to offer", then the screen fades out.
struct LaunchOverlay: View {
    @Binding var shown: Bool
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            green.ignoresSafeArea()
            LogoMark(road: .jobToOffer, progress: progress).padding(.horizontal, 40)
        }
        .accessibilityElement()
        .accessibilityLabel("job to offer")
        .contentShape(.rect)
        .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { shown = false } } // tap skips the intro
        .task {
            if reduceMotion { progress = 1 } else {
                // ponytail: discrete steps drive the Canvas; a TimelineView is smoother if 60 steps ever look choppy.
                let steps = 60
                for k in 1...steps {
                    try? await Task.sleep(for: .milliseconds(1200 / steps))
                    let t = CGFloat(k) / CGFloat(steps)
                    progress = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
                }
            }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeOut(duration: 0.3)) { shown = false }
        }
    }
}
