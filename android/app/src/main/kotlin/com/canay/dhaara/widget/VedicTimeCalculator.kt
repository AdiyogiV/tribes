package com.canay.dhaara.widget

import java.util.Calendar
import java.util.TimeZone

/**
 * Pure Vedic time calculations — ported from Swift `VedicTimeCalculator.swift`
 * and Dart `vedic_time_utils.dart`.
 *
 * Vedic time units (sunrise to sunrise):
 *   1 Day   = 60 Ghati  = 3600 Pala
 *   1 Ghati = 24 minutes = 60 Pala
 *   1 Pala  = 24 seconds
 *
 * 8 Prahars (3-hour watches from sunrise):
 *   1 Purvanha  (6–9 AM)    5 Pradosha  (6–9 PM)
 *   2 Madhyanha (9–12 PM)   6 Nishitha  (9–12 AM)
 *   3 Aparanha  (12–3 PM)   7 Triyama   (12–3 AM)
 *   4 Sayanha   (3–6 PM)    8 Usha      (3–6 AM)
 *
 * KNOWN LIMITATION: Uses hardcoded 6 AM sunrise.
 */
object VedicTimeCalculator {

    private const val SUNRISE_HOUR = 6
    private const val SECONDS_PER_GHATI = 1440  // 24 min × 60 sec
    private const val SECONDS_PER_PALA = 24
    private const val MINUTES_PER_PRAHAR = 180  // 3 hours

    private val PRAHAR_NAMES = arrayOf(
        "Purvanha",   // early morning (sunrise–9 AM)
        "Madhyanha",  // midday (9 AM–12 PM)
        "Aparanha",   // afternoon (12–3 PM)
        "Sayanha",    // evening (3–6 PM)
        "Pradosha",   // early night (6–9 PM)
        "Nishitha",   // midnight (9 PM–12 AM)
        "Triyama",    // late night (12–3 AM)
        "Usha"        // dawn (3–6 AM)
    )

    private val VEDIC_WEEKDAYS = arrayOf(
        "Ravivar",    // Sunday — Sun
        "Somavar",    // Monday — Moon
        "Mangalvar",  // Tuesday — Mars
        "Budhvar",    // Wednesday — Mercury
        "Guruvar",    // Thursday — Jupiter
        "Shukravar",  // Friday — Venus
        "Shanivar"    // Saturday — Saturn
    )

    private val WEEKDAY_GLYPHS = arrayOf(
        "\u2609",  // ☉ Sunday
        "\u263E",  // ☾ Monday
        "\u2642",  // ♂ Tuesday
        "\u263F",  // ☿ Wednesday
        "\u2643",  // ♃ Thursday
        "\u2640",  // ♀ Friday
        "\u2644"   // ♄ Saturday
    )

    data class VedicTime(
        val ghati: Int,
        val pala: Int,
        val praharIndex: Int,
        val praharName: String,
        val praharNumber: Int,
        val isDaytime: Boolean,
        val ghatiFloat: Double,
        val palaFloat: Double
    )

    data class MoonPhase(
        val emoji: String,
        val label: String
    )

    fun calculate(cal: Calendar = Calendar.getInstance()): VedicTime {
        val h = cal.get(Calendar.HOUR_OF_DAY)
        val m = cal.get(Calendar.MINUTE)
        val s = cal.get(Calendar.SECOND)

        var secsFromSunrise = (h - SUNRISE_HOUR) * 3600 + m * 60 + s
        if (secsFromSunrise < 0) secsFromSunrise += 86400

        val ghati = secsFromSunrise / SECONDS_PER_GHATI
        val pala = (secsFromSunrise % SECONDS_PER_GHATI) / SECONDS_PER_PALA
        val minsFromSunrise = secsFromSunrise.toDouble() / 60.0
        val praharIndex = (minsFromSunrise / MINUTES_PER_PRAHAR).toInt() % 8

        return VedicTime(
            ghati = ghati,
            pala = pala,
            praharIndex = praharIndex,
            praharName = PRAHAR_NAMES[praharIndex],
            praharNumber = praharIndex + 1,
            isDaytime = praharIndex < 4,
            ghatiFloat = secsFromSunrise.toDouble() / SECONDS_PER_GHATI,
            palaFloat = (secsFromSunrise % SECONDS_PER_GHATI).toDouble() / SECONDS_PER_PALA
        )
    }

    /** Current dosha period for a given hour (Dinacharya cycle). */
    fun currentDosha(hour: Int): String {
        val h = if (hour < 2) hour + 24 else hour
        return when (h) {
            in 2..5 -> "Vata"
            in 6..9 -> "Kapha"
            in 10..13 -> "Pitta"
            in 14..17 -> "Vata"
            in 18..21 -> "Kapha"
            in 22..25 -> "Pitta"
            else -> "Pitta"
        }
    }

    /** Vedic weekday name (Vaar) for a Calendar day-of-week. */
    fun vedicWeekday(dayOfWeek: Int): String {
        // Calendar.SUNDAY=1, MONDAY=2, ..., SATURDAY=7
        return VEDIC_WEEKDAYS[(dayOfWeek - 1).coerceIn(0, 6)]
    }

    /** Planetary glyph for a Calendar day-of-week. */
    fun weekdayGlyph(dayOfWeek: Int): String {
        return WEEKDAY_GLYPHS[(dayOfWeek - 1).coerceIn(0, 6)]
    }

    /**
     * Approximate moon phase for a given date.
     *
     * Uses a reference new-moon epoch (Jan 6 2000 18:14 UTC) and the synodic
     * period (29.530588 days).  Accurate to within ~½ day.
     */
    fun moonPhase(cal: Calendar = Calendar.getInstance()): MoonPhase {
        // Reference new moon: Jan 6, 2000, 18:14 UTC
        val ref = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            set(2000, Calendar.JANUARY, 6, 18, 14, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val diffMs = cal.timeInMillis - ref.timeInMillis
        val days = diffMs.toDouble() / (86400.0 * 1000.0)
        val synodic = 29.530588
        var phase = (days / synodic) % 1.0
        if (phase < 0) phase += 1.0

        return when {
            phase < 0.0625 -> MoonPhase("\uD83C\uDF11", "New")
            phase < 0.1875 -> MoonPhase("\uD83C\uDF12", "Waxing crescent")
            phase < 0.3125 -> MoonPhase("\uD83C\uDF13", "First quarter")
            phase < 0.4375 -> MoonPhase("\uD83C\uDF14", "Waxing gibbous")
            phase < 0.5625 -> MoonPhase("\uD83C\uDF15", "Full")
            phase < 0.6875 -> MoonPhase("\uD83C\uDF16", "Waning gibbous")
            phase < 0.8125 -> MoonPhase("\uD83C\uDF17", "Last quarter")
            phase < 0.9375 -> MoonPhase("\uD83C\uDF18", "Waning crescent")
            else -> MoonPhase("\uD83C\uDF11", "New")
        }
    }
}
