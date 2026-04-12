import SwiftUI

/// Minimal circular zodiac wheel — signs on the rim, planets as dots on a track.
/// Digital Crown scrubs ±30 days.
struct ZodiacWheelView: View {
    @EnvironmentObject private var cache: LocalCache
    @State private var daysOffset: Double = 0.0
    @FocusState private var isFocused: Bool

    private static let signLabels = [
        "Ar","Ta","Ge","Cn","Le","Vi",
        "Li","Sc","Sg","Cp","Aq","Pi"
    ]

    private static let glyphs: [String: String] = [
        "Sun": "Su", "Moon": "Mo", "Mars": "Ma",
        "Mercury": "Me", "Jupiter": "Ju", "Venus": "Ve",
        "Saturn": "Sa", "Rahu": "Ra", "Ketu": "Ke",
        "Uranus": "Ur", "Neptune": "Ne", "Pluto": "Pl",
    ]

    private static let planetColors: [String: Color] = [
        "Sun": .orange, "Moon": .white, "Mars": .red,
        "Mercury": .green, "Jupiter": .yellow, "Venus": .pink,
        "Saturn": .blue, "Rahu": Color(white: 0.55), "Ketu": Color(white: 0.55),
    ]

    private static let dailyMotion: [String: Double] = [
        "Sun": 1.0, "Moon": 13.2, "Mars": 0.52,
        "Mercury": 1.38, "Jupiter": 0.08, "Venus": 1.2,
        "Saturn": 0.034, "Rahu": -0.053, "Ketu": -0.053,
        "Uranus": 0.012, "Neptune": 0.006, "Pluto": 0.004,
    ]

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            ZStack {
                Canvas { ctx, sz in
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    let s = min(sz.width, sz.height)
                    drawRing(ctx: ctx, c: c, s: s)
                    drawPlanets(ctx: ctx, c: c, s: s)
                }
                .frame(width: side, height: side)

                // Title
                VStack(spacing: 2) {
                    if daysOffset != 0 {
                        let d = Int(daysOffset)
                        Text(d > 0 ? "+\(d)d" : "\(d)d")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea(.all)
        .focusable(true)
        .focused($isFocused)
        .digitalCrownRotation(
            $daysOffset,
            from: -30, through: 30, by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onAppear { isFocused = true }
    }

    // MARK: - Ring

    private func drawRing(ctx: GraphicsContext, c: CGPoint, s: CGFloat) {
        let outerR = s * 0.46
        let trackR = s * 0.34   // planet track
        let innerR = s * 0.26

        // Outer circle
        ctx.stroke(
            Path(ellipseIn: CGRect(x: c.x - outerR, y: c.y - outerR,
                                    width: outerR * 2, height: outerR * 2)),
            with: .color(.white.opacity(0.2)),
            style: StrokeStyle(lineWidth: 0.8)
        )

        // Track circle (faint)
        ctx.stroke(
            Path(ellipseIn: CGRect(x: c.x - trackR, y: c.y - trackR,
                                    width: trackR * 2, height: trackR * 2)),
            with: .color(.white.opacity(0.08)),
            style: StrokeStyle(lineWidth: 0.5)
        )

        // Inner circle
        ctx.stroke(
            Path(ellipseIn: CGRect(x: c.x - innerR, y: c.y - innerR,
                                    width: innerR * 2, height: innerR * 2)),
            with: .color(.white.opacity(0.12)),
            style: StrokeStyle(lineWidth: 0.5)
        )

        // 12 segment lines — short ticks from track outward
        for i in 0..<12 {
            let angle = CGFloat(i) * .pi / 6.0 - .pi / 2.0
            var seg = Path()
            seg.move(to: CGPoint(x: c.x + innerR * cos(angle),
                                  y: c.y + innerR * sin(angle)))
            seg.addLine(to: CGPoint(x: c.x + outerR * cos(angle),
                                     y: c.y + outerR * sin(angle)))
            ctx.stroke(seg, with: .color(.white.opacity(0.1)),
                       style: StrokeStyle(lineWidth: 0.5))
        }

        // Sign labels — centered in each 30° segment, on the outer rim
        let labelR = outerR * 0.85
        for i in 0..<12 {
            let angle = (CGFloat(i) * 30.0 + 15.0) * .pi / 180.0 - .pi / 2.0
            let pos = CGPoint(x: c.x + labelR * cos(angle),
                              y: c.y + labelR * sin(angle))
            let label = Text(Self.signLabels[i])
                .font(.system(size: s * 0.048, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
            ctx.draw(label, at: pos)
        }
    }

    // MARK: - Planets

    private func drawPlanets(ctx: GraphicsContext, c: CGPoint, s: CGFloat) {
        let trackR = s * 0.34

        let planets = cache.skyPositions
        if planets.isEmpty {
            let t1 = Text("Sync from")
                .font(.system(size: s * 0.05))
                .foregroundColor(.white.opacity(0.15))
            let t2 = Text("phone")
                .font(.system(size: s * 0.05))
                .foregroundColor(.white.opacity(0.15))
            ctx.draw(t1, at: CGPoint(x: c.x, y: c.y - s * 0.025))
            ctx.draw(t2, at: CGPoint(x: c.x, y: c.y + s * 0.025))
            return
        }

        // Build planet data with adjusted longitudes
        struct P {
            let glyph: String
            let longitude: Double
            let isRetro: Bool
            let color: Color
        }

        var items: [P] = []
        for data in planets {
            guard let name = data["name"] as? String,
                  let lon = data["longitude"] as? Double,
                  let glyph = Self.glyphs[name] else { continue }
            let isRetro = data["isRetro"] as? Bool ?? false
            let dm = Self.dailyMotion[name] ?? 0.5
            let motion = isRetro ? -dm : dm
            var adj = (lon + motion * daysOffset).truncatingRemainder(dividingBy: 360)
            if adj < 0 { adj += 360 }
            let color = Self.planetColors[name] ?? .white
            items.append(P(glyph: glyph, longitude: adj, isRetro: isRetro, color: color))
        }

        // Sort and spread overlaps
        items.sort { $0.longitude < $1.longitude }
        let minSep = 16.0
        var angles: [Double] = []
        for i in 0..<items.count {
            var a = items[i].longitude
            if i > 0 {
                let prev = angles[i - 1]
                var diff = a - prev
                if diff < 0 { diff += 360 }
                if diff > 180 { diff = 360 - diff }
                if diff < minSep {
                    a = prev + minSep
                    if a >= 360 { a -= 360 }
                }
            }
            angles.append(a)
        }

        // Draw
        let dotSize: CGFloat = 4.0
        let labelSize = s * 0.05

        for i in 0..<items.count {
            let item = items[i]
            let deg = angles[i]
            let rad = (deg - 90.0) * .pi / 180.0

            let x = c.x + trackR * cos(CGFloat(rad))
            let y = c.y + trackR * sin(CGFloat(rad))

            // Colored dot
            let dot = Path(ellipseIn: CGRect(
                x: x - dotSize / 2, y: y - dotSize / 2,
                width: dotSize, height: dotSize))
            ctx.fill(dot, with: .color(item.color))

            // Label — offset outward from dot
            let outR = trackR + s * 0.055
            let lx = c.x + outR * cos(CGFloat(rad))
            let ly = c.y + outR * sin(CGFloat(rad))

            let label = Text(item.glyph)
                .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                .foregroundColor(item.isRetro ? item.color.opacity(0.5) : item.color.opacity(0.85))
            ctx.draw(label, at: CGPoint(x: lx, y: ly))
        }
    }
}

#Preview {
    let cache = LocalCache()
    cache.skyPositions = [
        ["name": "Sun", "longitude": 25.5, "isRetro": false],
        ["name": "Moon", "longitude": 120.3, "isRetro": false],
        ["name": "Mars", "longitude": 336.1, "isRetro": false],
        ["name": "Jupiter", "longitude": 65.0, "isRetro": true],
        ["name": "Saturn", "longitude": 340.0, "isRetro": false],
        ["name": "Venus", "longitude": 18.8, "isRetro": false],
        ["name": "Mercury", "longitude": 30.0, "isRetro": true],
        ["name": "Rahu", "longitude": 5.0, "isRetro": true],
        ["name": "Ketu", "longitude": 185.0, "isRetro": true],
    ]
    return ZodiacWheelView().environmentObject(cache)
}
