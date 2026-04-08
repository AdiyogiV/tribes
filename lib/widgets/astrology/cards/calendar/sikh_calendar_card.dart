import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'calendar_card_helpers.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Sikh Calendar Card - Nanakshahi
/// Solar calendar with fixed month lengths
class SikhCalendarCard extends StatelessWidget {
  final Map<String, dynamic> nanakshahiDate;
  final bool isDark;

  const SikhCalendarCard({
    super.key,
    required this.nanakshahiDate,
    required this.isDark,
  });

  /// Punjabi weekday names (romanized)
  /// weekday: 1=Monday, 7=Sunday (Dart DateTime.weekday format)
  static const _punjabiWeekdays = {
    1: 'Somvaar (Monday)',
    2: 'Mangalvaar (Tuesday)',
    3: 'Budhvaar (Wednesday)',
    4: 'Veervaar (Thursday)',
    5: 'Shukarvaar (Friday)',
    6: 'Shanivaar (Saturday)',
    7: 'Aitvaar (Sunday)',
  };

  /// Punjabi seasons (Rutt) - 6 seasons, 2 months each
  /// Based on month number (1-12)
  static String _getPunjabiSeason(int month) {
    switch (month) {
      case 1: // Chet
      case 2: // Vaisakh
        return 'Basant (Spring)';
      case 3: // Jeth
      case 4: // Harh
        return 'Grishma (Summer)';
      case 5: // Sawan
      case 6: // Bhadon
        return 'Varsha (Monsoon)';
      case 7: // Assu
      case 8: // Kattak
        return 'Sharad (Autumn)';
      case 9: // Maghar
      case 10: // Poh
        return 'Hemant (Pre-winter)';
      case 11: // Magh
      case 12: // Phagun
        return 'Shishir (Winter)';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = nanakshahiDate['year'] as int;
    final month = nanakshahiDate['month'] as int;
    final monthName = nanakshahiDate['monthName'] as String;
    final day = nanakshahiDate['day'] as int;
    final weekday = nanakshahiDate['weekday'] as int?;

    final season = _getPunjabiSeason(month);
    final isSangrand = day == 1; // First day of month
    final weekdayName = weekday != null ? _punjabiWeekdays[weekday] : null;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nanakshahi Calendar',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          // Main date display
          Row(
            children: [
              Text(
                '$day $monthName $year',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                  height: 1.2,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMdSm),
              Text(
                'NS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  height: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          // Sangrand indicator
          if (isSangrand) ...[
            buildDateComponent(
                'Sangrand (New Month)', 'First day of $monthName'),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          // Season (Rutt)
          if (season.isNotEmpty) ...[
            buildDateComponent('Rutt (Season)', season),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          // Weekday (Vaar) in Punjabi
          if (weekdayName != null) ...[
            buildDateComponent('Vaar (Weekday)', weekdayName),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          // Day (Din)
          buildDateComponent('Din (Day)', 'Day $day'),
          const SizedBox(height: AppDimensions.spacingSm),
          // Month (Mahina)
          buildDateComponent('Mahina (Month)', '$monthName ($month of 12)'),
          const SizedBox(height: AppDimensions.spacingSm),
          // Year (Sal)
          buildDateComponent('Sal (Year)', '$year NS'),
          const SizedBox(height: AppDimensions.spacingMd),
          // Note about solar calendar
          Text(
            'Solar calendar • Epoch: Guru Nanak\'s birth (1469 CE)',
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
