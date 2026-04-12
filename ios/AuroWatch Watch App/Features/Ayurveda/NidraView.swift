import SwiftUI
import Charts

/// Nidra — Sleep page. Full-screen concentric rings for Deep/REM/Core.
/// Tap for paged sleep history detail.
struct NidraView: View {
    @EnvironmentObject private var cache: LocalCache
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let w = max(geo.size.width, 1)
                let h = max(geo.size.height, 1)

                ZStack {
                    if let hours = cache.sleepHours, hours > 0 {
                        sleepContent(hours: hours, w: w, h: h)
                    } else {
                        waitingView
                    }
                }
                .frame(width: w, height: h)
            }
            .ignoresSafeArea(.all)
            .toolbar(.hidden, for: .navigationBar)
            .onTapGesture { showHistory = true }
            .navigationDestination(isPresented: $showHistory) {
                NidraHistoryView(cache: cache)
            }
        }
    }

    @ViewBuilder
    private func sleepContent(hours: Double, w: CGFloat, h: CGFloat) -> some View {
        let deep = cache.deepSleepMinutes ?? 0
        let rem = cache.remSleepMinutes ?? 0
        let totalMins = hours * 60
        let core = max(0, totalMins - deep - rem)
        let ringSize = min(w, h) * 0.78

        ZStack {
            // Total sleep ring (outer)
            Circle()
                .trim(from: 0, to: 0.85)
                .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: min(0.85, 0.85 * hours / 9.0))
                .stroke(
                    AngularGradient(
                        colors: [Color(red: 0.3, green: 0.4, blue: 0.8).opacity(0.4),
                                 Color(red: 0.3, green: 0.4, blue: 0.8)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(135))

            // Deep sleep ring (middle)
            Circle()
                .trim(from: 0, to: 0.85)
                .stroke(Color.white.opacity(0.04), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: ringSize - 20, height: ringSize - 20)
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: min(0.85, 0.85 * deep / 90.0))
                .stroke(
                    AngularGradient(
                        colors: [Color(red: 0.15, green: 0.2, blue: 0.6).opacity(0.4),
                                 Color(red: 0.15, green: 0.2, blue: 0.6)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: ringSize - 20, height: ringSize - 20)
                .rotationEffect(.degrees(135))

            // REM ring (inner)
            Circle()
                .trim(from: 0, to: 0.85)
                .stroke(Color.white.opacity(0.04), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: ringSize - 38, height: ringSize - 38)
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: min(0.85, 0.85 * rem / 120.0))
                .stroke(
                    AngularGradient(
                        colors: [Color(red: 0.4, green: 0.55, blue: 0.9).opacity(0.4),
                                 Color(red: 0.4, green: 0.55, blue: 0.9)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: ringSize - 38, height: ringSize - 38)
                .rotationEffect(.degrees(135))

            VStack(spacing: 2) {
                Text(String(format: "%.1f", hours))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.95))
                Text("hours")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AuroTheme.textLight.opacity(0.5))

                HStack(spacing: 8) {
                    stagePill("D", value: Int(deep), color: Color(red: 0.15, green: 0.2, blue: 0.6))
                    stagePill("R", value: Int(rem), color: Color(red: 0.4, green: 0.55, blue: 0.9))
                    stagePill("C", value: Int(core), color: Color(red: 0.45, green: 0.45, blue: 0.55))
                }
                .padding(.top, 6)

                Text(sleepQuality(hours: hours, deep: deep, rem: rem))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(sleepQualityColor(hours: hours, deep: deep))
                    .padding(.top, 2)
            }
            .position(x: w / 2, y: h / 2)
        }
    }

    @ViewBuilder
    private func stagePill(_ label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4, height: 10)
            Text("\(value)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(AuroTheme.textLight.opacity(0.6))
        }
    }

    private var waitingView: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 36))
                .foregroundColor(Color(red: 0.3, green: 0.4, blue: 0.8).opacity(0.5))
            Text("Nidra")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AuroTheme.textLight)
            Text("Sleep data appears\nafter your first night")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                .multilineTextAlignment(.center)
        }
    }

    private func sleepQuality(hours: Double, deep: Double, rem: Double) -> String {
        if hours >= 7 && hours <= 9 && deep >= 45 && rem >= 60 { return "Restorative" }
        if hours >= 6.5 && deep >= 30 { return "Adequate" }
        if hours < 5 { return "Depleted" }
        return "Light"
    }

    private func sleepQualityColor(hours: Double, deep: Double) -> Color {
        if hours >= 7 && deep >= 45 { return AuroTheme.kaphaColor }
        if hours >= 6 { return AuroTheme.goldAccent }
        return AuroTheme.pittaColor
    }
}

// MARK: - Sleep History (paged drill-down)

struct NidraHistoryView: View {
    let cache: LocalCache
    @Environment(\.dismiss) private var dismiss
    @State private var detailPage = 0

    var body: some View {
        TabView(selection: $detailPage) {
            // Page 0: 7-day bar chart
            barChartPage
                .tag(0)

            // Page 1: Deep + REM trends
            trendsPage
                .tag(1)

            // Page 2: Ayurveda explanation
            explanationPage
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var barChartPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 6) {
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text("Sleep")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(AuroTheme.kaphaColor.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)

                Spacer(minLength: 4)

                if cache.sleepHistory.count >= 2 {
                    HStack {
                        Text("7 NIGHTS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AuroTheme.textLight.opacity(0.4))
                            .tracking(0.8)
                        Spacer()
                        if let last = cache.sleepHistory.last {
                            Text(String(format: "%.1fh", last))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.95))
                        }
                    }
                    .padding(.horizontal, 12)

                    Chart {
                        ForEach(Array(cache.sleepHistory.enumerated()), id: \.offset) { idx, hrs in
                            BarMark(x: .value("Night", idx), y: .value("Hours", hrs))
                                .foregroundStyle(
                                    hrs >= 7 ? Color(red: 0.3, green: 0.4, blue: 0.8) :
                                    hrs >= 6 ? Color(red: 0.5, green: 0.5, blue: 0.7) :
                                    Color(red: 0.7, green: 0.4, blue: 0.4)
                                )
                                .cornerRadius(3)
                        }
                        RuleMark(y: .value("Ideal", 7))
                            .foregroundStyle(AuroTheme.textLight.opacity(0.15))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: h * 0.4)
                    .padding(.horizontal, 12)
                }

                Spacer(minLength: 4)
            }
            .frame(width: w, height: h)
        }
    }

    private var trendsPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 10) {
                Spacer()

                if cache.deepSleepHistory.count >= 2 {
                    miniTrend("Deep Sleep", data: cache.deepSleepHistory,
                              color: Color(red: 0.15, green: 0.2, blue: 0.6), suffix: "m",
                              chartWidth: w - 32, chartHeight: h * 0.18)
                }

                if cache.remSleepHistory.count >= 2 {
                    miniTrend("REM", data: cache.remSleepHistory,
                              color: Color(red: 0.4, green: 0.55, blue: 0.9), suffix: "m",
                              chartWidth: w - 32, chartHeight: h * 0.18)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(width: w, height: h)
        }
    }

    private var explanationPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 8) {
                Spacer()

                Text("Nidra in Ayurveda")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AuroTheme.goldAccent.opacity(0.8))

                Text("Sleep is one of the three pillars of life.\n\nDeep sleep repairs Dhatus (tissues) and builds Ojas. REM processes emotions.\n\nIrregular sleep aggravates Vata; excess sleep increases Kapha.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(AuroTheme.textLight.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)

                Spacer()
            }
            .frame(width: w, height: h)
        }
    }

    @ViewBuilder
    private func miniTrend(_ title: String, data: [Double], color: Color, suffix: String, chartWidth: CGFloat, chartHeight: CGFloat) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AuroTheme.textLight.opacity(0.4))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                if let last = data.last {
                    Text("\(Int(last))\(suffix)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(color)
                }
            }

            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { idx, val in
                    AreaMark(x: .value("D", idx), y: .value("V", val))
                        .foregroundStyle(
                            .linearGradient(colors: [color.opacity(0.3), .clear],
                                            startPoint: .top, endPoint: .bottom)
                        )
                    LineMark(x: .value("D", idx), y: .value("V", val))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: chartHeight)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
    }
}

#Preview {
    NidraView()
        .environmentObject(LocalCache())
}
