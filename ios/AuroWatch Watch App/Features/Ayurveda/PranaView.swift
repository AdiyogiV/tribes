import SwiftUI
import Charts

/// Prana — Breath & Oxygen page. Bold SpO2 gauge arc + respiratory rate.
/// Tap for paged trends detail.
struct PranaView: View {
    @EnvironmentObject private var cache: LocalCache
    @State private var showDetail = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let w = max(geo.size.width, 1)
                let h = max(geo.size.height, 1)

                ZStack {
                    if cache.spO2 != nil || cache.respiratoryRate != nil {
                        pranaContent(w: w, h: h)
                    } else {
                        waitingView
                    }
                }
                .frame(width: w, height: h)
            }
            .ignoresSafeArea(.all)
            .toolbar(.hidden, for: .navigationBar)
            .onTapGesture { showDetail = true }
            .navigationDestination(isPresented: $showDetail) {
                PranaDetailView(cache: cache)
            }
        }
    }

    @ViewBuilder
    private func pranaContent(w: CGFloat, h: CGFloat) -> some View {
        let arcSize = min(w, h) * 0.78

        ZStack {
            if let spo2 = cache.spO2 {
                let pct = spo2 > 1 ? spo2 : spo2 * 100
                let fraction = (pct - 85) / 15.0

                Circle()
                    .trim(from: 0.2, to: 0.8)
                    .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: arcSize, height: arcSize)
                Circle()
                    .trim(from: 0.2, to: 0.2 + 0.6 * min(1, max(0, fraction)))
                    .stroke(
                        AngularGradient(
                            colors: [spo2Color(pct).opacity(0.3), spo2Color(pct)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: arcSize, height: arcSize)
            }

            if let resp = cache.respiratoryRate {
                let fraction = (resp - 8) / 16.0
                Circle()
                    .trim(from: 0.2, to: 0.8)
                    .stroke(Color.white.opacity(0.04), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: arcSize - 26, height: arcSize - 26)
                Circle()
                    .trim(from: 0.2, to: 0.2 + 0.6 * min(1, max(0, fraction)))
                    .stroke(AuroTheme.vataColor.opacity(0.7), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: arcSize - 26, height: arcSize - 26)
            }

            VStack(spacing: 4) {
                if let spo2 = cache.spO2 {
                    let pct = spo2 > 1 ? spo2 : spo2 * 100
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.0f", pct))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(spo2Color(pct))
                        Text("%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(spo2Color(pct).opacity(0.5))
                    }
                    Text("Blood Oxygen")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AuroTheme.textLight.opacity(0.5))
                }

                if let resp = cache.respiratoryRate {
                    HStack(spacing: 4) {
                        Image(systemName: "wind")
                            .font(.system(size: 12))
                            .foregroundColor(AuroTheme.vataColor.opacity(0.7))
                        Text(String(format: "%.0f", resp))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AuroTheme.vataColor)
                        Text("/min")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AuroTheme.textLight.opacity(0.35))
                    }
                    .padding(.top, 4)
                }

                Text("Prana")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AuroTheme.goldAccent.opacity(0.4))
                    .textCase(.uppercase)
                    .tracking(1.0)
                    .padding(.top, 2)
            }
            .position(x: w / 2, y: h / 2)
        }
    }

    private var waitingView: some View {
        VStack(spacing: 10) {
            Image(systemName: "lungs.fill")
                .font(.system(size: 36))
                .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.9).opacity(0.5))
            Text("Prana")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AuroTheme.textLight)
            Text("Blood oxygen measured\nduring sleep or on-demand")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                .multilineTextAlignment(.center)
        }
    }

    private func spo2Color(_ pct: Double) -> Color {
        if pct >= 97 { return Color(red: 0.4, green: 0.75, blue: 0.95) }
        if pct >= 95 { return AuroTheme.kaphaColor }
        if pct >= 92 { return AuroTheme.goldAccent }
        return AuroTheme.pittaColor
    }
}

// MARK: - Prana Detail (paged drill-down)

struct PranaDetailView: View {
    let cache: LocalCache
    @Environment(\.dismiss) private var dismiss
    @State private var detailPage = 0

    var body: some View {
        TabView(selection: $detailPage) {
            trendsPage.tag(0)
            readingsPage.tag(1)
            explanationPage.tag(2)
        }
        .tabViewStyle(.verticalPage)
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var trendsPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 8) {
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text("Prana")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(AuroTheme.vataColor.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)

                Spacer(minLength: 4)

                if cache.spO2History.count >= 2 {
                    trendCard("Blood Oxygen", data: cache.spO2History,
                              color: Color(red: 0.4, green: 0.75, blue: 0.95), suffix: "%",
                              chartHeight: h * 0.2)
                }
                if cache.respRateHistory.count >= 2 {
                    trendCard("Breath Rate", data: cache.respRateHistory,
                              color: AuroTheme.vataColor, suffix: "/m",
                              chartHeight: h * 0.2)
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 8)
            .frame(width: w, height: h)
        }
    }

    private var readingsPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 8) {
                Spacer()

                if let spo2 = cache.spO2 {
                    let pct = spo2 > 1 ? spo2 : spo2 * 100
                    readingRow("SpO2", value: String(format: "%.1f%%", pct),
                               color: pct >= 95 ? AuroTheme.kaphaColor : AuroTheme.pittaColor)
                }
                if let resp = cache.respiratoryRate {
                    readingRow("Resp Rate", value: String(format: "%.1f /min", resp),
                               color: (resp >= 12 && resp <= 20) ? AuroTheme.kaphaColor : AuroTheme.pittaColor)
                }
                if let temp = cache.wristTempDeviation {
                    let sign = temp >= 0 ? "+" : ""
                    readingRow("Temp", value: "\(sign)\(String(format: "%.2f", temp))°C",
                               color: abs(temp) < 0.3 ? AuroTheme.kaphaColor : AuroTheme.pittaColor)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(width: w, height: h)
        }
    }

    private var explanationPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 8) {
                Spacer()

                Text("Prana Vayu")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AuroTheme.goldAccent.opacity(0.8))

                Text("Prana Vayu governs breath, oxygen flow, and sensory intake.\n\nStrong Prana = steady SpO2, calm breathing.\n\nElevated breath rate may signal Vata disturbance.")
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
    private func readingRow(_ name: String, value: String, color: Color) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AuroTheme.textLight.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(AuroTheme.textLight.opacity(0.85))
            Circle().fill(color).frame(width: 6, height: 6)
        }
    }

    @ViewBuilder
    private func trendCard(_ title: String, data: [Double], color: Color, suffix: String, chartHeight: CGFloat) -> some View {
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
                            .linearGradient(colors: [color.opacity(0.25), .clear],
                                            startPoint: .top, endPoint: .bottom)
                        )
                    LineMark(x: .value("D", idx), y: .value("V", val))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                if let last = data.last {
                    PointMark(x: .value("D", data.count - 1), y: .value("V", last))
                        .foregroundStyle(color)
                        .symbolSize(25)
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
    PranaView()
        .environmentObject(LocalCache())
}
