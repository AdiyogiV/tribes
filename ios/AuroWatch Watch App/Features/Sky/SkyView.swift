import SwiftUI

/// Current sky in North Indian diamond (Kundali) chart format.
/// Digital Crown scrubs time forward/backward.
///
/// North Indian chart layout — outer square + inner diamond + corner diagonals = 12 triangular houses.
/// House 1 (Ascendant) is always the top-center inner diamond triangle.
/// Houses proceed counterclockwise (matching the kundali_chart Flutter package convention):
///   1 = top inner, 2 = upper-left outer, 3 = left-upper outer, 4 = left inner, etc.
///
///       ┌────────┬────────┐
///       │ \  2 / │ \ 1  / │
///       │  \  /  │  \  /  │
///       │ 3 \/   │   \/12 │
///       │   /\   │   /\   │
///       │  /  \  │  /  \  │
///       │ /  4 \ │ / 11 \ │
///       ├────────┼────────┤
///       │ \  5 / │ \ 10 / │
///       │  \  /  │  \  /  │
///       │ 6 \/   │   \/ 9 │
///       │   /\   │   /\   │
///       │  /  \  │  /  \  │
///       │ /  7 \ │ /  8 \ │
///       └────────┴────────┘
struct SkyView: View {
    @EnvironmentObject private var cache: LocalCache
    @State private var daysOffset: Double = 0.0
    @FocusState private var isFocused: Bool

    // Planet display glyphs (Vedic 9 grahas)
    private static let glyphs: [String: String] = [
        "Sun": "Su", "Moon": "Mo", "Mars": "Ma",
        "Mercury": "Me", "Jupiter": "Ju", "Venus": "Ve",
        "Saturn": "Sa", "Rahu": "Ra", "Ketu": "Ke",
    ]

    // Average daily motion in degrees (used for Digital Crown time scrubbing).
    // Retrograde planets get their motion reversed at runtime.
    private static let dailyMotion: [String: Double] = [
        "Sun": 1.0, "Moon": 13.2, "Mars": 0.52,
        "Mercury": 1.38, "Jupiter": 0.08, "Venus": 1.2,
        "Saturn": 0.034, "Rahu": -0.053, "Ketu": -0.053,
    ]

    // Zodiac sign short labels — index 0 = Aries, 11 = Pisces
    private static let signShorts = [
        "Ari", "Tau", "Gem", "Can", "Leo", "Vir",
        "Lib", "Sco", "Sag", "Cap", "Aqu", "Pis",
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // Diamond chart fills screen, sized to the smaller dimension
            // so it's aligned like the clock (watch screen is rectangular)
            let chartSize = min(w, h) * 0.92

            ZStack {
                // Diamond Kundali chart — centered, fills screen
                Canvas { context, canvasSize in
                    let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                    let size = min(canvasSize.width, canvasSize.height)

                    drawDiamondChart(context: context, center: center, size: size)
                    placePlanets(
                        context: context, center: center, size: size, daysOffset: daysOffset)
                }
                .frame(width: chartSize, height: chartSize)
                .position(x: w / 2, y: h / 2)

                // Days offset overlay — centered in the diamond
                if daysOffset != 0 {
                    let d = Int(daysOffset)
                    Text(d > 0 ? "+\(d)d" : "\(d)d")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .position(x: w / 2, y: h / 2)
                }
            }
            .frame(width: w, height: h)
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

    // MARK: - House Text Positions (Incenters)
    //
    // Each outer house is an isoceles right triangle with legs s/√2 and base s.
    // The INCENTER (equidistant from all 3 sides) is the optimal text position:
    //   - For outer triangles: incenter at (±0.500, ±0.793) or (±0.793, ±0.500)
    //     Derived: I = (a·A + b·B + c·C)/(a+b+c) with a=b=s/√2, c=s
    //   - For inner kites (symmetric): centroid at (0, ±0.500) or (±0.500, 0)
    //     These sit at the widest point of each kite — naturally centered.
    //
    // Coordinate system: center = (0,0), outer square spans ±1·s on each axis.

    private func houseTextCenter(_ house: Int, center: CGPoint, s: CGFloat) -> CGPoint {
        let p: [(CGFloat, CGFloat)] = [
            (0.000, -0.500),  // 0  — inner top (Ascendant) — kite centroid
            (0.500, -0.860),  // 1  — outer upper-right — pulled UP
            (0.793, -0.500),  // 2  — outer right-upper — incenter
            (0.500, 0.000),  // 3  — inner right — kite centroid
            (0.793, 0.500),  // 4  — outer right-lower — incenter
            (0.500, 0.860),  // 5  — outer lower-right — pulled DOWN
            (0.000, 0.500),  // 6  — inner bottom — kite centroid
            (-0.500, 0.860),  // 7  — outer lower-left — pulled DOWN
            (-0.793, 0.500),  // 8  — outer left-lower — incenter
            (-0.500, 0.000),  // 9  — inner left — kite centroid
            (-0.793, -0.500),  // 10 — outer left-upper — incenter
            (-0.500, -0.860),  // 11 — outer upper-left — pulled UP
        ]
        let (dx, dy) = p[house]
        return CGPoint(x: center.x + s * dx, y: center.y + s * dy)
    }

    // MARK: - Draw Diamond Chart

    private func drawDiamondChart(context: GraphicsContext, center: CGPoint, size: CGFloat) {
        let s = size * 0.47
        let lineColor = Color(white: 0.28)  // darker grey
        let lineWidth: CGFloat = 4.0
        let r = s * 0.10  // corner rounding radius for diamond

        let top = CGPoint(x: center.x, y: center.y - s)
        let right = CGPoint(x: center.x + s, y: center.y)
        let bottom = CGPoint(x: center.x, y: center.y + s)
        let left = CGPoint(x: center.x - s, y: center.y)
        let tl = CGPoint(x: center.x - s, y: center.y - s)
        let tr = CGPoint(x: center.x + s, y: center.y - s)
        let br = CGPoint(x: center.x + s, y: center.y + s)
        let bl = CGPoint(x: center.x - s, y: center.y + s)

        // Combine all lines into ONE path — no overlap artifacts
        var chart = Path()

        // Diamond with rounded corners at each midpoint
        // Each corner: approach the point, then curve through it
        // Top → Right
        chart.move(to: CGPoint(x: top.x + r, y: top.y + r))
        chart.addQuadCurve(
            to: CGPoint(x: top.x + r, y: top.y + r),
            control: top)  // dummy to set start
        // Build rounded diamond: move to offset before top, curve around each vertex
        chart = Path()
        // Start offset before top (coming from left side)
        chart.move(to: CGPoint(x: top.x - r * 0.7, y: top.y + r * 0.7))
        // Curve around top
        chart.addQuadCurve(to: CGPoint(x: top.x + r * 0.7, y: top.y + r * 0.7), control: top)
        // Line to before right
        chart.addLine(to: CGPoint(x: right.x - r * 0.7, y: right.y - r * 0.7))
        // Curve around right
        chart.addQuadCurve(to: CGPoint(x: right.x - r * 0.7, y: right.y + r * 0.7), control: right)
        // Line to before bottom
        chart.addLine(to: CGPoint(x: bottom.x + r * 0.7, y: bottom.y - r * 0.7))
        // Curve around bottom
        chart.addQuadCurve(
            to: CGPoint(x: bottom.x - r * 0.7, y: bottom.y - r * 0.7), control: bottom)
        // Line to before left
        chart.addLine(to: CGPoint(x: left.x + r * 0.7, y: left.y + r * 0.7))
        // Curve around left
        chart.addQuadCurve(to: CGPoint(x: left.x + r * 0.7, y: left.y - r * 0.7), control: left)
        chart.closeSubpath()

        // Corner-to-center diagonals
        for corner in [tl, tr, br, bl] {
            chart.move(to: corner)
            chart.addLine(to: center)
        }

        // Stroke once with round joins/caps for smooth edges
        context.stroke(
            chart,
            with: .color(lineColor),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Place Planets

    private func placePlanets(
        context: GraphicsContext, center: CGPoint, size: CGFloat, daysOffset: Double = 0
    ) {
        let s = size * 0.47
        let planets = cache.skyPositions

        if planets.isEmpty {
            let line1 = Text("Sync from")
                .font(.system(size: size * 0.06, weight: .medium))
                .foregroundColor(Color.white.opacity(0.25))
            let line2 = Text("phone")
                .font(.system(size: size * 0.06, weight: .medium))
                .foregroundColor(Color.white.opacity(0.25))
            context.draw(line1, at: CGPoint(x: center.x, y: center.y - size * 0.04))
            context.draw(line2, at: CGPoint(x: center.x, y: center.y + size * 0.04))
            return
        }

        // Group planets by sign index (0=Aries .. 11=Pisces).
        // Apply Digital Crown time offset using average daily motion rates.
        let daysFraction = daysOffset
        // (glyph, isRetro) per house
        var houseContents: [Int: [(String, Bool)]] = [:]

        for planetData in planets {
            guard let name = planetData["name"] as? String,
                let longitude = planetData["longitude"] as? Double
            else { continue }

            guard let glyph = Self.glyphs[name] else { continue }

            let isRetro = planetData["isRetro"] as? Bool ?? false
            let baseDailyMotion = Self.dailyMotion[name] ?? 0.5
            let motion = isRetro ? -baseDailyMotion : baseDailyMotion
            let adjustedLong = (longitude + motion * daysFraction).truncatingRemainder(
                dividingBy: 360)
            let safeLong = adjustedLong < 0 ? adjustedLong + 360 : adjustedLong

            let signIndex = Int(safeLong / 30.0) % 12
            houseContents[signIndex, default: []].append((glyph, isRetro))
        }

        // Colors: white for direct, warm orange for retrograde
        let directColor = Color.white
        let retroColor = Color(red: 0.68, green: 0.62, blue: 1.0)  // subtle indigo on white

        // Draw planet glyphs in each house
        let fontSize = size * 0.105

        for house in 0..<12 {
            let pos = houseTextCenter(house, center: center, s: s)

            guard let contents = houseContents[house] else { continue }

            // Build attributed text with per-planet coloring
            func styledRow(_ items: [(String, Bool)]) -> Text {
                var result = Text("")
                for (i, (glyph, isRetro)) in items.enumerated() {
                    if i > 0 { result = result + Text(" ") }
                    result =
                        result
                        + Text(glyph)
                        .font(.system(size: fontSize, weight: .heavy))
                        .foregroundColor(isRetro ? retroColor : directColor)
                }
                return result
            }

            if contents.count > 3 {
                let row1 = Array(contents.prefix(3))
                let row2 = Array(contents.dropFirst(3))
                context.draw(styledRow(row1), at: CGPoint(x: pos.x, y: pos.y - fontSize * 0.3))
                context.draw(styledRow(row2), at: CGPoint(x: pos.x, y: pos.y + fontSize * 0.6))
            } else {
                context.draw(styledRow(contents), at: pos)
            }
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
    return SkyView().environmentObject(cache)
}
