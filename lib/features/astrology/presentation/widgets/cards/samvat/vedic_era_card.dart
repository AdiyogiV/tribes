import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/moon_phase_strip.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Generic Vedic Era Card for epoch-based calendars
/// Used for Mahabharata Samvat, Kali Yuga, etc.
class VedicEraCard extends StatelessWidget {
  final String label;
  final int year;
  final String yearSuffix;
  final int epochYear;
  final String epochNote;
  final Map<String, dynamic>? samvat;
  final bool isDark;
  final String? nakshatra;
  final String? yoga;
  final String? karana;
  final int? tithiNumber;
  final String? paksha;

  const VedicEraCard({
    super.key,
    required this.label,
    required this.year,
    required this.yearSuffix,
    required this.epochYear,
    required this.epochNote,
    required this.samvat,
    required this.isDark,
    this.nakshatra,
    this.yoga,
    this.karana,
    this.tithiNumber,
    this.paksha,
  });

  @override
  Widget build(BuildContext context) {
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
                  yearSuffix,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppDimensions.spacingLg),

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
            epochNote,
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
