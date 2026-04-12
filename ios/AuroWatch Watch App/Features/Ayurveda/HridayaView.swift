import SwiftUI
import Charts

/// Hridaya — Heart page. Live heart rate with animated pulse ring,
/// HRV trend, resting HR, and Nadi dosha analysis.
struct HridayaView: View {
    @EnvironmentObject private var cache: LocalCache
    @EnvironmentObject private var health: HealthKitManager
    @State private var showDetail = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let w = max(geo.size.width, 1)
                let h = max(geo.size.height, 1)

                ZStack {
                    if cache.currentHeartRate != nil || cache.latestHRV != nil {
                        heartContent(w: w, h: h)
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
                HridayaDetailView(cache: cache)
            }
            .onAppear { startPulse() }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func heartContent(w: CGFloat, h: CGFloat) -> some View {
        let ringSize = min(w, h) * 0.75

        ZStack {
            Circle()
                .stroke(AuroTheme.pittaColor.opacity(0.06), lineWidth: 20)
                .frame(width: ringSize + 10, height: ringSize + 10)
                .scaleEffect(pulseScale)

            Circle()
                .stroke(AuroTheme.pittaColor.opacity(0.10), lineWidth: 2)
                .frame(width: ringSize - 4, height: ringSize - 4)
                .scaleEffect(pulseScale * 0.98)

            if let hrv = cache.latestHRV {
                let fraction = min(1, hrv / 100.0)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        AngularGradient(
                            colors: [AuroTheme.vataColor.opacity(0.3), AuroTheme.vataColor.opacity(0.8)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: ringSize - 14, height: ringSize - 14)
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 3) {
                if let hr = cache.currentHeartRate {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AuroTheme.pittaColor)
                            .scaleEffect(pulseScale)
                        Text("\(Int(hr))")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(AuroTheme.textLight)
                    }
                    Text("bpm")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AuroTheme.textLight.opacity(0.4))
                } else {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 28))
                        .foregroundColor(AuroTheme.pittaColor.opacity(0.5))
                }

                HStack(spacing: 12) {
                    if let hrv = cache.latestHRV {
                        VStack(spacing: 0) {
                            Text(String(format: "%.0f", hrv))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(AuroTheme.vataColor)
                            Text("HRV")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(AuroTheme.textLight.opacity(0.3))
                        }
                    }
                    if let rhr = cache.latestRestingHR {
                        VStack(spacing: 0) {
                            Text(String(format: "%.0f", rhr))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(AuroTheme.kaphaColor)
                            Text("Rest")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(AuroTheme.textLight.opacity(0.3))
                        }
                    }
                }
                .padding(.top, 4)

                if let dosha = cache.nadiDominantDosha {
                    HStack(spacing: 3) {
                        Text(AuroTheme.doshaGlyph(dosha))
                            .font(.system(size: 10))
                        Text("\(dosha) Nadi")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AuroTheme.doshaColor(dosha).opacity(0.7))
                    }
                    .padding(.top, 2)
                }
            }
            .position(x: w / 2, y: h / 2)
        }
    }

    private var waitingView: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .foregroundColor(AuroTheme.pittaColor.opacity(0.4))
            Text("Hridaya")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AuroTheme.textLight)
            Text("Heart data appears\nafter wearing your watch")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                .multilineTextAlignment(.center)
        }
    }

    private func startPulse() {
        guard let hr = cache.currentHeartRate, hr > 0 else { return }
        let interval = 60.0 / hr
        withAnimation(.easeInOut(duration: interval * 0.3).repeatForever(autoreverses: true)) {
            pulseScale = 1.04
        }
    }
}

// MARK: - Heart Detail (paged drill-down)

struct HridayaDetailView: View {
    let cache: LocalCache
    @Environment(\.dismiss) private var dismiss
    @State private var detailPage = 0

    var body: some View {
        TabView(selection: $detailPage) {
            // Page 0: Trends
            trendsPage
                .tag(0)

            // Page 1: Current readings
            readingsPage
                .tag(1)

            // Page 2: Nadi explanation
            nadiExplanationPage
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Trends Page

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
                            Text("Heart")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(AuroTheme.pittaColor.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)

                Spacer(minLength: 4)

                if cache.hrvHistory.count >= 2 {
                    trendCard("HRV", data: cache.hrvHistory, color: AuroTheme.vataColor, suffix: "ms", chartHeight: h * 0.2)
                }

                if cache.restingHRHistory.count >= 2 {
                    trendCard("Resting HR", data: cache.restingHRHistory, color: AuroTheme.kaphaColor, suffix: "bpm", chartHeight: h * 0.2)
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 8)
            .frame(width: w, height: h)
        }
    }

    // MARK: - Readings Page

    private var readingsPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 8) {
                Spacer()

                if let hr = cache.currentHeartRate {
                    readingRow("Heart Rate", value: "\(Int(hr)) bpm")
                }
                if let hrv = cache.latestHRV {
                    readingRow("HRV (SDNN)", value: String(format: "%.1f ms", hrv))
                }
                if let rhr = cache.latestRestingHR {
                    readingRow("Resting HR", value: "\(Int(rhr)) bpm")
                }
                if let rec = cache.hrRecovery {
                    readingRow("Recovery", value: "\(Int(rec)) bpm drop")
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(width: w, height: h)
        }
    }

    // MARK: - Nadi Explanation Page

    private var nadiExplanationPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 8) {
                Spacer()

                Text("Nadi Pariksha")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AuroTheme.goldAccent.opacity(0.8))

                Text("In Ayurveda, the pulse reveals dosha state.\n\n🐍 Sarpa gati = Vata\n🐸 Manduka gati = Pitta\n🦢 Hamsa gati = Kapha\n\nYour HRV patterns approximate these rhythms.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(AuroTheme.textLight.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                Spacer()
            }
            .frame(width: w, height: h)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func readingRow(_ name: String, value: String) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AuroTheme.textLight.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(AuroTheme.textLight.opacity(0.85))
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
    HridayaView()
        .environmentObject(LocalCache())
        .environmentObject(HealthKitManager())
}
