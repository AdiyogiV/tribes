import SwiftUI

/// Muhurat Timeline — full-screen page.
/// Uses ScrollView only for the list (can have many windows), but no nav bar.
struct MuhuratView: View {
    @EnvironmentObject private var cache: LocalCache

    var body: some View {
        GeometryReader { geo in
            if cache.muhuratWindows.isEmpty {
                // Empty state — centered
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 36))
                        .foregroundColor(AuroTheme.goldAccent.opacity(0.5))
                    Text("Time Guidance")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AuroTheme.textLight)
                    Text("Open Aurogram on your phone\nto load today's muhurat")
                        .font(.system(size: 11))
                        .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(width: geo.size.width, height: geo.size.height)
            } else {
                // Muhurat list
                VStack(spacing: 0) {
                    Text("Time Guidance")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AuroTheme.goldAccent)
                        .padding(.top, 4)
                        .padding(.bottom, 4)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 3) {
                            let now = Date.now
                            let sorted = sortedWindows()

                            ForEach(Array(sorted.enumerated()), id: \.offset) { _, window in
                                muhuratRow(window: window, now: now, width: geo.size.width)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 8)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Row

    @ViewBuilder
    private func muhuratRow(window: [String: String], now: Date, width: CGFloat) -> some View {
        let name = window["name"] ?? "Unknown"
        let startStr = window["start"] ?? ""
        let endStr = window["end"] ?? ""
        let type = window["type"] ?? "neutral"
        let isAuspicious = type == "auspicious"
        let isCurrent = isCurrentWindow(start: startStr, end: endStr, now: now)
        let isPast = isWindowPast(end: endStr, now: now)

        HStack(spacing: 6) {
            Circle()
                .fill(indicatorColor(type: type, isCurrent: isCurrent, isPast: isPast))
                .frame(width: 8, height: 8)
                .overlay {
                    if isCurrent {
                        Circle()
                            .stroke(indicatorColor(type: type, isCurrent: true, isPast: false).opacity(0.4), lineWidth: 2)
                            .frame(width: 14, height: 14)
                    }
                }

            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                    .foregroundColor(isPast ? AuroTheme.textLight.opacity(0.35) : AuroTheme.textLight)
                Text("\(startStr) – \(endStr)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(isPast ? AuroTheme.textLight.opacity(0.25) : AuroTheme.textLight.opacity(AuroTheme.textTertiary))
            }

            Spacer()

            Text(isAuspicious ? "✦" : "✧")
                .font(.system(size: 13))
                .foregroundColor(isPast ? AuroTheme.textLight.opacity(0.15) : isAuspicious ? .green : .red.opacity(0.7))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            isCurrent
                ? RoundedRectangle(cornerRadius: 6)
                    .fill(isAuspicious ? Color.green.opacity(0.10) : Color.red.opacity(0.08))
                : nil
        )
    }

    // MARK: - Helpers

    private func sortedWindows() -> [[String: String]] {
        cache.muhuratWindows.sorted { ($0["start"] ?? "") < ($1["start"] ?? "") }
    }

    private func indicatorColor(type: String, isCurrent: Bool, isPast: Bool) -> Color {
        if isPast { return AuroTheme.textLight.opacity(0.15) }
        return type == "auspicious" ? .green : .red.opacity(0.7)
    }

    private func parseTime(_ str: String) -> (hour: Int, minute: Int)? {
        let parts = str.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return (parts[0], parts[1])
    }

    private func isCurrentWindow(start: String, end: String, now: Date) -> Bool {
        guard let s = parseTime(start), let e = parseTime(end) else { return false }
        let cal = Calendar.current
        let nowMins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        return nowMins >= (s.hour * 60 + s.minute) && nowMins < (e.hour * 60 + e.minute)
    }

    private func isWindowPast(end: String, now: Date) -> Bool {
        guard let e = parseTime(end) else { return false }
        let cal = Calendar.current
        return (cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)) >= (e.hour * 60 + e.minute)
    }
}

#Preview {
    let cache = LocalCache()
    cache.muhuratWindows = [
        ["name": "Brahma Muhurat", "start": "04:24", "end": "05:12", "type": "auspicious"],
        ["name": "Rahu Kaal", "start": "07:30", "end": "09:00", "type": "inauspicious"],
        ["name": "Abhijit Muhurat", "start": "11:48", "end": "12:36", "type": "auspicious"],
        ["name": "Yamaganda", "start": "13:30", "end": "15:00", "type": "inauspicious"],
    ]
    return MuhuratView().environmentObject(cache)
}
