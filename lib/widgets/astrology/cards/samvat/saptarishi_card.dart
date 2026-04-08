import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/astrology/cards/moon_phase_strip.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Saptarishi Calendar Card
/// Based on movement of Ursa Major (Seven Sages) through 27 Nakshatras
class SaptarishiCard extends StatelessWidget {
  final String label;
  final int year;
  final int epoch;
  final String epochName;
  final Map<String, dynamic>? samvat;
  final bool isDark;
  final String? nakshatra;
  final String? yoga;
  final String? karana;
  final int? tithiNumber;
  final String? paksha;

  const SaptarishiCard({
    super.key,
    required this.label,
    required this.year,
    required this.epoch,
    required this.epochName,
    required this.samvat,
    required this.isDark,
    this.nakshatra,
    this.yoga,
    this.karana,
    this.tithiNumber,
    this.paksha,
  });

  /// The 27 Nakshatras in order
  static const _nakshatras = [
    'Ashwini',
    'Bharani',
    'Krittika',
    'Rohini',
    'Mrigashira',
    'Ardra',
    'Punarvasu',
    'Pushya',
    'Ashlesha',
    'Magha',
    'Purva Phalguni',
    'Uttara Phalguni',
    'Hasta',
    'Chitra',
    'Swati',
    'Vishakha',
    'Anuradha',
    'Jyeshtha',
    'Mula',
    'Purva Ashadha',
    'Uttara Ashadha',
    'Shravana',
    'Dhanishta',
    'Shatabhisha',
    'Purva Bhadrapada',
    'Uttara Bhadrapada',
    'Revati',
  ];

  /// Calculate which nakshatra the Saptarishis are residing in
  /// Using traditional 100-year per nakshatra system
  Map<String, dynamic> _calculateNakshatraPosition() {
    // Cycle is 2700 years (27 nakshatras x 100 years each)
    const cycleLength = 2700;
    const yearsPerNakshatra = 100;

    // Starting nakshatra depends on epoch
    // 3076 BCE: Started in Magha (index 9)
    // 6676 BCE: Started in Krittika (index 2)
    final startNakshatraIndex = epoch == 3076 ? 9 : 2; // Magha or Krittika

    // Calculate position in cycle
    final yearsElapsed = year;
    final yearsIntoCycle = yearsElapsed % cycleLength;
    final nakshatrasCompleted = yearsIntoCycle ~/ yearsPerNakshatra;
    final yearsInCurrentNakshatra = yearsIntoCycle % yearsPerNakshatra;

    // Current nakshatra index (wrapping around)
    final currentNakshatraIndex =
        (startNakshatraIndex + nakshatrasCompleted) % 27;
    final currentNakshatra = _nakshatras[currentNakshatraIndex];

    // Cycle number (1-indexed)
    final cycleNumber = (yearsElapsed ~/ cycleLength) + 1;

    return {
      'nakshatra': currentNakshatra,
      'nakshatraIndex': currentNakshatraIndex + 1, // 1-indexed for display
      'yearsInNakshatra': yearsInCurrentNakshatra,
      'yearsRemaining': yearsPerNakshatra - yearsInCurrentNakshatra,
      'cycleNumber': cycleNumber,
      'yearsIntoCycle': yearsIntoCycle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final position = _calculateNakshatraPosition();
    final saptarishiNakshatra = position['nakshatra'] as String;
    final nakshatraIndex = position['nakshatraIndex'] as int;
    final yearsInNakshatra = position['yearsInNakshatra'] as int;
    final cycleNumber = position['cycleNumber'] as int;

    // Extract month/tithi/paksha from samvat (same keys as SamvatCard)
    final monthName = samvat?['lunar_month_full_name']?.toString() ??
        samvat?['lunar_month_name']?.toString();
    final tithiName =
        samvat?['name']?.toString() ?? samvat?['tithi']?.toString();
    final pakshaName =
        samvat?['paksha']?.toString() ?? samvat?['tithiPaksha']?.toString();
    final lunarMonthNumber = samvat?['lunar_month_number'];

    // Derive paksha number (1=Shukla, 2=Krishna)
    int? pakshaNumber;
    if (pakshaName != null) {
      final pakshaLower = pakshaName.toLowerCase();
      if (pakshaLower.contains('shukla') || pakshaLower.contains('sukla')) {
        pakshaNumber = 1;
      } else if (pakshaLower.contains('krishna') ||
          pakshaLower.contains('krsna')) {
        pakshaNumber = 2;
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          // Numeric date display
          if (lunarMonthNumber != null && tithiNumber != null)
            Row(
              children: [
                Text(
                  '$lunarMonthNumber${pakshaNumber != null ? '/$pakshaNumber' : ''}/$tithiNumber/$year',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                    height: 1.2,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMdSm),
                Flexible(
                  child: Text(
                    pakshaNumber != null
                        ? '(Masa/Paksha/Tithi/Varsha)'
                        : '(Masa/Tithi/Varsha)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Text(
                  '$year',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                    height: 1.2,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  'SS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppDimensions.spacingLg),

          // === SAPTARISHI CYCLE INFO ===
          _buildComponent(
            'Rishi Nakshatra',
            '$saptarishiNakshatra (#$nakshatraIndex of 27)',
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          _buildComponent(
            'Years in Nakshatra',
            '$yearsInNakshatra of 100 years',
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          _buildComponent(
            'Chakra (Cycle)',
            'Cycle $cycleNumber (2700 years each)',
          ),
          const SizedBox(height: AppDimensions.spacingSm),

          // === BIRTH DATE INFO (Lunisolar - shared with Vedic) ===
          if (monthName != null) ...[
            _buildComponent('Masa (Month)', monthName.toString()),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          if (pakshaName != null) ...[
            _buildComponent(
              'Paksha (Fortnight)',
              pakshaName.toString().toLowerCase().contains('shukla') ||
                      pakshaName.toString().toLowerCase().contains('sukla')
                  ? 'Shukla (Bright/Waxing)'
                  : 'Krishna (Dark/Waning)',
            ),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          if (tithiName != null) ...[
            _buildComponent('Tithi (Lunar Day)', tithiName.toString()),
            const SizedBox(height: AppDimensions.spacingSm),
          ],

          // === PANCHANG ELEMENTS ===
          if (nakshatra != null && nakshatra!.isNotEmpty) ...[
            _buildComponent('Nakshatra (Star)', nakshatra!),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          if (yoga != null && yoga!.isNotEmpty) ...[
            _buildComponent('Yoga (Combination)', yoga!),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          if (karana != null && karana!.isNotEmpty) ...[
            _buildComponent('Karana (Half-Day)', karana!),
            const SizedBox(height: AppDimensions.spacingSm),
          ],

          // Moon phase visualization
          if (tithiNumber != null && paksha != null) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            MoonPhaseStrip(
              tithiNumber: tithiNumber!,
              paksha: paksha!,
              isDark: isDark,
            ),
          ],
          const SizedBox(height: AppDimensions.spacingMd),
          // Epoch note
          Text(
            'Saptarishi cycle \u2022 Epoch: $epochName ($epoch BCE)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponent(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
              height: 1.3,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
