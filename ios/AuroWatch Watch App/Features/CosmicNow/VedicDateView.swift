import SwiftUI

/// Full-screen Vedic calendar date page.
/// Shows the complete Hindu/Vedic date — Masa, Paksha, Tithi,
/// Samvat year, and the corresponding Gregorian date.
/// Mirrors the cosmic_date_time_card layout from the phone app.
struct VedicDateView: View {
    @EnvironmentObject private var cache: LocalCache

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            VStack(spacing: 0) {
                Spacer()

                if let vedicDate = cache.vedicDate {
                    vedicContent(vedicDate: vedicDate, w: w)
                } else {
                    waitingView
                }

                Spacer()
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea(.all)
    }

    // MARK: - Vedic Date Content

    @ViewBuilder
    private func vedicContent(vedicDate: String, w: CGFloat) -> some View {
        let fontSize = w * 0.11
        VStack(spacing: h(w, 0.025)) {
            // Moon phase glyph — large
            Text(moonGlyph())
                .font(.system(size: w * 0.28))

            // Vedic date — month, paksha, tithi on three equal rows
            let parts = splitVedicDate(vedicDate)
            VStack(spacing: 4) {
                Text(parts.masa)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(AuroTheme.goldAccent)

                Text(parts.paksha)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(AuroTheme.goldAccent)

                Text(parts.tithi)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(AuroTheme.goldAccent)
            }
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.7)

            // Samvat year
            if let samvat = cache.samvatYear {
                Text(samvat)
                    .font(.system(size: w * 0.065, weight: .semibold))
                    .foregroundColor(AuroTheme.textLight.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // Numeric Vedic date — bright and larger
            if let numeric = cache.vedicNumericDate, !numeric.isEmpty {
                Text(numeric)
                    .font(.system(size: w * 0.085, weight: .bold, design: .monospaced))
                    .foregroundColor(AuroTheme.goldAccent.opacity(0.7))
            }
        }
    }

    private var waitingView: some View {
        VStack(spacing: 10) {
            Text("🌙")
                .font(.system(size: 36))
            Text("Vedic Date")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AuroTheme.textLight)
            Text("Syncing from phone…")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AuroTheme.textLight.opacity(AuroTheme.textTertiary))
        }
    }

    // MARK: - Helpers

    /// Spacing helper based on screen width.
    private func h(_ w: CGFloat, _ fraction: CGFloat) -> CGFloat {
        w * fraction
    }

    /// Splits "Chaitra Krishna Saptami" → (masa: "Chaitra", paksha: "Krishna", tithi: "Saptami").
    /// First word is the masa (month), second is paksha, remainder is tithi.
    private func splitVedicDate(_ date: String) -> (masa: String, paksha: String, tithi: String) {
        let words = date.split(separator: " ")
        if words.count >= 3 {
            return (
                masa: String(words[0]),
                paksha: String(words[1]),
                tithi: words.dropFirst(2).joined(separator: " ")
            )
        } else if words.count == 2 {
            return (masa: String(words[0]), paksha: String(words[1]), tithi: "")
        }
        return (masa: date, paksha: "", tithi: "")
    }

    /// Moon phase glyph based on the Vedic date.
    /// Parses Paksha + rough tithi from the vedicDate string.
    private func moonGlyph() -> String {
        guard let date = cache.vedicDate?.lowercased() else { return "🌙" }

        let isKrishna = date.contains("krishna") || date.contains("krsna")
        let isShukla = date.contains("shukla") || date.contains("sukla")

        // Full/New moon special cases
        if date.contains("purnima") || date.contains("poornima") { return "🌕" }
        if date.contains("amavasya") || date.contains("amavasi") { return "🌑" }

        if isKrishna {
            // Waning: 🌖 → 🌗 → 🌘 → 🌑
            if date.contains("pratipada") || date.contains("dwitiya") || date.contains("tritiya") { return "🌖" }
            if date.contains("ashtami") || date.contains("navami") { return "🌗" }
            if date.contains("dwadashi") || date.contains("trayodashi") || date.contains("chaturdashi") { return "🌘" }
            return "🌗"
        } else if isShukla {
            // Waxing: 🌑 → 🌒 → 🌓 → 🌔 → 🌕
            if date.contains("pratipada") || date.contains("dwitiya") || date.contains("tritiya") { return "🌒" }
            if date.contains("ashtami") || date.contains("navami") { return "🌓" }
            if date.contains("dwadashi") || date.contains("trayodashi") || date.contains("chaturdashi") { return "🌔" }
            return "🌓"
        }

        return "🌙"
    }
}

#Preview {
    let cache = LocalCache()
    cache.vedicDate = "Chaitra Krishna Saptami"
    cache.samvatYear = "Vikram Samvat Raudri"
    cache.vedicNumericDate = "1/2/7/2083"
    return VedicDateView().environmentObject(cache)
}
