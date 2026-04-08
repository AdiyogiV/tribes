import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/astrology/cards/moon_phase_strip.dart';
import 'calendar_card_helpers.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Buddhist Calendar Card - Buddhist Era (BE)
/// Uses the same lunar structure as Vedic calendar
class BuddhistCalendarCard extends StatelessWidget {
  final int buddhistYear;
  final Map<String, dynamic>? samvat;
  final bool isDark;

  const BuddhistCalendarCard({
    super.key,
    required this.buddhistYear,
    required this.samvat,
    required this.isDark,
  });

  /// Pali/Buddhist month names (romanized)
  static const _paliMonthNames = {
    'chaitra': 'Citta',
    'vaisakha': 'Vesakha',
    'jyeshtha': 'Jettha',
    'ashadha': 'Asalha',
    'shravana': 'Savana',
    'bhadrapada': 'Potthapad',
    'ashwin': 'Assayuja',
    'kartik': 'Kattika',
    'margashirsha': 'Maggasira',
    'pausha': 'Phussa',
    'magha': 'Magha',
    'phalguna': 'Phagguna',
  };

  @override
  Widget build(BuildContext context) {
    final lunarMonthName = samvat?['lunar_month_full_name']?.toString() ??
        samvat?['lunar_month_name']?.toString();
    final lunarMonthNumber = samvat?['lunar_month_number'];
    final tithiName =
        samvat?['name']?.toString() ?? samvat?['tithi']?.toString();
    final tithiNumber = extractTithiNumber(samvat);
    final paksha = extractPaksha(samvat);

    // Convert to Pali month name if possible
    final paliMonth = lunarMonthName != null
        ? _paliMonthNames[lunarMonthName.toLowerCase()] ?? lunarMonthName
        : null;

    // Determine Uposatha (observance days)
    // In Buddhism: New Moon (Amavasya, tithi 30/1), Full Moon (Purnima, tithi 15)
    // Quarter days: tithi 8 (half moon)
    String? uposatha;
    if (tithiNumber != null) {
      if (tithiNumber == 15 && paksha == 'shukla') {
        uposatha = 'Poya (Purnima) - Full Moon Uposatha';
      } else if (tithiNumber == 15 && paksha == 'krishna') {
        uposatha = 'Amavasya - New Moon Uposatha';
      } else if (tithiNumber == 8) {
        uposatha = 'Atthami - Half Moon Uposatha';
      }
    }

    final pakshaNamePali = paksha == 'shukla'
        ? 'Sukkapakkha (Waxing)'
        : paksha == 'krishna'
            ? 'Kalapakkha (Waning)'
            : null;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Buddhist Era',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          // Main year display
          Row(
            children: [
              Text(
                'BE $buddhistYear',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                  height: 1.2,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMdSm),
              if (tithiNumber != null && lunarMonthNumber != null)
                Flexible(
                  child: Text(
                    '• $lunarMonthNumber/$tithiNumber',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          // Uposatha (significant observance days)
          if (uposatha != null) ...[
            buildDateComponent('Uposatha (Observance)', uposatha),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          // Month (Pali name)
          if (paliMonth != null) buildDateComponent('Masa (Month)', paliMonth),
          // Day (Tithi)
          if (tithiName != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            buildDateComponent('Tithi (Lunar Day)',
                '$tithiName${tithiNumber != null ? ' ($tithiNumber)' : ''}'),
          ],
          // Phase (Paksha in Pali)
          if (pakshaNamePali != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            buildDateComponent('Pakkha (Fortnight)', pakshaNamePali),
          ],
          // Year
          const SizedBox(height: AppDimensions.spacingSm),
          buildDateComponent('Vassa (Year)', 'BE $buddhistYear'),
          const SizedBox(height: AppDimensions.spacingMd),
          // Moon phase visualization at bottom
          if (tithiNumber != null && paksha != null)
            MoonPhaseStrip(
              tithiNumber: tithiNumber,
              paksha: paksha,
              isDark: isDark,
            ),
          if (tithiNumber != null && paksha != null) const SizedBox(height: AppDimensions.spacingMd),
          // Note
          Text(
            'Lunisolar calendar • Epoch: Parinibbana (543 BCE)',
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
}
