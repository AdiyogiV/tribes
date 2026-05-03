import SwiftUI

/// Ayurveda Hub — compact grid of all deeper features.
/// Sits as the last page in the main vertical pager.
/// Two-column icon grid with section dividers. Tap any cell to drill in.
///
/// Sections:
///   Sharira (Body)    — Hridaya, Prana, Nidra, Dhatu, Sensors
///   Nadi (Pulse)      — Nadi, Prakriti, Vikriti, Agni, Remedy
///   Dinacharya (Day)  — Dinacharya, Ritu
///   Sadhana (Practice) — Pranayama, Abhyanga, Mantra, Vyayama
struct AyurvedaHubView: View {

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Title
                    Text("Ayurveda")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AuroTheme.goldAccent)
                        .padding(.top, 8)

                    // Body Signals
                    sectionHeader("Sharira", icon: "figure.mind.and.body")
                    hubGrid(items: bodyItems)

                    // Nadi & Dosha
                    sectionHeader("Nadi", icon: "waveform.path")
                    hubGrid(items: nadiItems)

                    // Daily & Seasons
                    sectionHeader("Kala", icon: "clock.arrow.circlepath")
                    hubGrid(items: timeItems)

                    // Practices
                    sectionHeader("Sadhana", icon: "sparkles")
                    hubGrid(items: practiceItems)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HubDestination.self) { dest in
                destinationView(dest)
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AuroTheme.textLight.opacity(0.35))
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AuroTheme.textLight.opacity(0.35))
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Grid

    private func hubGrid(items: [HubItem]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ], spacing: 8) {
            ForEach(items) { item in
                NavigationLink(value: item.destination) {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20))
                            .foregroundColor(item.color)
                        Text(item.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AuroTheme.textLight.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(item.color.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Items

    private var bodyItems: [HubItem] {
        [
            HubItem(label: "Heart", icon: "heart.fill", color: AuroTheme.pittaColor, destination: .hridaya),
            HubItem(label: "Breath", icon: "lungs.fill", color: AuroTheme.vataColor, destination: .prana),
            HubItem(label: "Sleep", icon: "moon.fill", color: AuroTheme.kaphaColor, destination: .nidra),
            HubItem(label: "Tissues", icon: "circle.hexagongrid.fill", color: AuroTheme.goldAccent, destination: .dhatu),
            HubItem(label: "Sensors", icon: "antenna.radiowaves.left.and.right", color: AuroTheme.textLight, destination: .sensors),
        ]
    }

    private var nadiItems: [HubItem] {
        [
            HubItem(label: "Pulse", icon: "waveform.path.ecg", color: AuroTheme.primaryColor, destination: .nadi),
            HubItem(label: "Prakriti", icon: "person.crop.circle", color: AuroTheme.kaphaColor, destination: .prakriti),
            HubItem(label: "Vikriti", icon: "arrow.triangle.swap", color: AuroTheme.pittaColor, destination: .vikriti),
            HubItem(label: "Agni", icon: "flame.fill", color: .orange, destination: .agni),
            HubItem(label: "Remedy", icon: "leaf.fill", color: .green, destination: .remedy),
        ]
    }

    private var timeItems: [HubItem] {
        [
            HubItem(label: "Routine", icon: "calendar.day.timeline.leading", color: AuroTheme.goldAccent, destination: .dinacharya),
            HubItem(label: "Seasons", icon: "cloud.sun.fill", color: AuroTheme.vataColor, destination: .ritu),
        ]
    }

    private var practiceItems: [HubItem] {
        [
            HubItem(label: "Breathe", icon: "wind", color: AuroTheme.vataColor, destination: .pranayama),
            HubItem(label: "Massage", icon: "hand.raised.fingers.spread.fill", color: AuroTheme.kaphaColor, destination: .abhyanga),
            HubItem(label: "Mantra", icon: "music.note", color: AuroTheme.primaryColor, destination: .mantra),
            HubItem(label: "Exercise", icon: "figure.run", color: AuroTheme.pittaColor, destination: .vyayama),
        ]
    }

    // MARK: - Navigation

    @ViewBuilder
    private func destinationView(_ dest: HubDestination) -> some View {
        switch dest {
        case .hridaya:    HridayaView()
        case .prana:      PranaView()
        case .nidra:      NidraView()
        case .dhatu:      DhatuView()
        case .sensors:    SensorsView()
        case .nadi:       NadiView()
        case .prakriti:   PrakritiView()
        case .vikriti:    VikritiView()
        case .agni:       AgniView()
        case .remedy:     RemedyView()
        case .dinacharya: DinacharyaView()
        case .ritu:       RituView()
        case .pranayama:  PranayamaView()
        case .abhyanga:   AbhyangaView()
        case .mantra:     MantraView()
        case .vyayama:    VyayamaView()
        }
    }
}

// MARK: - Models

enum HubDestination: Hashable {
    case hridaya, prana, nidra, dhatu, sensors
    case nadi, prakriti, vikriti, agni, remedy
    case dinacharya, ritu
    case pranayama, abhyanga, mantra, vyayama
}

struct HubItem: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let color: Color
    let destination: HubDestination
}

#Preview {
    AyurvedaHubView()
        .environmentObject(LocalCache())
        .environmentObject(HealthKitManager())
        .environmentObject(WatchSyncManager())
}
