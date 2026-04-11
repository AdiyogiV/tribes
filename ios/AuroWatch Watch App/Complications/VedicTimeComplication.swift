import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

/// Provides Vedic time data for watch face complications.
/// Updates every 15 minutes for smooth Ghati progression.
///
/// SETUP: This file belongs in a "Widget Extension" target.
///   1. File → New → Target → watchOS → Widget Extension
///   2. Name: "AuroWatch Complication"
///   3. Move this file to that target's compile sources
///   4. Also add VedicTimeCalculator.swift and AuroTheme.swift to the target
struct VedicTimeProvider: TimelineProvider {

    func placeholder(in context: Context) -> VedicTimeEntry {
        VedicTimeEntry(
            date: .now,
            ghati: 30,
            pala: 0,
            praharName: "Aparanha",
            praharNumber: 3,
            vedicDate: "Chaitra Shukla Panchami",
            currentDosha: "Pitta"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (VedicTimeEntry) -> Void) {
        completion(makeEntry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VedicTimeEntry>) -> Void) {
        var entries: [VedicTimeEntry] = []
        let now = Date.now

        // Generate entries for the next 8 hours at 15-minute intervals
        for minuteOffset in stride(from: 0, through: 8 * 60, by: 15) {
            let date = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now)!
            entries.append(makeEntry(for: date))
        }

        let refreshDate = Calendar.current.date(byAdding: .hour, value: 4, to: now)!
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }

    private func makeEntry(for date: Date) -> VedicTimeEntry {
        let vt = VedicTimeCalculator.calculate(from: date)
        let hour = Calendar.current.component(.hour, from: date)
        let dosha = VedicTimeCalculator.currentDosha(forHour: hour)

        // Read cached panchang from shared UserDefaults
        let defaults = UserDefaults.standard
        let vedicDate = defaults.string(forKey: "auro_vedicDate")

        return VedicTimeEntry(
            date: date,
            ghati: vt.ghati,
            pala: vt.pala,
            praharName: vt.praharName,
            praharNumber: vt.praharNumber,
            vedicDate: vedicDate,
            currentDosha: dosha
        )
    }
}

// MARK: - Timeline Entry

struct VedicTimeEntry: TimelineEntry {
    let date: Date
    let ghati: Int
    let pala: Int
    let praharName: String
    let praharNumber: Int
    let vedicDate: String?
    let currentDosha: String
}

// MARK: - Complication Views

/// Circular complication — Ghati number with Prahar progress ring.
struct VedicCircularView: View {
    let entry: VedicTimeEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Prahar progress ring
            let praharFraction = Double(entry.ghati % 8) / 7.5
            Circle()
                .trim(from: 0, to: praharFraction)
                .stroke(doshaColor, lineWidth: 3)
                .rotationEffect(.degrees(-90))
                .padding(2)

            VStack(spacing: -1) {
                Text("\(entry.ghati)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(doshaColor)
                Text("ghati")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var doshaColor: Color {
        switch entry.currentDosha {
        case "Vata":  return AuroTheme.vataColor
        case "Pitta": return AuroTheme.pittaColor
        case "Kapha": return AuroTheme.kaphaColor
        default:      return AuroTheme.primaryColor
        }
    }
}

/// Rectangular complication — Prahar, Ghati·Pala, dosha, and Vedic date.
struct VedicRectangularView: View {
    let entry: VedicTimeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(entry.praharName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(doshaColor)
                Spacer()
                Text(entry.currentDosha)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(doshaColor.opacity(0.7))
            }

            Text("Ghati \(entry.ghati) · Pala \(entry.pala)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary.opacity(0.8))

            if let vedicDate = entry.vedicDate {
                Text(vedicDate)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var doshaColor: Color {
        switch entry.currentDosha {
        case "Vata":  return AuroTheme.vataColor
        case "Pitta": return AuroTheme.pittaColor
        case "Kapha": return AuroTheme.kaphaColor
        default:      return AuroTheme.primaryColor
        }
    }
}

/// Inline complication — compact single-line text.
struct VedicInlineView: View {
    let entry: VedicTimeEntry

    var body: some View {
        Text("☉ \(entry.praharName) · G\(entry.ghati)")
            .font(.system(size: 12, weight: .medium))
    }
}

/// Corner complication — large Ghati with label.
struct VedicCornerView: View {
    let entry: VedicTimeEntry

    var body: some View {
        Text("\(entry.ghati)")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(doshaColor)
            .widgetLabel {
                Text("Ghati")
            }
    }

    private var doshaColor: Color {
        switch entry.currentDosha {
        case "Vata":  return AuroTheme.vataColor
        case "Pitta": return AuroTheme.pittaColor
        case "Kapha": return AuroTheme.kaphaColor
        default:      return AuroTheme.primaryColor
        }
    }
}

// MARK: - Widget Definition

/// Vedic Time complication widget.
///
/// Shows current Ghati, Prahar, and Ayurvedic dosha period on the watch face.
/// Supports circular, rectangular, inline, and corner families.
struct VedicTimeComplication: Widget {
    let kind: String = "VedicTimeComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VedicTimeProvider()) { entry in
            if #available(watchOS 10.0, *) {
                complicationView(for: entry)
                    .containerBackground(.clear, for: .widget)
            } else {
                complicationView(for: entry)
            }
        }
        .configurationDisplayName("Vedic Time")
        .description("Current Ghati, Prahar, and dosha period.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }

    @ViewBuilder
    private func complicationView(for entry: VedicTimeEntry) -> some View {
        // WidgetKit picks the right view based on the family
        // We use a single view that adapts via @Environment(\.widgetFamily)
        VedicAdaptiveView(entry: entry)
    }
}

/// Adapts to widget family automatically.
struct VedicAdaptiveView: View {
    let entry: VedicTimeEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            VedicCircularView(entry: entry)
        case .accessoryRectangular:
            VedicRectangularView(entry: entry)
        case .accessoryInline:
            VedicInlineView(entry: entry)
        case .accessoryCorner:
            VedicCornerView(entry: entry)
        default:
            VedicCircularView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle Entry Point
// Uncomment when this file is in its own Widget Extension target:
//
// @main
// struct AuroWatchWidgets: WidgetBundle {
//     var body: some Widget {
//         VedicTimeComplication()
//     }
// }
