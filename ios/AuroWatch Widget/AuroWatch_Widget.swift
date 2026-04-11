import WidgetKit
import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Shared Timeline Provider & Entry
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Rich timeline entry with all data needed across all complications.
struct VedicEntry: TimelineEntry {
    let date: Date

    // Vedic time
    let ghati: Int
    let pala: Int
    let ghatiFloat: Double
    let palaFloat: Double
    let praharName: String
    let praharNumber: Int
    let praharIndex: Int
    let isDaytime: Bool

    // Dosha
    let currentDosha: String

    // Panchang (from cache)
    let vedicDate: String?
    let samvatYear: String?

    // Muhurat (from cache)
    let nextMuhuratName: String?
    let nextMuhuratStart: String?
    let nextMuhuratType: String?  // "auspicious" or "inauspicious"

    // Nadi (from cache)
    let nadiDosha: String?

    // Western time helpers
    var westernTime: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
    var westernTimeShort: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }

    // Vedic formatted strings
    var ghatiPala: String { "\(ghati).\(String(format: "%02d", pala))" }
    var ghatiPalaFull: String { "Ghati \(ghati) · Pala \(pala)" }
    var praharProgress: Double { Double(pala) / 60.0 }
    var dayProgress: Double { ghatiFloat / 60.0 }

    /// Seconds remaining in current Pala (0–24)
    var palaSecondsRemaining: Int {
        let totalSecs = Calendar.current.component(.second, from: date)
        return VedicTimeCalculator.secondsPerPala - (totalSecs % VedicTimeCalculator.secondsPerPala)
    }
}

/// Shared provider used by all complications.
struct VedicTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> VedicEntry {
        makeEntry(for: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (VedicEntry) -> Void) {
        completion(makeEntry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VedicEntry>) -> Void) {
        var entries: [VedicEntry] = []
        let now = Date.now

        // Generate entries every Pala (24 seconds) for next 2 hours
        // This gives smooth Pala-level updates on the watch face
        for palaOffset in stride(from: 0, through: 300, by: 1) {
            let date = now.addingTimeInterval(Double(palaOffset) * 24.0)
            entries.append(makeEntry(for: date))
        }

        // Refresh after 2 hours
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 2, to: now)!
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }

    private func makeEntry(for date: Date) -> VedicEntry {
        let vt = VedicTimeCalculator.calculate(from: date)
        let hour = Calendar.current.component(.hour, from: date)
        let dosha = VedicTimeCalculator.currentDosha(forHour: hour)

        let defaults = UserDefaults.standard
        let vedicDate = defaults.string(forKey: "auro_vedicDate")
        let samvatYear = defaults.string(forKey: "auro_samvatYear")
        let nadiDosha = defaults.string(forKey: "auro_nadiDosha")

        // Parse next muhurat window
        var nextName: String?
        var nextStart: String?
        var nextType: String?
        if let data = defaults.data(forKey: "auro_muhurat"),
           let windows = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            let nowMins = hour * 60 + Calendar.current.component(.minute, from: date)
            for w in windows.sorted(by: { ($0["start"] ?? "") < ($1["start"] ?? "") }) {
                if let startStr = w["start"],
                   let parts = Optional(startStr.split(separator: ":")),
                   parts.count >= 2,
                   let h = Int(parts[0]), let m = Int(parts[1]),
                   h * 60 + m > nowMins {
                    nextName = w["name"]
                    nextStart = startStr
                    nextType = w["type"]
                    break
                }
            }
        }

        return VedicEntry(
            date: date,
            ghati: vt.ghati,
            pala: vt.pala,
            ghatiFloat: vt.ghatiFloat,
            palaFloat: vt.palaFloat,
            praharName: vt.praharName,
            praharNumber: vt.praharNumber,
            praharIndex: vt.praharIndex,
            isDaytime: vt.isDaytime,
            currentDosha: dosha,
            vedicDate: vedicDate,
            samvatYear: samvatYear,
            nextMuhuratName: nextName,
            nextMuhuratStart: nextStart,
            nextMuhuratType: nextType,
            nadiDosha: nadiDosha
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Helpers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private func doshaColor(_ dosha: String) -> Color {
    switch dosha.lowercased() {
    case "vata":  return AuroTheme.vataColor
    case "pitta": return AuroTheme.pittaColor
    case "kapha": return AuroTheme.kaphaColor
    default:      return AuroTheme.primaryColor
    }
}

private let doshaSymbol: [String: String] = [
    "Vata": "𑁍",   // wind
    "Pitta": "𑁋",  // fire
    "Kapha": "𑁌",  // water
]

/// Sun/moon glyph based on day/night
private func dayNightGlyph(_ isDaytime: Bool) -> String {
    isDaytime ? "☉" : "☽"
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1. VEDIC TIME — Ghati-focused (original, enhanced)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct VedicTimeComplication: Widget {
    let kind = "VedicTime"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VedicTimelineProvider()) { entry in
            VedicTimeAdaptive(entry: entry).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Vedic Time")
        .description("Ghati, Pala, and Prahar at a glance.")
        .supportedFamilies({
            var families: [WidgetFamily] = [.accessoryCircular, .accessoryRectangular, .accessoryInline]
            #if os(watchOS)
            families.append(.accessoryCorner)
            #endif
            return families
        }())
    }
}

struct VedicTimeAdaptive: View {
    let entry: VedicEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        switch family {
        case .accessoryCircular:
            // Ghati ring with Pala inside
            ZStack {
                Circle()
                    .trim(from: 0, to: Double(entry.pala) / 60.0)
                    .stroke(doshaColor(entry.currentDosha), lineWidth: 3)
                    .rotationEffect(.degrees(-90))
                    .padding(2)
                VStack(spacing: -2) {
                    Text("\(entry.ghati)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(doshaColor(entry.currentDosha))
                    Text("·\(entry.pala)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(dayNightGlyph(entry.isDaytime)) \(entry.praharName)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(doshaColor(entry.currentDosha))
                    Spacer()
                    Text(entry.currentDosha)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(doshaColor(entry.currentDosha).opacity(0.7))
                }
                Text("Ghati \(entry.ghati) · Pala \(entry.pala)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.85))
                if let vd = entry.vedicDate {
                    Text(vd)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        case .accessoryInline:
            Text("\(dayNightGlyph(entry.isDaytime)) G\(entry.ghati)·P\(entry.pala) \(entry.praharName)")
        case .accessoryCorner:
            Text("\(entry.ghati)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(doshaColor(entry.currentDosha))
                .widgetLabel { Text("G \(entry.ghati) · P \(entry.pala)") }
        default:
            Text("\(entry.ghati)")
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 2. PALA PULSE — Real-time Pala counter
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct PalaPulseComplication: Widget {
    let kind = "PalaPulse"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VedicTimelineProvider()) { entry in
            PalaPulseAdaptive(entry: entry).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Pala Pulse")
        .description("Live Pala counter — the heartbeat of Vedic time.")
        .supportedFamilies({
            var families: [WidgetFamily] = [.accessoryCircular, .accessoryRectangular, .accessoryInline]
            #if os(watchOS)
            families.append(.accessoryCorner)
            #endif
            return families
        }())
    }
}

struct PalaPulseAdaptive: View {
    let entry: VedicEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        switch family {
        case .accessoryCircular:
            // Pala countdown ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 4)
                    .padding(2)
                // Pala progress within current Ghati
                Circle()
                    .trim(from: 0, to: Double(entry.pala) / 60.0)
                    .stroke(
                        AngularGradient(
                            colors: [doshaColor(entry.currentDosha).opacity(0.3), doshaColor(entry.currentDosha)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(2)
                VStack(spacing: -2) {
                    Text("\(entry.pala)")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text("pala")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Pala \(entry.pala)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("of 60")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("G\(entry.ghati)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(doshaColor(entry.currentDosha))
                }
                // Progress bar — Pala within Ghati
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.15))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(doshaColor(entry.currentDosha).opacity(0.7))
                            .frame(width: geo.size.width * Double(entry.pala) / 60.0)
                    }
                }
                .frame(height: 6)
                Text("\(entry.westernTimeShort) → \(entry.ghatiPala) Vedic")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        case .accessoryInline:
            Text("Pala \(entry.pala)/60 · Ghati \(entry.ghati)")
        case .accessoryCorner:
            Text("\(entry.pala)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .widgetLabel {
                    Gauge(value: Double(entry.pala), in: 0...60) {
                        Text("P")
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                }
        default:
            Text("\(entry.pala)")
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 3. DUAL TIME — Vedic + Western side by side
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct DualTimeComplication: Widget {
    let kind = "DualTime"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VedicTimelineProvider()) { entry in
            DualTimeAdaptive(entry: entry).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Dual Time")
        .description("Western and Vedic time together.")
        .supportedFamilies({
            var families: [WidgetFamily] = [.accessoryCircular, .accessoryRectangular, .accessoryInline]
            #if os(watchOS)
            families.append(.accessoryCorner)
            #endif
            return families
        }())
    }
}

struct DualTimeAdaptive: View {
    let entry: VedicEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text(entry.westernTimeShort)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Rectangle()
                    .fill(doshaColor(entry.currentDosha))
                    .frame(width: 24, height: 1)
                    .padding(.vertical, 1)
                Text(entry.ghatiPala)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(doshaColor(entry.currentDosha))
            }
        case .accessoryRectangular:
            HStack(spacing: 0) {
                // Western side
                VStack(alignment: .center, spacing: 1) {
                    Text(entry.westernTime)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Western")
                        .font(.system(size: 7, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(doshaColor(entry.currentDosha).opacity(0.5))
                    .frame(width: 1, height: 28)

                // Vedic side
                VStack(alignment: .center, spacing: 1) {
                    Text("G\(entry.ghati)·P\(entry.pala)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(doshaColor(entry.currentDosha))
                    Text(entry.praharName)
                        .font(.system(size: 7, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        case .accessoryInline:
            Text("\(entry.westernTimeShort) ↔ G\(entry.ghati)·P\(entry.pala)")
        case .accessoryCorner:
            Text(entry.ghatiPala)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(doshaColor(entry.currentDosha))
                .widgetLabel { Text(entry.westernTime) }
        default:
            Text(entry.ghatiPala)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 4. DOSHA CLOCK — Current Ayurvedic period
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct DoshaClockComplication: Widget {
    let kind = "DoshaClock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VedicTimelineProvider()) { entry in
            DoshaClockAdaptive(entry: entry).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Dosha Clock")
        .description("Which dosha rules right now — live Ayurvedic rhythm.")
        .supportedFamilies({
            var families: [WidgetFamily] = [.accessoryCircular, .accessoryRectangular, .accessoryInline]
            #if os(watchOS)
            families.append(.accessoryCorner)
            #endif
            return families
        }())
    }
}

struct DoshaClockAdaptive: View {
    let entry: VedicEntry
    @Environment(\.widgetFamily) var family

    // Compute dosha cycle position (6 periods of 4 hours each)
    private var doshaPeriodProgress: Double {
        let hour = Calendar.current.component(.hour, from: entry.date)
        let minute = Calendar.current.component(.minute, from: entry.date)
        let totalMinutes = hour * 60 + minute
        // Each dosha period is 4 hours = 240 minutes
        let periodMinutes = totalMinutes % 240
        return Double(periodMinutes) / 240.0
    }

    private var nextDosha: String {
        switch entry.currentDosha {
        case "Vata": return "Kapha"
        case "Kapha": return "Pitta"
        case "Pitta": return "Vata"
        default: return "Vata"
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                // Three-segment ring showing V/P/K
                Circle()
                    .trim(from: 0, to: 0.33)
                    .stroke(AuroTheme.vataColor.opacity(entry.currentDosha == "Vata" ? 1 : 0.2), lineWidth: 4)
                    .rotationEffect(.degrees(-90))
                    .padding(1)
                Circle()
                    .trim(from: 0.33, to: 0.66)
                    .stroke(AuroTheme.kaphaColor.opacity(entry.currentDosha == "Kapha" ? 1 : 0.2), lineWidth: 4)
                    .rotationEffect(.degrees(-90))
                    .padding(1)
                Circle()
                    .trim(from: 0.66, to: 1.0)
                    .stroke(AuroTheme.pittaColor.opacity(entry.currentDosha == "Pitta" ? 1 : 0.2), lineWidth: 4)
                    .rotationEffect(.degrees(-90))
                    .padding(1)

                VStack(spacing: -1) {
                    Text(String(entry.currentDosha.prefix(1)))
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(doshaColor(entry.currentDosha))
                    Text(entry.currentDosha.lowercased())
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(entry.currentDosha) Time")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(doshaColor(entry.currentDosha))
                    Spacer()
                    Text(entry.isDaytime ? "Day" : "Night")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                // Progress through current dosha period
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.15))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(doshaColor(entry.currentDosha))
                            .frame(width: geo.size.width * doshaPeriodProgress)
                    }
                }
                .frame(height: 6)
                HStack {
                    // Show all three with current highlighted
                    ForEach(["Vata", "Pitta", "Kapha"], id: \.self) { d in
                        Text(d)
                            .font(.system(size: 8, weight: d == entry.currentDosha ? .bold : .regular))
                            .foregroundColor(d == entry.currentDosha ? doshaColor(d) : .secondary.opacity(0.4))
                    }
                    Spacer()
                    Text("→ \(nextDosha)")
                        .font(.system(size: 8))
                        .foregroundColor(doshaColor(nextDosha).opacity(0.5))
                }
            }
        case .accessoryInline:
            Text("\(entry.currentDosha) Time · \(entry.praharName)")
        case .accessoryCorner:
            Text(String(entry.currentDosha.prefix(1)))
                .font(.system(size: 24, weight: .black))
                .foregroundColor(doshaColor(entry.currentDosha))
                .widgetLabel {
                    Gauge(value: doshaPeriodProgress) {
                        Text(entry.currentDosha)
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(doshaColor(entry.currentDosha))
                }
        default:
            Text(entry.currentDosha)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 5. MUHURAT ALERT — Next auspicious/inauspicious window
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct MuhuratAlertComplication: Widget {
    let kind = "MuhuratAlert"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VedicTimelineProvider()) { entry in
            MuhuratAlertAdaptive(entry: entry).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Muhurat Alert")
        .description("Upcoming auspicious or inauspicious time window.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct MuhuratAlertAdaptive: View {
    let entry: VedicEntry
    @Environment(\.widgetFamily) var family

    private var isAuspicious: Bool { entry.nextMuhuratType == "auspicious" }
    private var muhuratColor: Color { isAuspicious ? .green : .red.opacity(0.8) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            if let name = entry.nextMuhuratName {
                ZStack {
                    Circle()
                        .stroke(muhuratColor.opacity(0.3), lineWidth: 3)
                        .padding(2)
                    VStack(spacing: 1) {
                        Image(systemName: isAuspicious ? "star.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(muhuratColor)
                        Text(abbreviate(name))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        if let t = entry.nextMuhuratStart {
                            Text(t)
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.green.opacity(0.6))
                    Text("Clear")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        case .accessoryRectangular:
            if let name = entry.nextMuhuratName {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: isAuspicious ? "star.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(muhuratColor)
                        Text("Next: \(name)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    HStack {
                        Text("at \(entry.nextMuhuratStart ?? "—")")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(muhuratColor)
                        Spacer()
                        Text(isAuspicious ? "Auspicious" : "Avoid")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(muhuratColor.opacity(0.7))
                    }
                    Text(entry.praharName)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All clear today")
                            .font(.system(size: 12, weight: .medium))
                    }
                    Text("No upcoming muhurat windows")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        case .accessoryInline:
            if let name = entry.nextMuhuratName, let t = entry.nextMuhuratStart {
                Text("\(isAuspicious ? "✦" : "⚠") \(abbreviate(name)) at \(t)")
            } else {
                Text("✓ No upcoming muhurat")
            }
        default:
            Text("—")
        }
    }

    private func abbreviate(_ name: String) -> String {
        // Shorten long names for circular view
        let map: [String: String] = [
            "Brahma Muhurat": "Brahma",
            "Abhijit Muhurat": "Abhijit",
            "Rahu Kala": "Rahu",
            "Gulika Kala": "Gulika",
            "Amrit Kaal": "Amrit",
        ]
        return map[name] ?? String(name.prefix(7))
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 6. TITHI — Vedic date on watch face
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct TithiComplication: Widget {
    let kind = "Tithi"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VedicTimelineProvider()) { entry in
            TithiAdaptive(entry: entry).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Tithi")
        .description("Today's Vedic date — Tithi, Paksha, and lunar month.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TithiAdaptive: View {
    let entry: VedicEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 1) {
                // Moon phase glyph based on day/night
                Text(entry.isDaytime ? "☉" : "☽")
                    .font(.system(size: 14))
                if let vd = entry.vedicDate {
                    // Try to extract just tithi name (last word)
                    let parts = vd.split(separator: " ")
                    Text(parts.last.map(String.init) ?? vd)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AuroTheme.primaryColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    Text("—")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                if let vd = entry.vedicDate {
                    Text(vd)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AuroTheme.primaryColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                if let sy = entry.samvatYear {
                    Text(sy)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                // Western date for reference
                Text(entry.date, style: .date)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        case .accessoryInline:
            if let vd = entry.vedicDate {
                Text("🪷 \(vd)")
            } else {
                Text("🪷 Vedic Date")
            }
        default:
            Text("—")
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Previews
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private let sampleEntry = VedicEntry(
    date: .now, ghati: 42, pala: 37, ghatiFloat: 42.617, palaFloat: 37.0,
    praharName: "Aparanha", praharNumber: 3, praharIndex: 2, isDaytime: true,
    currentDosha: "Pitta", vedicDate: "Chaitra Shukla Panchami",
    samvatYear: "Vikram Samvat Raudri",
    nextMuhuratName: "Rahu Kala", nextMuhuratStart: "15:00", nextMuhuratType: "inauspicious",
    nadiDosha: "Pitta"
)

#Preview("Vedic Time · Circular", as: .accessoryCircular) {
    VedicTimeComplication()
} timeline: { sampleEntry }

#Preview("Vedic Time · Rectangular", as: .accessoryRectangular) {
    VedicTimeComplication()
} timeline: { sampleEntry }

#Preview("Pala Pulse · Circular", as: .accessoryCircular) {
    PalaPulseComplication()
} timeline: { sampleEntry }

#Preview("Pala Pulse · Rectangular", as: .accessoryRectangular) {
    PalaPulseComplication()
} timeline: { sampleEntry }

#if os(watchOS)
#Preview("Pala Pulse · Corner", as: .accessoryCorner) {
    PalaPulseComplication()
} timeline: { sampleEntry }
#endif

#Preview("Dual Time · Circular", as: .accessoryCircular) {
    DualTimeComplication()
} timeline: { sampleEntry }

#Preview("Dual Time · Rectangular", as: .accessoryRectangular) {
    DualTimeComplication()
} timeline: { sampleEntry }

#Preview("Dosha Clock · Circular", as: .accessoryCircular) {
    DoshaClockComplication()
} timeline: { sampleEntry }

#Preview("Dosha Clock · Rectangular", as: .accessoryRectangular) {
    DoshaClockComplication()
} timeline: { sampleEntry }

#if os(watchOS)
#Preview("Dosha Clock · Corner", as: .accessoryCorner) {
    DoshaClockComplication()
} timeline: { sampleEntry }
#endif

#Preview("Muhurat Alert · Circular", as: .accessoryCircular) {
    MuhuratAlertComplication()
} timeline: { sampleEntry }

#Preview("Muhurat Alert · Rectangular", as: .accessoryRectangular) {
    MuhuratAlertComplication()
} timeline: { sampleEntry }

#Preview("Tithi · Circular", as: .accessoryCircular) {
    TithiComplication()
} timeline: { sampleEntry }

#Preview("Tithi · Rectangular", as: .accessoryRectangular) {
    TithiComplication()
} timeline: { sampleEntry }
