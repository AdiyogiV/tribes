import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';

/// Monthly per-house current-state reading (from skyHouseReadings.houses[N]).
/// Generated inside the forecast narrate pass and refreshed with it.
class SkyHouseReading {
  final String? headline;
  final String? reading;
  final String? focus;
  final String? watch;

  const SkyHouseReading({
    this.headline,
    this.reading,
    this.focus,
    this.watch,
  });

  bool get hasContent =>
      (reading != null && reading!.isNotEmpty) ||
      (headline != null && headline!.isNotEmpty);
}

/// Data class for house information shown in the popup.
class HouseInfo {
  final int houseNumber;
  final String zodiacSign;
  final String signLord;
  final List<String> planets;

  /// Static natal interpretation (from houseInterpretations[N].interpretation).
  final String? interpretation;

  /// Current-state reading — "what's happening to this house RIGHT NOW".
  final SkyHouseReading? skyReading;

  /// End date of the current reading cycle (ISO string), if any.
  final String? cycleEndDate;

  const HouseInfo({
    required this.houseNumber,
    required this.zodiacSign,
    required this.signLord,
    required this.planets,
    this.interpretation,
    this.skyReading,
    this.cycleEndDate,
  });
}

/// Editorial house-reading dialog — matches the dashboard cards' skin:
/// stark surface, square corners, hairline edge, two-tone Georgia title,
/// spaced-caps eyebrows, a single accent. No traffic-light colours or icons.
class HouseDetailsDialog extends StatelessWidget {
  final HouseInfo info;
  final bool isDark;

  const HouseDetailsDialog({
    super.key,
    required this.info,
    required this.isDark,
  });

  static void show(BuildContext context, HouseInfo info, bool isDark) {
    showDialog(
      context: context,
      builder: (_) => HouseDetailsDialog(info: info, isDark: isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);
    final r = info.skyReading;
    final hasSky = r?.hasContent == true;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 660),
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(kDashboardCardRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          padding: kDashboardCardPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: two-tone Georgia title + close.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: EditorialCardHeader(
                      palette: palette,
                      leading: '${_ordinal(info.houseNumber)} ',
                      trailing: houseName(info.houseNumber),
                      subtitle: '${info.zodiacSign}   ${info.signLord}',
                      titleSize: 24,
                      subtitleSize: 12,
                    ),
                  ),
                  _closeButton(context, palette),
                ],
              ),
              const SizedBox(height: 22),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Who is transiting this house right now.
                      if (info.planets.isNotEmpty) ...[
                        _eyebrow(palette, 'HERE NOW'),
                        const SizedBox(height: 10),
                        _occupants(palette),
                        const SizedBox(height: 22),
                      ],

                      // The generated reading.
                      if (hasSky) ...[
                        if (r!.headline != null && r.headline!.isNotEmpty) ...[
                          Text(
                            r.headline!,
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontStyle: FontStyle.italic,
                              fontSize: 20,
                              height: 1.25,
                              letterSpacing: -0.5,
                              color: palette.fgMain,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (r.reading != null && r.reading!.isNotEmpty)
                          Text(
                            r.reading!,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.55,
                              color: palette.fgMain.withValues(alpha: 0.9),
                            ),
                          ),
                        if (r.focus != null && r.focus!.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _labeledBlock(palette, 'FOCUS', r.focus!),
                        ],
                        if (r.watch != null && r.watch!.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _labeledBlock(palette, 'WATCH', r.watch!),
                        ],
                      ],

                      // Natal foundation.
                      if (_natalText(hasSky) != null) ...[
                        const SizedBox(height: 22),
                        _hairline(palette),
                        const SizedBox(height: 22),
                        _eyebrow(palette, 'YOUR NATAL FOUNDATION'),
                        const SizedBox(height: 10),
                        Text(
                          _natalText(hasSky)!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.55,
                            color: palette.fgMuted,
                          ),
                        ),
                      ],

                      if (hasSky) ...[
                        const SizedBox(height: 22),
                        Text(
                          'Refreshes with your monthly forecast',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: palette.fgFaint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- pieces -------------------------------------------------------------

  Widget _eyebrow(DashboardCardPalette palette, String text) => Text(
        text,
        style: TextStyle(
          color: palette.fgMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.0,
        ),
      );

  Widget _occupants(DashboardCardPalette palette) => Wrap(
        spacing: 18,
        runSpacing: 8,
        children: info.planets
            .map((p) => Text(
                  '${planetGlyph(p)}  $p',
                  style: TextStyle(
                    fontSize: 14,
                    color: palette.fgMain,
                  ),
                ))
            .toList(),
      );

  Widget _labeledBlock(
          DashboardCardPalette palette, String label, String text) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow(palette, label),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: palette.fgMain.withValues(alpha: 0.9),
            ),
          ),
        ],
      );

  Widget _hairline(DashboardCardPalette palette) => Container(
        height: 1,
        color: palette.fgFaint.withValues(alpha: 0.5),
      );

  Widget _closeButton(BuildContext context, DashboardCardPalette palette) =>
      GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Icon(Icons.close, size: 20, color: palette.fgMuted),
        ),
      );

  String? _natalText(bool hasSky) =>
      info.interpretation ??
      (hasSky ? null : 'Sync your birth chart to unlock personalized insights.');

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }
}

/// Classical astrological glyph for a graha. Shared by the house dialog and
/// the Current-Sky gochara list so both render planets identically.
String planetGlyph(String name) {
  final l = name.toLowerCase();
  // Astrological glyphs built from Unicode code points (avoids literal
  // glyphs in source, which the repo's write filter strips).
  if (l.contains('sun')) return String.fromCharCode(0x2609);
  if (l.contains('moon')) return String.fromCharCode(0x263D);
  if (l.contains('mars')) return String.fromCharCode(0x2642);
  if (l.contains('mercury')) return String.fromCharCode(0x263F);
  if (l.contains('jupiter')) return String.fromCharCode(0x2643);
  if (l.contains('venus')) return String.fromCharCode(0x2640);
  if (l.contains('saturn')) return String.fromCharCode(0x2644);
  if (l.contains('rahu')) return String.fromCharCode(0x260A);
  if (l.contains('ketu')) return String.fromCharCode(0x260B);
  return String.fromCharCode(0x2022); // bullet
}

/// Gochara importance weight per graha — slow/karmic planets dominate the
/// ranking of "which transited house matters most right now" (classical
/// Gochara emphasis; the Moon ranks low since its transit is fleeting).
const Map<String, int> kGrahaGocharaWeight = {
  'saturn': 10,
  'rahu': 9,
  'ketu': 9,
  'jupiter': 8,
  'mars': 6,
  'sun': 5,
  'venus': 4,
  'mercury': 3,
  'moon': 2,
};

/// Sum of gochara weights for the planets occupying a house — the single score
/// that captures BOTH how many planets transit it and how heavy they are.
int gocharaScore(List<String> planets) => planets.fold(
      0,
      (sum, p) => sum + (kGrahaGocharaWeight[p.toLowerCase()] ?? 1),
    );

/// Public house name (e.g. 'Career & Status') for a house number, shared by
/// the dialog header and the gochara list rows.
String houseName(int h) {
  const names = {
    1: 'Self & Identity',
    2: 'Wealth & Values',
    3: 'Courage & Siblings',
    4: 'Home & Mother',
    5: 'Children & Creativity',
    6: 'Health & Service',
    7: 'Marriage & Partnership',
    8: 'Transformation',
    9: 'Fortune & Dharma',
    10: 'Career & Status',
    11: 'Gains & Aspirations',
    12: 'Spirituality & Liberation',
  };
  return names[h] ?? 'House $h';
}

/// Helpers for house calculations
class HouseSignifications {
  static String getSignForHouse(int houseNumber, int lagnaSignIndex) {
    const signs = [
      'Aries',
      'Taurus',
      'Gemini',
      'Cancer',
      'Leo',
      'Virgo',
      'Libra',
      'Scorpio',
      'Sagittarius',
      'Capricorn',
      'Aquarius',
      'Pisces'
    ];
    return signs[(lagnaSignIndex + houseNumber - 1) % 12];
  }

  static String getSignLord(String sign) {
    const lords = {
      'Aries': 'Mars',
      'Taurus': 'Venus',
      'Gemini': 'Mercury',
      'Cancer': 'Moon',
      'Leo': 'Sun',
      'Virgo': 'Mercury',
      'Libra': 'Venus',
      'Scorpio': 'Mars',
      'Sagittarius': 'Jupiter',
      'Capricorn': 'Saturn',
      'Aquarius': 'Saturn',
      'Pisces': 'Jupiter',
    };
    return lords[sign] ?? 'Unknown';
  }
}
