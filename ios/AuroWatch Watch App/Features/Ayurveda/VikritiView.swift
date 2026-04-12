import SwiftUI

/// Vikriti — Current Balance page. Shows dosha state vs Prakriti.
/// Three dosha bars with deviation arrows. Tap for detail.
struct VikritiView: View {
    @EnvironmentObject private var cache: LocalCache
    @State private var showDetail = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let w = max(geo.size.width, 1)
                let h = max(geo.size.height, 1)

                ZStack {
                    if cache.prakritiVata > 0 || cache.nadiDominantDosha != nil {
                        balanceContent(w: w, h: h)
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
                VikritiDetailView(cache: cache)
            }
        }
    }

    @ViewBuilder
    private func balanceContent(w: CGFloat, h: CGFloat) -> some View {
        let vikriti = currentVikriti()

        VStack(spacing: 0) {
            Spacer()

            Text("Balance")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                .textCase(.uppercase)
                .tracking(1.5)

            Spacer().frame(height: 10)

            doshaMeter("Vata", icon: "wind", value: vikriti.vata,
                       prakriti: Double(cache.prakritiVata),
                       color: AuroTheme.vataColor, w: w)
                .padding(.bottom, 8)

            doshaMeter("Pitta", icon: "flame.fill", value: vikriti.pitta,
                       prakriti: Double(cache.prakritiPitta),
                       color: AuroTheme.pittaColor, w: w)
                .padding(.bottom, 8)

            doshaMeter("Kapha", icon: "drop.fill", value: vikriti.kapha,
                       prakriti: Double(cache.prakritiKapha),
                       color: AuroTheme.kaphaColor, w: w)

            Spacer().frame(height: 8)

            HStack(spacing: 4) {
                Circle()
                    .fill(AuroTheme.doshaColor(vikriti.dominant))
                    .frame(width: 6, height: 6)
                Text("\(vikriti.dominant) dominant")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AuroTheme.doshaColor(vikriti.dominant))

                if vikriti.isAligned {
                    Text("· Aligned")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AuroTheme.kaphaColor.opacity(0.6))
                } else {
                    Text("· Shifted")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AuroTheme.pittaColor.opacity(0.6))
                }
            }

            Spacer().frame(height: 6)

            if let agni = cache.agniType {
                HStack(spacing: 3) {
                    Text("🔥").font(.system(size: 10))
                    Text(agni)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AuroTheme.textLight.opacity(0.45))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private func doshaMeter(_ name: String, icon: String, value: Double, prakriti: Double, color: Color, w: CGFloat) -> some View {
        let barWidth = max(w - 48, 1)
        let maxVal = 100.0

        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 18)
                Text(name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AuroTheme.textLight)
                Spacer()
                Text("\(Int(value))")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(color)

                if prakriti > 0 {
                    let diff = value - prakriti
                    if abs(diff) > 5 {
                        Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(diff > 0 ? AuroTheme.pittaColor : AuroTheme.vataColor)
                    } else {
                        Image(systemName: "equal")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AuroTheme.kaphaColor.opacity(0.5))
                    }
                }
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: barWidth, height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.7))
                    .frame(width: barWidth * min(1, value / maxVal), height: 8)
                if prakriti > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 2, height: 14)
                        .offset(x: barWidth * min(1, prakriti / maxVal) - 1)
                }
            }
        }
    }

    private var waitingView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(AuroTheme.vataColor).frame(width: 10, height: 10)
                Circle().fill(AuroTheme.pittaColor).frame(width: 10, height: 10)
                Circle().fill(AuroTheme.kaphaColor).frame(width: 10, height: 10)
            }
            Text("Vikriti")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AuroTheme.textLight)
            Text("Complete your Prakriti\nquiz and wear your watch")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Compute Current Vikriti

    private func currentVikriti() -> VikritiState {
        var vata = 33.0, pitta = 33.0, kapha = 34.0
        var dominant = "Balanced"
        let hasPrakriti = cache.prakritiVata > 0

        if hasPrakriti {
            vata = Double(cache.prakritiVata)
            pitta = Double(cache.prakritiPitta)
            kapha = Double(cache.prakritiKapha)
        }

        if let hrv = cache.latestHRV {
            if hrv > 60 { vata += 8; pitta -= 3; kapha -= 5 }
            else if hrv < 25 { kapha += 6; vata -= 3; pitta -= 3 }
        }
        if let rhr = cache.latestRestingHR {
            if rhr > 75 { pitta += 5; vata += 3; kapha -= 5 }
            else if rhr < 55 { kapha += 5; pitta -= 3 }
        }
        if let temp = cache.wristTempDeviation {
            if temp > 0.3 { pitta += 6; vata -= 2 }
            else if temp < -0.3 { vata += 5; kapha += 2; pitta -= 4 }
        }
        if let hrs = cache.sleepHours {
            if hrs < 6 { vata += 6; pitta += 3; kapha -= 5 }
            else if hrs > 9 { kapha += 8; vata -= 4; pitta -= 2 }
        }
        if let resp = cache.respiratoryRate {
            if resp > 18 { vata += 4; kapha -= 2 }
            else if resp < 12 { kapha += 3 }
        }
        if let spo2 = cache.spO2 {
            let pct = spo2 > 1 ? spo2 : spo2 * 100
            if pct < 94 { kapha += 4; vata += 2 }
        }
        if let steps = cache.todaySteps {
            if steps < 2000 { kapha += 5; vata -= 2 }
            else if steps > 15000 { vata += 4; kapha -= 3 }
        }

        let total = max(1, vata + pitta + kapha)
        vata = (vata / total) * 100
        pitta = (pitta / total) * 100
        kapha = (kapha / total) * 100

        if vata >= pitta && vata >= kapha { dominant = "Vata" }
        else if pitta >= vata && pitta >= kapha { dominant = "Pitta" }
        else { dominant = "Kapha" }

        let prakritiDominant: String
        if cache.prakritiVata >= cache.prakritiPitta && cache.prakritiVata >= cache.prakritiKapha {
            prakritiDominant = "Vata"
        } else if cache.prakritiPitta >= cache.prakritiVata && cache.prakritiPitta >= cache.prakritiKapha {
            prakritiDominant = "Pitta"
        } else {
            prakritiDominant = "Kapha"
        }

        let aligned = hasPrakriti ? (dominant == prakritiDominant) : true
        return VikritiState(vata: vata, pitta: pitta, kapha: kapha, dominant: dominant, isAligned: aligned)
    }
}

struct VikritiState {
    let vata: Double
    let pitta: Double
    let kapha: Double
    let dominant: String
    let isAligned: Bool
}

// MARK: - Vikriti Detail (paged drill-down)

struct VikritiDetailView: View {
    let cache: LocalCache
    @Environment(\.dismiss) private var dismiss
    @State private var detailPage = 0

    var body: some View {
        TabView(selection: $detailPage) {
            signalsPage.tag(0)
            conceptPage.tag(1)
        }
        .tabViewStyle(.verticalPage)
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var signalsPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 4) {
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text("Balance")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(AuroTheme.goldAccent.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)

                Text("SIGNALS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AuroTheme.textLight.opacity(0.3))
                    .tracking(1.0)
                    .padding(.top, 4)

                Spacer(minLength: 2)

                VStack(spacing: 4) {
                    if let hrv = cache.latestHRV {
                        signalRow("HRV \(Int(hrv))ms",
                                  effect: hrv > 60 ? "↑ Vata" : hrv < 25 ? "↑ Kapha" : "Balanced",
                                  color: hrv > 60 ? AuroTheme.vataColor : hrv < 25 ? AuroTheme.kaphaColor : AuroTheme.kaphaColor)
                    }
                    if let hrs = cache.sleepHours {
                        signalRow("Sleep \(String(format: "%.1f", hrs))h",
                                  effect: hrs < 6 ? "↑ Vata" : hrs > 9 ? "↑ Kapha" : "Balanced",
                                  color: hrs < 6 ? AuroTheme.vataColor : hrs > 9 ? AuroTheme.kaphaColor : AuroTheme.kaphaColor)
                    }
                    if let temp = cache.wristTempDeviation {
                        let sign = temp >= 0 ? "+" : ""
                        signalRow("Temp \(sign)\(String(format: "%.1f", temp))°",
                                  effect: temp > 0.3 ? "↑ Pitta" : temp < -0.3 ? "↑ Vata" : "Stable",
                                  color: temp > 0.3 ? AuroTheme.pittaColor : temp < -0.3 ? AuroTheme.vataColor : AuroTheme.kaphaColor)
                    }
                    if let resp = cache.respiratoryRate {
                        signalRow("Breath \(Int(resp))/m",
                                  effect: resp > 18 ? "↑ Vata" : "Calm",
                                  color: resp > 18 ? AuroTheme.vataColor : AuroTheme.kaphaColor)
                    }
                    if let steps = cache.todaySteps {
                        signalRow("Steps \(steps)",
                                  effect: steps < 2000 ? "↑ Kapha" : steps > 15000 ? "↑ Vata" : "Active",
                                  color: steps < 2000 ? AuroTheme.kaphaColor : steps > 15000 ? AuroTheme.vataColor : AuroTheme.kaphaColor)
                    }
                }
                .padding(.horizontal, 10)

                Spacer(minLength: 2)
            }
            .frame(width: w, height: h)
        }
    }

    private var conceptPage: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 8) {
                Spacer()

                Text("Prakriti vs Vikriti")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AuroTheme.goldAccent.opacity(0.8))

                Text("Prakriti is your birth constitution (fixed).\nVikriti is your current state (changing).\n\nWhen aligned, you are in balance.\nDeviations show which dosha needs attention.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(AuroTheme.textLight.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)

                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 2, height: 10)
                    Text("= Prakriti baseline")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AuroTheme.textLight.opacity(0.3))
                }
                .padding(.top, 4)

                Spacer()
            }
            .frame(width: w, height: h)
        }
    }

    @ViewBuilder
    private func signalRow(_ label: String, effect: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AuroTheme.textLight.opacity(0.7))
            Spacer()
            Text(effect)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
        }
        .frame(height: 22)
    }
}

#Preview {
    VikritiView()
        .environmentObject(LocalCache())
}
