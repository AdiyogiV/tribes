import SwiftUI

/// Full-screen Vedic time in big bold white text.
/// Shows Ghati, Pala, Prahar name, and Panchang data from phone sync.
struct VedicTimeTextView: View {
    @EnvironmentObject private var cache: LocalCache

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let vt = VedicTimeCalculator.calculate(from: timeline.date)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                VStack(spacing: h * 0.03) {
                    Spacer()

                    // Ghati · Pala — hero numbers
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(vt.ghati)")
                            .font(.system(size: w * 0.22, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.31))
                        Text("g")
                            .font(.system(size: w * 0.10, weight: .bold, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.50))
                        Text("\(vt.pala)")
                            .font(.system(size: w * 0.22, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("p")
                            .font(.system(size: w * 0.10, weight: .bold, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.50))
                    }

                    // Prahar name + number
                    Text("\(vt.praharName) · \(vt.praharNumber)")
                        .font(.system(size: w * 0.09, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.60))

                    // Panchang — Vedic date from phone sync
                    if let vedicDate = cache.vedicDate {
                        Text(vedicDate)
                            .font(.system(size: w * 0.07, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.40))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, w * 0.08)
                    }

                    // Samvat year
                    if let samvat = cache.samvatYear {
                        Text(samvat)
                            .font(.system(size: w * 0.06, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.30))
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .frame(width: w, height: h)
            }
            .ignoresSafeArea(.all)
        }
    }
}

#Preview {
    let cache = LocalCache()
    cache.vedicDate = "Chaitra Krishna Shashthi"
    cache.samvatYear = "Vikram Samvat Raudri"
    return VedicTimeTextView().environmentObject(cache)
}
