import WidgetKit
import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - App Group + Shared Defaults
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// App Group identifier — must match the value configured in:
///   - Runner.entitlements
///   - AurogramWidget.entitlements
///   - Apple Developer Portal (App Group capability for both bundle IDs)
///
/// IMPORTANT: AppDelegate's platform channel writes panchang values to this
/// suite. If you change this string, also update `kAppGroup` in AppDelegate.
private let kAppGroup = "group.com.canay.dhaara.widget"

/// SharedDefaults instance backed by the App Group. Falls back to standard
/// defaults if the App Group isn't configured (e.g., during local development
/// before the capability has been added).
private var sharedDefaults: UserDefaults {
    UserDefaults(suiteName: kAppGroup) ?? .standard
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Timeline Entry
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct VedicDateEntry: TimelineEntry {
    let date: Date

    // Vedic time (computed natively every tick)
    let ghati: Int
    let pala: Int
    let praharName: String
    let isDaytime: Bool

    // Moon glyph (computed natively)
    let moonEmoji: String

    // Panchang (from App Group, written by Flutter)
    let lunarMonth: String?
    let paksha: String?
    let tithiName: String?
    let numericDate: String?

    var ghatiPala: String { "\(ghati)·\(String(format: "%02d", pala))" }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Timeline Provider
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct VedicDateProvider: TimelineProvider {

    func placeholder(in context: Context) -> VedicDateEntry {
        makeEntry(for: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (VedicDateEntry) -> Void) {
        completion(makeEntry(for: .now))
    }

    /// Build a timeline of entries one per minute for the next 60 minutes so
    /// Ghati·Pala stays roughly current without forcing iOS to wake the
    /// extension every Pala (24s). iOS reloads at the end of the timeline.
    func getTimeline(in context: Context, completion: @escaping (Timeline<VedicDateEntry>) -> Void) {
        var entries: [VedicDateEntry] = []
        let now = Date.now
        for minuteOffset in 0..<60 {
            let date = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now)!
            entries.append(makeEntry(for: date))
        }
        let refresh = Calendar.current.date(byAdding: .minute, value: 60, to: now)!
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func makeEntry(for date: Date) -> VedicDateEntry {
        let vt = VedicTimeCalculator.calculate(from: date)
        let defaults = sharedDefaults

        return VedicDateEntry(
            date: date,
            ghati: vt.ghati,
            pala: vt.pala,
            praharName: vt.praharName,
            isDaytime: vt.isDaytime,
            moonEmoji: VedicTimeCalculator.moonEmoji(for: date),
            lunarMonth: defaults.string(forKey: "widget_lunarMonth"),
            paksha: defaults.string(forKey: "widget_paksha"),
            tithiName: defaults.string(forKey: "widget_tithiName"),
            numericDate: defaults.string(forKey: "widget_vedicNumericDate")
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Theme
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Theme tokens that mirror the Android widget. SwiftUI resolves `Color` based
/// on the current `colorScheme`, so light/dark switching is automatic.
private enum WidgetTheme {
    /// Light: warm brown (#70543D). Dark: warm cream (#DEC4A8). Matches the
    /// Android `values/` vs `values-night/` color resources.
    static func textColor(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.871, green: 0.769, blue: 0.659) // #DEC4A8
            : Color(red: 0.439, green: 0.329, blue: 0.239) // #70543D
    }

    static func dividerColor(_ scheme: ColorScheme) -> Color {
        textColor(scheme).opacity(0.18)
    }

    /// Light: white. Dark: deep navy (#121A2A). Mirrors Android
    /// drawable/widget_background.xml vs drawable-night.
    static func backgroundColor(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.071, green: 0.102, blue: 0.165) // #121A2A
            : Color.white
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Widget Views
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Medium (systemMedium) layout — mirrors Android 4×2 widget exactly:
/// three columns separated by thin vertical dividers.
///
/// ┌──────────────────────┬──────┬─────────────┐
/// │ Lunar Month          │      │ Ghati·Pala  │
/// │ Paksha               │  🌓  │             │
/// │ Tithi                │      │ Prahar      │
/// │ 3/2/2/2083           │      │             │
/// └──────────────────────┴──────┴─────────────┘
struct VedicDateMediumView: View {
    let entry: VedicDateEntry
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 8) {
            // LEFT: Vedic date stack
            VStack(spacing: 2) {
                Text(entry.lunarMonth ?? "—")
                Text(entry.paksha ?? "—")
                Text(entry.tithiName ?? "—")
                Text(entry.numericDate ?? "")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(WidgetTheme.textColor(scheme))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            divider

            // CENTER: Moon emoji
            Text(entry.moonEmoji)
                .font(.system(size: 32))
                .frame(width: 44)

            divider

            // RIGHT: Vedic time stack
            VStack(spacing: 4) {
                Text(entry.ghatiPala)
                Text(entry.praharName)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(WidgetTheme.textColor(scheme))
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(WidgetTheme.dividerColor(scheme))
            .frame(width: 1, height: 70)
    }
}

/// Small (systemSmall) layout — compact 2×2 equivalent.
///
/// ┌──────────────┐
/// │ 🌓 Jyeshtha  │
/// │ Krishna      │
/// │ Dwitiya      │
/// │ G42·P15      │
/// └──────────────┘
struct VedicDateSmallView: View {
    let entry: VedicDateEntry
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(entry.moonEmoji).font(.system(size: 22))
                Text(entry.lunarMonth ?? "Vedic")
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
            }
            Text(entry.paksha ?? "—")
                .font(.system(size: 12, weight: .semibold))
            Text(entry.tithiName ?? "—")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("G\(entry.ghati)·P\(entry.pala)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .foregroundColor(WidgetTheme.textColor(scheme))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Lock Screen / StandBy (Accessory families, iOS 16+)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Tiny circular lock-screen complication: Ghati on top, Pala below.
///
/// ╭───╮
/// │42 │
/// │·15│
/// ╰───╯
struct VedicDateCircularView: View {
    let entry: VedicDateEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Text("\(entry.ghati)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                Text("·\(entry.pala)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .opacity(0.75)
            }
        }
        .widgetAccentable()
    }
}

/// Rectangular lock-screen complication with the full Vedic date and time.
///
/// ╭──────────────────────╮
/// │ 🌓 Jyeshtha Krishna  │
/// │ Dwitiya · G42·P15    │
/// │ Aparanha             │
/// ╰──────────────────────╯
struct VedicDateRectangularView: View {
    let entry: VedicDateEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(entry.moonEmoji)
                Text(headlineLine)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            Text(secondLine)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)
            Text(entry.praharName)
                .font(.system(size: 10))
                .opacity(0.7)
                .lineLimit(1)
        }
        .widgetAccentable()
    }

    private var headlineLine: String {
        [entry.lunarMonth, entry.paksha].compactMap { $0 }.joined(separator: " ")
    }

    private var secondLine: String {
        let tithi = entry.tithiName ?? ""
        return tithi.isEmpty ? entry.ghatiPala : "\(tithi) · \(entry.ghatiPala)"
    }
}

/// Single-line inline complication that appears above the lock-screen clock.
///
///   🌓 Krishna Dwitiya · G42·P15
struct VedicDateInlineView: View {
    let entry: VedicDateEntry

    var body: some View {
        let tithi = [entry.paksha, entry.tithiName].compactMap { $0 }.joined(separator: " ")
        let label = tithi.isEmpty ? "Vedic" : tithi
        Text("\(entry.moonEmoji) \(label) · G\(entry.ghati)·P\(entry.pala)")
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Adaptive entry view
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct VedicDateHomeView: View {
    let entry: VedicDateEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        switch family {
        case .systemSmall:
            VedicDateSmallView(entry: entry)
                .containerBackground(WidgetTheme.backgroundColor(scheme), for: .widget)
        case .systemMedium:
            VedicDateMediumView(entry: entry)
                .containerBackground(WidgetTheme.backgroundColor(scheme), for: .widget)
        case .accessoryCircular:
            VedicDateCircularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            VedicDateRectangularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        case .accessoryInline:
            VedicDateInlineView(entry: entry)
                .containerBackground(.clear, for: .widget)
        default:
            VedicDateMediumView(entry: entry)
                .containerBackground(WidgetTheme.backgroundColor(scheme), for: .widget)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Widget Configuration
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct VedicDateHomeWidget: Widget {
    let kind = "VedicDateHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VedicDateProvider()) { entry in
            VedicDateHomeView(entry: entry)
        }
        .configurationDisplayName("Vedic Date")
        .description("Today's Tithi, Paksha and Vedic time at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            // Lock screen / StandBy complications (iOS 16+)
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
        .contentMarginsDisabled()
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Preview
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#if DEBUG
struct VedicDateHomeWidget_Previews: PreviewProvider {
    static let sample = VedicDateEntry(
        date: .now,
        ghati: 42, pala: 15,
        praharName: "Aparanha", isDaytime: true,
        moonEmoji: "🌓",
        lunarMonth: "Jyeshtha", paksha: "Krishna",
        tithiName: "Dwitiya", numericDate: "A3/2/2/2083"
    )

    static var previews: some View {
        Group {
            VedicDateHomeView(entry: sample)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium · Light")
            VedicDateHomeView(entry: sample)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .preferredColorScheme(.dark)
                .previewDisplayName("Medium · Dark")
            VedicDateHomeView(entry: sample)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small · Light")
            VedicDateHomeView(entry: sample)
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Lock · Circular")
            VedicDateHomeView(entry: sample)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Lock · Rectangular")
            VedicDateHomeView(entry: sample)
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
                .previewDisplayName("Lock · Inline")
        }
    }
}
#endif
