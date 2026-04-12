import SwiftUI
import Charts

/// Ritu — trends and seasons, split into full-screen pages.
/// No scrolling. Each card gets its own page.
struct RituView: View {
    @EnvironmentObject private var cache: LocalCache
    @State private var showSeasonDetail = false
    @State private var showTrendDetail = false
    @State private var page = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                // Page 0: Ojas sparkline
                ojasPage
                    .tag(0)

                // Page 1: Sleep breakdown (only if data)
                if cache.sleepHours != nil {
                    sleepPage
                        .tag(1)
                }

                // Page 2: Agni + Season
                agniSeasonPage
                    .tag(cache.sleepHours != nil ? 2 : 1)
            }
            .tabViewStyle(.verticalPage)
            .ignoresSafeArea(.all)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showSeasonDetail) {
                RituDetailView()
            }
            .navigationDestination(isPresented: $showTrendDetail) {
                TrendDetailView(cache: cache)
            }
        }
    }

    // MARK: - Page 0: Ojas Trend

    private var ojasPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            let history = cache.ojasHistory
            let current = cache.ojasScore ?? 0

            VStack(spacing: 6) {
                Spacer(minLength: 8)

                HStack {
                    Text("Ojas")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                        .textCase(.uppercase)
                        .tracking(1.0)
                    Spacer()
                    HStack(spacing: 2) {
                        Text("7 days")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AuroTheme.textLight.opacity(0.35))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(AuroTheme.textLight.opacity(0.15))
                    }
                }
                .padding(.horizontal, 14)

                if history.count >= 2 {
                    Chart {
                        ForEach(Array(history.enumerated()), id: \.offset) { idx, score in
                            LineMark(x: .value("Day", idx), y: .value("Ojas", score))
                                .foregroundStyle(AuroTheme.goldAccent)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            AreaMark(x: .value("Day", idx), y: .value("Ojas", score))
                                .foregroundStyle(
                                    .linearGradient(
                                        colors: [AuroTheme.goldAccent.opacity(0.25), .clear],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                        }
                        if let last = history.last {
                            PointMark(x: .value("Day", history.count - 1), y: .value("Ojas", last))
                                .foregroundStyle(AuroTheme.goldAccent)
                                .symbolSize(40)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: max(0, (history.min() ?? 0) - 10)...min(100, (history.max() ?? 100) + 10))
                    .frame(height: h * 0.35)
                    .padding(.horizontal, 14)

                    trendLabel(history: history)
                        .padding(.horizontal, 14)
                } else {
                    Text("\(current)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(AuroTheme.goldAccent)
                    Text("More data coming soon")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AuroTheme.textLight.opacity(0.35))
                }

                Spacer(minLength: 8)
            }
            .frame(width: w, height: h)
            .contentShape(Rectangle())
            .onTapGesture { showTrendDetail = true }
        }
    }

    @ViewBuilder
    private func trendLabel(history: [Int]) -> some View {
        let recent = Array(history.suffix(3))
        let older = Array(history.prefix(max(1, history.count - 3)))
        let recentAvg = recent.isEmpty ? 0.0 : Double(recent.reduce(0, +)) / Double(recent.count)
        let olderAvg = older.isEmpty ? recentAvg : Double(older.reduce(0, +)) / Double(older.count)
        let diff = recentAvg - olderAvg

        HStack(spacing: 4) {
            if diff > 3 {
                Image(systemName: "arrow.up.right").foregroundColor(AuroTheme.kaphaColor)
                Text("Improving").foregroundColor(AuroTheme.kaphaColor)
            } else if diff < -3 {
                Image(systemName: "arrow.down.right").foregroundColor(AuroTheme.pittaColor)
                Text("Dipping").foregroundColor(AuroTheme.pittaColor)
            } else {
                Image(systemName: "arrow.right").foregroundColor(AuroTheme.textLight.opacity(0.5))
                Text("Steady").foregroundColor(AuroTheme.textLight.opacity(0.5))
            }
            Spacer()
        }
        .font(.system(size: 11, weight: .semibold))
    }

    // MARK: - Page 1: Sleep Breakdown

    private var sleepPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            let deep = cache.deepSleepMinutes ?? 0
            let rem = cache.remSleepMinutes ?? 0
            let totalMins = (cache.sleepHours ?? 0) * 60
            let core = max(0, totalMins - deep - rem)

            VStack(spacing: 10) {
                Spacer()

                HStack {
                    Text("Sleep")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                        .textCase(.uppercase)
                        .tracking(1.0)
                    Spacer()
                    Text(String(format: "%.1fh", cache.sleepHours ?? 0))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AuroTheme.kaphaColor)
                }
                .padding(.horizontal, 16)

                // Stacked bar
                let total = max(1, deep + rem + core)
                HStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.2, green: 0.3, blue: 0.7))
                        .frame(width: (w - 36) * deep / total, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.4, green: 0.6, blue: 0.9))
                        .frame(width: (w - 36) * rem / total, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.5, green: 0.5, blue: 0.6))
                        .frame(width: (w - 36) * core / total, height: 14)
                }
                .padding(.horizontal, 18)

                // Legend
                HStack(spacing: 12) {
                    legendDot(Color(red: 0.2, green: 0.3, blue: 0.7), text: "Deep \(Int(deep))m")
                    legendDot(Color(red: 0.4, green: 0.6, blue: 0.9), text: "REM \(Int(rem))m")
                    legendDot(Color(red: 0.5, green: 0.5, blue: 0.6), text: "Core \(Int(core))m")
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .frame(width: w, height: h)
        }
    }

    @ViewBuilder
    private func legendDot(_ color: Color, text: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AuroTheme.textLight.opacity(0.5))
        }
    }

    // MARK: - Page 2: Agni + Season

    private var agniSeasonPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            let agni = cache.agniType ?? "Sama"
            let type = AgniType(rawValue: agni) ?? .sama
            let season = VedicSeason.current()

            VStack(spacing: 14) {
                Spacer()

                // Agni
                HStack(spacing: 8) {
                    Text("🔥")
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(type.rawValue)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(agniColor(type))
                        Text(type.description)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AuroTheme.textLight.opacity(0.55))
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                // Season (tappable)
                Button { showSeasonDetail = true } label: {
                    HStack(spacing: 8) {
                        Text(season.emoji)
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(season.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AuroTheme.doshaColor(season.dominantDosha))
                            Text(season.subtitle)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AuroTheme.textLight.opacity(0.55))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AuroTheme.textLight.opacity(0.2))
                    }
                    .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .frame(width: w, height: h)
        }
    }

    private func agniColor(_ type: AgniType) -> Color {
        switch type {
        case .sama:    return AuroTheme.kaphaColor
        case .vishama: return AuroTheme.vataColor
        case .tikshna: return AuroTheme.pittaColor
        case .manda:   return AuroTheme.primaryColor
        }
    }
}

// MARK: - Trend Detail (paged drill-down: one chart per page)

struct TrendDetailView: View {
    let cache: LocalCache
    @Environment(\.dismiss) private var dismiss
    @State private var trendPage = 0

    var body: some View {
        let charts = buildCharts()

        TabView(selection: $trendPage) {
            ForEach(Array(charts.enumerated()), id: \.offset) { idx, chart in
                trendPage(chart: chart, isFirst: idx == 0)
                    .tag(idx)
            }
        }
        .tabViewStyle(.verticalPage)
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func trendPage(chart: TrendChartData, isFirst: Bool) -> some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 6) {
                // Back button on first page
                if isFirst {
                    HStack {
                        Button { dismiss() } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Trends")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(AuroTheme.goldAccent.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                }

                Spacer(minLength: 4)

                // Title + current value
                HStack {
                    Text(chart.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AuroTheme.textLight.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                    if let last = chart.data.last {
                        Text("\(Int(last))\(chart.suffix)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(chart.color)
                    }
                }
                .padding(.horizontal, 12)

                // Chart
                Chart {
                    ForEach(Array(chart.data.enumerated()), id: \.offset) { idx, val in
                        LineMark(x: .value("D", idx), y: .value("V", val))
                            .foregroundStyle(chart.color)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        AreaMark(x: .value("D", idx), y: .value("V", val))
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [chart.color.opacity(0.25), .clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    }
                    if let last = chart.data.last {
                        PointMark(x: .value("D", chart.data.count - 1), y: .value("V", last))
                            .foregroundStyle(chart.color)
                            .symbolSize(30)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: h * 0.4)
                .padding(.horizontal, 12)

                Text("7 days")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AuroTheme.textLight.opacity(0.2))

                Spacer(minLength: 4)
            }
            .frame(width: w, height: h)
        }
    }

    private func buildCharts() -> [TrendChartData] {
        var charts: [TrendChartData] = []

        let ojasData = cache.ojasHistory.map { Double($0) }
        if ojasData.count >= 2 {
            charts.append(TrendChartData(title: "Ojas", data: ojasData, color: AuroTheme.goldAccent, suffix: ""))
        }
        if cache.sleepHistory.count >= 2 {
            charts.append(TrendChartData(title: "Sleep", data: cache.sleepHistory, color: AuroTheme.kaphaColor, suffix: "h"))
        }
        if cache.hrvHistory.count >= 2 {
            charts.append(TrendChartData(title: "HRV", data: cache.hrvHistory, color: AuroTheme.vataColor, suffix: "ms"))
        }
        if cache.restingHRHistory.count >= 2 {
            charts.append(TrendChartData(title: "Rest HR", data: cache.restingHRHistory, color: AuroTheme.pittaColor, suffix: "bpm"))
        }
        if cache.spO2History.count >= 2 {
            charts.append(TrendChartData(title: "Oxygen", data: cache.spO2History, color: Color(red: 0.4, green: 0.6, blue: 0.9), suffix: "%"))
        }
        if cache.stepsHistory.count >= 2 {
            charts.append(TrendChartData(title: "Steps", data: cache.stepsHistory.map { Double($0) }, color: AuroTheme.kaphaColor, suffix: ""))
        }

        return charts
    }
}

private struct TrendChartData {
    let title: String
    let data: [Double]
    let color: Color
    let suffix: String
}

// MARK: - Ritu Detail (paged drill-down)

struct RituDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var detailPage = 0

    var body: some View {
        let season = VedicSeason.current()

        TabView(selection: $detailPage) {
            // Page 0: Season overview
            seasonOverviewPage(season)
                .tag(0)

            // Page 1: Food guidance
            foodGuidancePage(season)
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func seasonOverviewPage(_ season: VedicSeason) -> some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 8) {
                // Back
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text("Season")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(AuroTheme.goldAccent.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)

                Spacer()

                Text(season.emoji)
                    .font(.system(size: 36))

                Text(season.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AuroTheme.doshaColor(season.dominantDosha))

                Text(season.months)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AuroTheme.textLight.opacity(0.5))

                Text(season.doshaAdvice)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AuroTheme.textLight.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                Spacer()
            }
            .frame(width: w, height: h)
        }
    }

    private func foodGuidancePage(_ season: VedicSeason) -> some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(alignment: .leading, spacing: 10) {
                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("FAVOR")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AuroTheme.kaphaColor)
                        .tracking(1.0)
                    Text(season.favorFoods)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AuroTheme.textLight.opacity(0.75))
                }

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text("REDUCE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AuroTheme.pittaColor)
                        .tracking(1.0)
                    Text(season.avoidFoods)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AuroTheme.textLight.opacity(0.75))
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(width: w, height: h)
        }
    }
}

// MARK: - Vedic Season Model

struct VedicSeason {
    let name: String
    let emoji: String
    let months: String
    let dominantDosha: String
    let subtitle: String
    let doshaAdvice: String
    let favorFoods: String
    let avoidFoods: String

    static func current(date: Date = .now) -> VedicSeason {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 1, 2:   return shishira
        case 3, 4:   return vasanta
        case 5, 6:   return grishma
        case 7, 8:   return varsha
        case 9, 10:  return sharad
        case 11, 12: return hemanta
        default:     return hemanta
        }
    }

    static let shishira = VedicSeason(
        name: "Shishira", emoji: "❄️", months: "Jan – Feb",
        dominantDosha: "Kapha", subtitle: "Late winter · Kapha builds",
        doshaAdvice: "Kapha accumulates in cold. Stay warm, stay active. Strong digestion — eat well.",
        favorFoods: "Warm soups, root vegetables, ginger, garlic, ghee, sesame",
        avoidFoods: "Cold drinks, raw salads, excess dairy"
    )
    static let vasanta = VedicSeason(
        name: "Vasanta", emoji: "🌸", months: "Mar – Apr",
        dominantDosha: "Kapha", subtitle: "Spring · Kapha spreads",
        doshaAdvice: "Kapha melts and spreads. Lighten up — more movement, less heavy food.",
        favorFoods: "Bitter greens, barley, honey, warming spices, light meals",
        avoidFoods: "Heavy, oily, cold foods, excess sweets, daytime sleep"
    )
    static let grishma = VedicSeason(
        name: "Grishma", emoji: "☀️", months: "May – Jun",
        dominantDosha: "Pitta", subtitle: "Summer · Pitta rises",
        doshaAdvice: "Heat is building. Cool your system. Avoid harsh sun and intense exercise.",
        favorFoods: "Coconut water, cucumber, sweet fruits, rice, mint, coriander",
        avoidFoods: "Spicy, sour, fermented foods, alcohol, red meat"
    )
    static let varsha = VedicSeason(
        name: "Varsha", emoji: "🌧️", months: "Jul – Aug",
        dominantDosha: "Vata", subtitle: "Monsoon · Vata stirs",
        doshaAdvice: "Dampness weakens digestion. Vata rises. Stay warm, eat warm, keep routine.",
        favorFoods: "Old grains, warm soups, ginger tea, light meats, boiled water",
        avoidFoods: "Raw food, heavy meals, cold drinks, excess leafy greens"
    )
    static let sharad = VedicSeason(
        name: "Sharad", emoji: "🍂", months: "Sep – Oct",
        dominantDosha: "Pitta", subtitle: "Autumn · Pitta peaks",
        doshaAdvice: "Summer's heat releases. Cool Pitta with sweet and bitter tastes.",
        favorFoods: "Sweet fruits, coconut, fennel, leafy greens, ghee, wheat",
        avoidFoods: "Spicy, sour, oily, fermented, excessive salt"
    )
    static let hemanta = VedicSeason(
        name: "Hemanta", emoji: "🌙", months: "Nov – Dec",
        dominantDosha: "Vata", subtitle: "Early winter · Strength peaks",
        doshaAdvice: "Cold increases Vata. Digestion is strongest now. Nourish deeply.",
        favorFoods: "Rich warm foods, milk, meats, nuts, sesame, new rice, sugarcane",
        avoidFoods: "Light dry foods, fasting, cold drinks, raw vegetables"
    )
}

#Preview {
    RituView()
        .environmentObject(LocalCache())
}
