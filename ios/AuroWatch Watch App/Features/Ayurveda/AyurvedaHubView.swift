import SwiftUI

/// Ayurveda Hub — last page in the main vertical pager.
///
/// Navigation approach: simple state-swap.
///   Hub state → scrollable list of features
///   Active state → back bar (VStack sibling) + feature view
///
/// Why not NavigationStack/sheets:
///   Child views have their own NavigationStack with .toolbar(.hidden),
///   which kills nested push back-buttons AND sheet dismiss controls.
///   A VStack sibling back-bar cannot be hidden by the child view.
struct AyurvedaHubView: View {
    @State private var activeView: HubDestination?

    var body: some View {
        if let active = activeView {
            activeContent(active)
        } else {
            hubContent
        }
    }

    // MARK: - Active View (feature + back bar)

    private func activeContent(_ dest: HubDestination) -> some View {
        VStack(spacing: 0) {
            // Back bar — sits ABOVE child view in VStack.
            // Child view cannot hide this because it's a sibling, not a toolbar.
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    activeView = nil
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("Ayurveda")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                }
                .foregroundColor(AuroTheme.goldAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.black)
            }
            .buttonStyle(.plain)

            // Feature view fills remaining space
            destinationView(dest)
                .frame(maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Hub List

    private var hubContent: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Ayurveda")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AuroTheme.goldAccent)
                    .padding(.top, 8)

                // Sharira (Body)
                sectionHeader("Sharira", icon: "figure.mind.and.body")
                hubRow(label: "Heart", icon: "heart.fill", color: AuroTheme.pittaColor, dest: .hridaya)
                hubRow(label: "Breath", icon: "lungs.fill", color: AuroTheme.vataColor, dest: .prana)
                hubRow(label: "Sleep", icon: "moon.fill", color: AuroTheme.kaphaColor, dest: .nidra)
                hubRow(label: "Tissues", icon: "circle.hexagongrid.fill", color: AuroTheme.goldAccent, dest: .dhatu)
                hubRow(label: "Sensors", icon: "antenna.radiowaves.left.and.right", color: AuroTheme.textLight, dest: .sensors)

                // Nadi (Pulse)
                sectionHeader("Nadi", icon: "waveform.path")
                hubRow(label: "Pulse", icon: "waveform.path.ecg", color: AuroTheme.primaryColor, dest: .nadi)
                hubRow(label: "Prakriti", icon: "person.crop.circle", color: AuroTheme.kaphaColor, dest: .prakriti)
                hubRow(label: "Vikriti", icon: "arrow.triangle.swap", color: AuroTheme.pittaColor, dest: .vikriti)
                hubRow(label: "Agni", icon: "flame.fill", color: .orange, dest: .agni)
                hubRow(label: "Remedy", icon: "leaf.fill", color: .green, dest: .remedy)

                // Kala (Time)
                sectionHeader("Kala", icon: "clock.arrow.circlepath")
                hubRow(label: "Routine", icon: "calendar.day.timeline.leading", color: AuroTheme.goldAccent, dest: .dinacharya)
                hubRow(label: "Seasons", icon: "cloud.sun.fill", color: AuroTheme.vataColor, dest: .ritu)

                // Sadhana (Practice)
                sectionHeader("Sadhana", icon: "sparkles")
                hubRow(label: "Breathe", icon: "wind", color: AuroTheme.vataColor, dest: .pranayama)
                hubRow(label: "Massage", icon: "hand.raised.fingers.spread.fill", color: AuroTheme.kaphaColor, dest: .abhyanga)
                hubRow(label: "Mantra", icon: "music.note", color: AuroTheme.primaryColor, dest: .mantra)
                hubRow(label: "Exercise", icon: "figure.run", color: AuroTheme.pittaColor, dest: .vyayama)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 16)
        }
        .toolbar(.hidden, for: .navigationBar)
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
        .padding(.top, 4)
    }

    // MARK: - Hub Row

    private func hubRow(label: String, icon: String, color: Color, dest: HubDestination) -> some View {
        Button {
            withAnimation(.easeIn(duration: 0.15)) {
                activeView = dest
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(color.opacity(0.12))
                    )

                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AuroTheme.textLight.opacity(0.85))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AuroTheme.textLight.opacity(0.2))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Destinations

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

// MARK: - Destination Enum

enum HubDestination: Identifiable, Hashable {
    case hridaya, prana, nidra, dhatu, sensors
    case nadi, prakriti, vikriti, agni, remedy
    case dinacharya, ritu
    case pranayama, abhyanga, mantra, vyayama

    var id: Self { self }
}

#Preview {
    AyurvedaHubView()
        .environmentObject(LocalCache())
        .environmentObject(HealthKitManager())
        .environmentObject(WatchSyncManager())
}
