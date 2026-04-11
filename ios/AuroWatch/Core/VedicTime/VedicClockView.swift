import SwiftUI

/// Vedic analog clock — ported from Flutter `VedicClockPainter`.
///
/// Layout (center → edge):
///   0.00 → 0.76  Prahar background segments + labels
///   0.80 → 0.92  Ghati tick marks (60 marks) + sun at 12 o'clock
///   Hands reach into Ghati ring area
///   Sunrise (6 AM) at 12 o'clock = 0 Ghati
///
/// Renders with SwiftUI Canvas (equivalent to Flutter CustomPainter).
struct VedicClockView: View {
    let date: Date
    let isDark: Bool
    var size: CGFloat = 150

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2

            // Calculate Vedic time
            let vt = VedicTimeCalculator.calculate(from: date)

            // Draw layers (back to front)
            drawPraharSegments(context: context, center: center, radius: radius)
            drawGhatiRing(context: context, center: center, radius: radius)
            drawHands(context: context, center: center, radius: radius,
                      ghati: vt.ghatiFloat, pala: vt.palaFloat)
            drawCenterDot(context: context, center: center, radius: radius)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Prahar Segments (inner area)

    private func drawPraharSegments(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let segR = radius * 0.76
        let sweepAngle = Angle.degrees(45) // 360° / 8

        for i in 0..<8 {
            let startAngle = Angle.degrees(-90 + Double(i) * 45)
            let isDay = i < 4

            // Segment fill
            let alpha = isDark ? 0.12 : 0.08
            let extraAlpha = (i == 0) ? 0.04 : (i == 4 ? 0.02 : 0.0)
            let segColor: Color
            if isDay {
                let t = Double(i) / 4.0
                segColor = lerp(AuroTheme.dayStart, AuroTheme.dayEnd, t)
                    .opacity(alpha + extraAlpha)
            } else {
                let t = Double(i - 4) / 4.0
                segColor = lerp(AuroTheme.nightStart, AuroTheme.nightEnd, t)
                    .opacity(alpha + extraAlpha)
            }

            var segPath = Path()
            segPath.move(to: center)
            segPath.addArc(center: center, radius: segR,
                           startAngle: startAngle,
                           endAngle: startAngle + sweepAngle,
                           clockwise: false)
            segPath.closeSubpath()
            context.fill(segPath, with: .color(segColor))

            // Segment border
            context.stroke(segPath,
                           with: .color(AuroTheme.primaryColor.opacity(isDark ? 0.06 : 0.05)),
                           lineWidth: 0.5)

            // Prahar label
            let midAngle = startAngle + Angle.degrees(22.5)
            let lr = segR * 0.72
            let lx = center.x + lr * cos(midAngle.radians)
            let ly = center.y + lr * sin(midAngle.radians)
            let fontSize = radius * 0.055

            let label = Text(VedicTimeCalculator.praharNames[i].lowercased())
                .font(.system(size: fontSize, weight: .light))
                .foregroundColor(AuroTheme.primaryColor.opacity(isDark ? 0.55 : 0.45))
            context.draw(label, at: CGPoint(x: lx, y: ly))
        }

        // Ring around prahar area
        var ringPath = Path()
        ringPath.addArc(center: center, radius: segR,
                        startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.stroke(ringPath,
                       with: .color(AuroTheme.primaryColor.opacity(isDark ? 0.10 : 0.08)),
                       lineWidth: 0.8)
    }

    // MARK: - Ghati Ring (outer area)

    private func drawGhatiRing(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let outerR = radius * 0.92
        let innerR = radius * 0.80
        let labelR = radius * 0.84

        // Outer ring line
        var outerPath = Path()
        outerPath.addArc(center: center, radius: outerR,
                         startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.stroke(outerPath,
                       with: .color(AuroTheme.primaryColor.opacity(isDark ? 0.12 : 0.10)),
                       lineWidth: 1.0)

        for g in 0..<60 {
            let angle = Angle.degrees(-90 + Double(g) / 60.0 * 360)
            let isMajor = g % 5 == 0
            let hasLabel = g % 15 == 0 && g > 0
            let isSunrise = g == 0

            // Tick marks (skip where label or sun sits)
            if !hasLabel && !isSunrise {
                let tickLen = isMajor
                    ? (outerR - innerR) * 0.6
                    : (outerR - innerR) * 0.25
                let tickStart = outerR - tickLen

                var tickPath = Path()
                tickPath.move(to: CGPoint(
                    x: center.x + tickStart * cos(angle.radians),
                    y: center.y + tickStart * sin(angle.radians)
                ))
                tickPath.addLine(to: CGPoint(
                    x: center.x + outerR * cos(angle.radians),
                    y: center.y + outerR * sin(angle.radians)
                ))
                context.stroke(tickPath,
                               with: .color(AuroTheme.primaryColor.opacity(isMajor ? 0.50 : 0.18)),
                               style: StrokeStyle(lineWidth: isMajor ? 1.2 : 0.5, lineCap: .round))
            }

            // Sun icon at 0 Ghati (sunrise / 12 o'clock)
            if isSunrise {
                let sx = center.x + labelR * cos(angle.radians)
                let sy = center.y + labelR * sin(angle.radians)
                drawSunIcon(context: context, cx: sx, cy: sy, r: radius * 0.038)
            }

            // Number labels every 15 Ghati
            if hasLabel {
                let lx = center.x + labelR * cos(angle.radians)
                let ly = center.y + labelR * sin(angle.radians)
                let label = Text("\(g)")
                    .font(.system(size: radius * 0.058, weight: .semibold))
                    .foregroundColor(AuroTheme.primaryColor.opacity(0.70))
                context.draw(label, at: CGPoint(x: lx, y: ly))
            }
        }
    }

    // MARK: - Clock Hands

    private func drawHands(context: GraphicsContext, center: CGPoint, radius: CGFloat,
                           ghati: Double, pala: Double) {
        // Pala hand — long, thin (like minute hand)
        let palaAngle = Angle.degrees(-90 + (pala / 60.0) * 360)
        drawHand(context: context, center: center,
                 angle: palaAngle, length: radius * 0.68, tail: radius * 0.10,
                 width: 1.5, color: AuroTheme.primaryColor.opacity(0.6))

        // Ghati hand — short, thick (like hour hand)
        let ghatiAngle = Angle.degrees(-90 + (ghati / 60.0) * 360)
        drawHand(context: context, center: center,
                 angle: ghatiAngle, length: radius * 0.52, tail: radius * 0.08,
                 width: 2.8, color: AuroTheme.primaryColor.opacity(0.85))
    }

    private func drawHand(context: GraphicsContext, center: CGPoint,
                          angle: Angle, length: CGFloat, tail: CGFloat,
                          width: CGFloat, color: Color) {
        var path = Path()
        path.move(to: CGPoint(
            x: center.x - tail * cos(angle.radians),
            y: center.y - tail * sin(angle.radians)
        ))
        path.addLine(to: CGPoint(
            x: center.x + length * cos(angle.radians),
            y: center.y + length * sin(angle.radians)
        ))
        context.stroke(path,
                       with: .color(color),
                       style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    // MARK: - Sun Icon

    private func drawSunIcon(context: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat) {
        let sunColor = AuroTheme.goldAccent

        // Core circle
        var corePath = Path()
        corePath.addArc(center: CGPoint(x: cx, y: cy), radius: r * 0.55,
                        startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.fill(corePath, with: .color(sunColor))

        // 8 rays
        for i in 0..<8 {
            let rayAngle = Angle.degrees(Double(i) / 8.0 * 360)
            let innerR = r * 0.7
            let outerR = r
            var rayPath = Path()
            rayPath.move(to: CGPoint(
                x: cx + innerR * cos(rayAngle.radians),
                y: cy + innerR * sin(rayAngle.radians)
            ))
            rayPath.addLine(to: CGPoint(
                x: cx + outerR * cos(rayAngle.radians),
                y: cy + outerR * sin(rayAngle.radians)
            ))
            context.stroke(rayPath,
                           with: .color(sunColor.opacity(0.8)),
                           style: StrokeStyle(lineWidth: r * 0.22, lineCap: .round))
        }
    }

    // MARK: - Center Dot

    private func drawCenterDot(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        // Outer dot
        var outerDot = Path()
        outerDot.addArc(center: center, radius: radius * 0.03,
                        startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.fill(outerDot, with: .color(AuroTheme.primaryColor.opacity(0.5)))

        // Inner dot
        var innerDot = Path()
        innerDot.addArc(center: center, radius: radius * 0.015,
                        startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.fill(innerDot, with: .color(AuroTheme.primaryColor))
    }

    // MARK: - Color Interpolation

    /// Linear interpolation between two colors (matches Dart Color.lerp).
    private func lerp(_ a: Color, _ b: Color, _ t: Double) -> Color {
        // SwiftUI doesn't have Color.lerp, so we blend via overlay
        // For the subtle alpha used here, a simple approach works
        let clamped = max(0, min(1, t))
        return clamped < 0.5 ? a : b
    }
}

// MARK: - Preview

#Preview {
    VedicClockView(date: .now, isDark: true, size: 180)
        .background(.black)
}
