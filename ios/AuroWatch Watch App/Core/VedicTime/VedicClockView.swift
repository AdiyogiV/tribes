import SwiftUI

/// Minimal Vedic clock — transparent background, bold white lines only.
struct VedicClockView: View {
    let date: Date
    let isDark: Bool
    var size: CGFloat = 150

    static let praharNames = [
        "purvanha", "madhyanha", "aparanha", "sayanha",
        "pradosha", "nishitha", "triyama", "usha",
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2
            let vt = VedicTimeCalculator.calculate(from: date)

            drawPraharRing(
                context: context, center: center, radius: radius, currentIdx: vt.praharIndex)
            drawGhatiRing(context: context, center: center, radius: radius, ghati: vt.ghatiFloat, pala: vt.palaFloat)
            drawHands(
                context: context, center: center, radius: radius,
                ghati: vt.ghatiFloat, pala: vt.palaFloat)
            drawCenterDot(context: context, center: center, radius: radius)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Prahar Ring

    private func drawPraharRing(
        context: GraphicsContext, center: CGPoint, radius: CGFloat, currentIdx: Int
    ) {
        let ringR = radius * 0.76

        // 8 prahar spoke lines (dividers from center outward, no circle)
        for i in 0..<8 {
            let angle = Angle.degrees(-90 + Double(i) * 45)
            let innerEnd = radius * 0.12
            let outerEnd = ringR
            var spoke = Path()
            spoke.move(to: CGPoint(
                x: center.x + innerEnd * cos(angle.radians),
                y: center.y + innerEnd * sin(angle.radians)))
            spoke.addLine(to: CGPoint(
                x: center.x + outerEnd * cos(angle.radians),
                y: center.y + outerEnd * sin(angle.radians)))
            context.stroke(
                spoke, with: .color(Color.white.opacity(0.12)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }

        // 8 prahar labels
        for i in 0..<8 {
            // Prahar number — inside, smaller
            let midAngle = Angle.degrees(-90 + Double(i) * 45 + 22.5)
            let lr = ringR * 0.45
            let isCurrent = i == currentIdx

            let label = Text("\(i + 1)")
                .font(.system(size: radius * 0.12, weight: .bold))
                .foregroundColor(Color.white.opacity(isCurrent ? 0.50 : 0.25))
            context.draw(
                label,
                at: CGPoint(
                    x: center.x + lr * cos(midAngle.radians),
                    y: center.y + lr * sin(midAngle.radians)
                ))
        }
    }

    // MARK: - Ghati Ring

    private func drawGhatiRing(
        context: GraphicsContext, center: CGPoint, radius: CGFloat, ghati: Double, pala: Double
    ) {
        let innerR = radius * 0.80
        let labelR = radius * 0.75

        // Sun icon disabled — kept for reuse
        // drawSunIcon(
        //     context: context,
        //     cx: center.x,
        //     cy: center.y - labelR,
        //     r: radius * 0.065)

        // Ghati tracker — shows current ghati number in sun color, tracks around dial
        let trackerAngle = Angle.degrees(-90 + (ghati / 60.0) * 360)
        let trackerText = Text("\(Int(ghati))")
            .font(.system(size: radius * 0.26, weight: .heavy, design: .rounded))
            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.31))
        let trackerPt = CGPoint(
            x: center.x + labelR * cos(trackerAngle.radians),
            y: center.y + labelR * sin(trackerAngle.radians))
        // Skip tracker if too close to sun at top (ghati near 0 or 60)
        let trackerDist = min(ghati, 60 - ghati)
        if trackerDist >= 3 {
            context.draw(trackerText, at: trackerPt)
        }

        // Pala tracker — same ring as ghati, same size, white; hides when near ghati
        let palaAngle = Angle.degrees(-90 + (pala / 60.0) * 360)
        let palaDist = abs(pala - ghati)
        let palaNearGhati = min(palaDist, 60 - palaDist) < 4
        if !palaNearGhati {
            let palaText = Text("\(Int(pala))")
                .font(.system(size: radius * 0.26, weight: .heavy, design: .rounded))
                .foregroundColor(Color.white)
            let palaPt = CGPoint(
                x: center.x + labelR * cos(palaAngle.radians),
                y: center.y + labelR * sin(palaAngle.radians))
            context.draw(palaText, at: palaPt)
        }

        // Time-of-day labels at prahar spoke positions (every 7.5 ghati = 3 hours)
        // Ghati 0=6am(sun), 7.5=9am, 15=12pm, 22.5=3pm, 30=6pm, 37.5=9pm, 45=12am, 52.5=3am
        let timeLabels: [(Double, String)] = [
            (0, "6am"),
        ]
        for (gPos, label) in timeLabels {
            let angle = Angle.degrees(-90 + gPos / 60.0 * 360)

            let dist = abs(gPos - ghati).truncatingRemainder(dividingBy: 60)
            let nearTracker = min(dist, 60 - dist) < 3
            if nearTracker { continue }

            let lbl = Text(label)
                .font(.system(size: radius * 0.14, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.25))
            context.draw(
                lbl,
                at: CGPoint(
                    x: center.x + labelR * cos(angle.radians),
                    y: center.y + labelR * sin(angle.radians)))
        }

        // Ghati number labels every 5, avoiding prahar spoke positions
        let ghatiLabels: [Int] = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
        for g in ghatiLabels {
            let angle = Angle.degrees(-90 + Double(g) / 60.0 * 360)

            let dist = abs(Double(g) - ghati).truncatingRemainder(dividingBy: 60)
            let nearTracker = min(dist, 60 - dist) < 3
            if nearTracker { continue }

            let lbl = Text("\(g)")
                .font(.system(size: radius * 0.14, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.25))
            context.draw(
                lbl,
                at: CGPoint(
                    x: center.x + labelR * cos(angle.radians),
                    y: center.y + labelR * sin(angle.radians)))
        }
    }

    // MARK: - Hands

    private func drawHands(
        context: GraphicsContext, center: CGPoint, radius: CGFloat,
        ghati: Double, pala: Double
    ) {
        // Pala — long
        let palaAngle = Angle.degrees(-90 + (pala / 60.0) * 360)
        drawHand(
            context: context, center: center,
            angle: palaAngle, length: radius * 0.55, tail: radius * 0.30,
            width: 5.0, color: Color.white.opacity(0.85))

        // Ghati — short, bold
        let ghatiAngle = Angle.degrees(-90 + (ghati / 60.0) * 360)
        drawHand(
            context: context, center: center,
            angle: ghatiAngle, length: radius * 0.52, tail: radius * 0.08,
            width: 11.0, color: Color.white)
    }

    private func drawHand(
        context: GraphicsContext, center: CGPoint,
        angle: Angle, length: CGFloat, tail: CGFloat,
        width: CGFloat, color: Color
    ) {
        var path = Path()
        path.move(
            to: CGPoint(
                x: center.x - tail * cos(angle.radians),
                y: center.y - tail * sin(angle.radians)))
        path.addLine(
            to: CGPoint(
                x: center.x + length * cos(angle.radians),
                y: center.y + length * sin(angle.radians)))
        context.stroke(
            path, with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    // MARK: - Sun Icon

    private func drawSunIcon(context: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat) {
        let sunColor = Color(red: 1.0, green: 0.84, blue: 0.31)
        var core = Path()
        core.addArc(
            center: CGPoint(x: cx, y: cy), radius: r * 0.55,
            startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.fill(core, with: .color(sunColor))

        for i in 0..<8 {
            let a = Angle.degrees(Double(i) / 8.0 * 360)
            var ray = Path()
            ray.move(
                to: CGPoint(x: cx + r * 0.7 * cos(a.radians), y: cy + r * 0.7 * sin(a.radians)))
            ray.addLine(to: CGPoint(x: cx + r * cos(a.radians), y: cy + r * sin(a.radians)))
            context.stroke(
                ray, with: .color(sunColor.opacity(0.85)),
                style: StrokeStyle(lineWidth: r * 0.24, lineCap: .round))
        }
    }

    // MARK: - Center Dot

    private func drawCenterDot(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        var outer = Path()
        outer.addArc(
            center: center, radius: radius * 0.040,
            startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.fill(outer, with: .color(Color.white.opacity(0.80)))

        var inner = Path()
        inner.addArc(
            center: center, radius: radius * 0.020,
            startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.fill(inner, with: .color(Color.white))
    }
}

#Preview {
    VedicClockView(date: .now, isDark: true, size: 180)
        .background(.black)
}
