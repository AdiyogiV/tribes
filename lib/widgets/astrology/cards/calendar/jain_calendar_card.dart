import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/astrology/cards/moon_phase_strip.dart';
import 'calendar_card_helpers.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Jain Calendar Card - Vira Nirvana Samvat
/// Uses the same lunar structure as Vedic calendar (tithi, paksha, masa)
class JainCalendarCard extends StatelessWidget {
  final int viraYear;
  final Map<String, dynamic>? samvat;
  final bool isDark;

  const JainCalendarCard({
    super.key,
    required this.viraYear,
    required this.samvat,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final lunarMonthName = samvat?['lunar_month_full_name']?.toString() ??
        samvat?['lunar_month_name']?.toString();
    final lunarMonthNumber = samvat?['lunar_month_number'];
    final tithiName =
        samvat?['name']?.toString() ?? samvat?['tithi']?.toString();
    final tithiNumber = extractTithiNumber(samvat);
    final paksha = extractPaksha(samvat);

    final pakshaNameEng = paksha == 'shukla'
        ? 'Waxing Moon'
        : paksha == 'krishna'
            ? 'Waning Moon'
            : null;
    final pakshaPrakrit = paksha == 'shukla'
        ? 'Sukka (Shukla)'
        : paksha == 'krishna'
            ? 'Kanha (Krishna)'
            : paksha;

    // Jain significant days (Parva = sacred/holy)
    String? parvaTithi;
    if (tithiNumber != null) {
      // Paryushana/Ashtanhika days, Purnima, Amavasya are significant
      if (tithiNumber == 15 && paksha == 'shukla') {
        parvaTithi = 'Purnima (Full Moon)';
      } else if (tithiNumber == 15 && paksha == 'krishna') {
        parvaTithi = 'Amavasya (New Moon)';
      } else if (tithiNumber == 8) {
        parvaTithi = 'Ashtami (8th - Fasting Day)';
      } else if (tithiNumber == 14) {
        parvaTithi = 'Chaturdashi (14th - Fasting Day)';
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Vira Nirvana Samvat',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          // Numerical date
          if (lunarMonthNumber != null && tithiNumber != null)
            Row(
              children: [
                Text(
                  'VNS $viraYear',
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
          // Parva Tithi (significant days)
          if (parvaTithi != null) ...[
            buildDateComponent('Parva (Sacred Day)', parvaTithi),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          // Month (Masa)
          if (lunarMonthName != null)
            buildDateComponent('Masa (Month)',
                '$lunarMonthName${lunarMonthNumber != null ? ' ($lunarMonthNumber)' : ''}'),
          // Tithi
          if (tithiName != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            buildDateComponent('Tithi (Lunar Day)',
                '$tithiName${tithiNumber != null ? ' ($tithiNumber)' : ''}'),
          ],
          // Paksha (Prakrit term)
          if (pakshaPrakrit != null && pakshaNameEng != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            buildDateComponent(
                'Pakkha (Fortnight)', '$pakshaPrakrit • $pakshaNameEng'),
          ],
          // Year
          const SizedBox(height: AppDimensions.spacingSm),
          buildDateComponent('Varsha (Year)', '$viraYear VNS'),
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
            'Lunisolar calendar • Epoch: Mahavira Nirvana (527 BCE)',
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
