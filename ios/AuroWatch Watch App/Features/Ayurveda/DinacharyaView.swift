import SwiftUI

/// Dinacharya — the Ayurvedic daily clock.
/// Shows current dosha period as a bold full-screen display.
/// Tap to see the full day timeline (paged — 3 periods per page).
struct DinacharyaView: View {
    @EnvironmentObject private var cache: LocalCache
    @State private var showTimeline = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let now = timeline.date
                let hour = Calendar.current.component(.hour, from: now)
                let minute = Calendar.current.component(.minute, from: now)
                let hourFloat = Double(hour) + Double(minute) / 60.0
                let current = DoshaPeriod.current(forHour: hourFloat)
                let next = DoshaPeriod.next(forHour: hourFloat)

                GeometryReader { geo in
                    let w = max(geo.size.width, 1)
                    let h = max(geo.size.height, 1)

                    ZStack {
                        doshaRing(current: current, size: min(w, h) * 0.88)

                        VStack(spacing: 4) {
                            Text(current.dosha)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(AuroTheme.doshaColor(current.dosha))

                            Text(current.timeLabel)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(AuroTheme.textLight.opacity(0.7))

                            Text(current.guidance)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AuroTheme.textLight.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 16)
                                .padding(.top, 2)

                            HStack(spacing: 4) {
                                Text("Next")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                                Text(next.dosha)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AuroTheme.doshaColor(next.dosha).opacity(0.7))
                                Text(next.startsAt)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                            }
                            .padding(.top, 4)
                        }
                        .position(x: w / 2, y: h / 2)
                    }
                    .frame(width: w, height: h)
                }
                .ignoresSafeArea(.all)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onTapGesture { showTimeline = true }
            .navigationDestination(isPresented: $showTimeline) {
                DinacharyaTimelineView()
            }
        }
    }

    @ViewBuilder
    private func doshaRing(current: DoshaPeriod, size: CGFloat) -> some View {
        ZStack {
            ForEach(DoshaPeriod.allPeriods, id: \.id) { period in
                Circle()
                    .trim(from: period.ringStart, to: period.ringEnd)
                    .stroke(
                        AuroTheme.doshaColor(period.dosha).opacity(period.id == current.id ? 0.6 : 0.12),
                        style: StrokeStyle(lineWidth: period.id == current.id ? 6 : 3, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

// MARK: - Full Day Timeline (paged drill-down — 3 per page)

struct DinacharyaTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    var body: some View {
        let periods = DoshaPeriod.allPeriods
        let pages = periods.chunked(into: 3)

        TabView(selection: $page) {
            ForEach(Array(pages.enumerated()), id: \.offset) { idx, group in
                timelinePage(group, isFirst: idx == 0)
                    .tag(idx)
            }
        }
        .tabViewStyle(.verticalPage)
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func timelinePage(_ periods: [DoshaPeriod], isFirst: Bool) -> some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            let currentId = DoshaPeriod.current(forHour: currentHour()).id

            VStack(spacing: 0) {
                if isFirst {
                    HStack {
                        Button { dismiss() } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Rhythm")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(AuroTheme.goldAccent.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                }

                Spacer(minLength: 4)

                ForEach(periods, id: \.id) { period in
                    let isCurrent = period.id == currentId
                    timelineRow(period, isCurrent: isCurrent)
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 8)
            .frame(width: w, height: h)
        }
    }

    @ViewBuilder
    private func timelineRow(_ period: DoshaPeriod, isCurrent: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 0) {
                Circle()
                    .fill(AuroTheme.doshaColor(period.dosha).opacity(isCurrent ? 1.0 : 0.3))
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(period.dosha)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AuroTheme.doshaColor(period.dosha).opacity(isCurrent ? 1.0 : 0.5))
                    Spacer()
                    Text(period.timeLabel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(AuroTheme.textLight.opacity(isCurrent ? 0.7 : 0.3))
                }
                Text(period.guidance)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(AuroTheme.textLight.opacity(isCurrent ? 0.8 : 0.35))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            isCurrent ?
                RoundedRectangle(cornerRadius: 8)
                    .fill(AuroTheme.doshaColor(period.dosha).opacity(0.08)) :
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
        )
    }

    private func currentHour() -> Double {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: .now)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
    }
}

// MARK: - Dosha Period Model

struct DoshaPeriod {
    let id: String
    let dosha: String
    let startHour: Double
    let endHour: Double
    let guidance: String
    let ringStart: Double
    let ringEnd: Double

    var timeLabel: String {
        "\(formatHour(startHour))–\(formatHour(endHour))"
    }

    var startsAt: String {
        formatHour(startHour)
    }

    static let allPeriods: [DoshaPeriod] = [
        DoshaPeriod(id: "vata_am", dosha: "Vata", startHour: 2, endHour: 6,
                    guidance: "Light sleep, dreams. Best to rise before 6.",
                    ringStart: 2.0/24.0, ringEnd: 6.0/24.0),
        DoshaPeriod(id: "kapha_am", dosha: "Kapha", startHour: 6, endHour: 10,
                    guidance: "Move your body. Light breakfast.",
                    ringStart: 6.0/24.0, ringEnd: 10.0/24.0),
        DoshaPeriod(id: "pitta_mid", dosha: "Pitta", startHour: 10, endHour: 14,
                    guidance: "Strongest digestion. Main meal now.",
                    ringStart: 10.0/24.0, ringEnd: 14.0/24.0),
        DoshaPeriod(id: "vata_pm", dosha: "Vata", startHour: 14, endHour: 18,
                    guidance: "Creative energy. Stay hydrated.",
                    ringStart: 14.0/24.0, ringEnd: 18.0/24.0),
        DoshaPeriod(id: "kapha_pm", dosha: "Kapha", startHour: 18, endHour: 22,
                    guidance: "Light dinner by 7. Wind down.",
                    ringStart: 18.0/24.0, ringEnd: 22.0/24.0),
        DoshaPeriod(id: "pitta_night", dosha: "Pitta", startHour: 22, endHour: 26,
                    guidance: "Deep repair. Be asleep before 10.",
                    ringStart: 22.0/24.0, ringEnd: 26.0/24.0),
    ]

    static func current(forHour hour: Double) -> DoshaPeriod {
        let h = hour < 2 ? hour + 24 : hour
        return allPeriods.first { h >= $0.startHour && h < $0.endHour } ?? allPeriods[0]
    }

    static func next(forHour hour: Double) -> DoshaPeriod {
        let current = self.current(forHour: hour)
        guard let idx = allPeriods.firstIndex(where: { $0.id == current.id }) else { return allPeriods[0] }
        return allPeriods[(idx + 1) % allPeriods.count]
    }

    private func formatHour(_ h: Double) -> String {
        let normalized = h.truncatingRemainder(dividingBy: 24)
        let hr = Int(normalized)
        let mn = Int((normalized - Double(hr)) * 60)
        if mn == 0 {
            if hr == 0 { return "12am" }
            if hr < 12 { return "\(hr)am" }
            if hr == 12 { return "12pm" }
            return "\(hr - 12)pm"
        }
        let ampm = hr < 12 ? "am" : "pm"
        let displayHr = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr)
        return "\(displayHr):\(String(format: "%02d", mn))\(ampm)"
    }
}

#Preview {
    DinacharyaView()
        .environmentObject(LocalCache())
}
