import SwiftUI

/// Hero screen — full-screen Vedic Clock.
/// Clock fills the screen edge-to-edge. Ghati/Pala overlaid top-left,
/// system time sits top-right (cannot be hidden on watchOS).
struct CosmicNowView: View {
    @EnvironmentObject private var cache: LocalCache
    @Environment(\.isLuminanceReduced) private var isAlwaysOn

    var body: some View {
        TimelineView(.periodic(from: .now, by: 16)) { timeline in
            let now = timeline.date
            let vt = VedicTimeCalculator.calculate(from: now)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                // Use the smaller dimension so the full circle fits on screen
                // with a small margin to keep ghati numbers (15, 30, 45) visible
                let clockSize = min(w, h) * 1.02

                ZStack {
                    // Clock — centered, fills screen
                    VedicClockView(date: now, isDark: true, size: clockSize)
                        .opacity(isAlwaysOn ? 0.6 : 1.0)
                        .position(x: w / 2, y: h / 2)
                }
                .frame(width: w, height: h)
            }
            .ignoresSafeArea(.all)
        }
        .ignoresSafeArea(.all)
    }
}

#Preview {
    let cache = LocalCache()
    cache.vedicDate = "Chaitra Krishna Shashthi"
    cache.samvatYear = "Vikram Samvat Raudri"
    return CosmicNowView().environmentObject(cache)
}
