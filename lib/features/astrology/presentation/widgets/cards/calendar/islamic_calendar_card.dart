import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/moon_phase_strip.dart';
import 'package:hijri_date/hijri_date.dart';
import 'package:hijri_date/moon_phases.dart' as hijri_moon;
import 'calendar_card_helpers.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Islamic Calendar Card - Hijri
/// Lunar calendar based on moon sighting
class IslamicCalendarCard extends StatelessWidget {
  final HijriDate hijriDate;
  final bool isDark;

  const IslamicCalendarCard({
    super.key,
    required this.hijriDate,
    required this.isDark,
  });

  /// Romanized Arabic moon phase names
  static const _arabicPhaseNames = {
    hijri_moon.MoonPhase.newMoon: 'Muhaq',
    hijri_moon.MoonPhase.waxingCrescent: 'Hilal Mutazayid',
    hijri_moon.MoonPhase.firstQuarter: "Tarbi' Awwal",
    hijri_moon.MoonPhase.waxingGibbous: 'Ahdab Mutazayid',
    hijri_moon.MoonPhase.fullMoon: 'Badr',
    hijri_moon.MoonPhase.waningGibbous: 'Ahdab Mutanaqis',
    hijri_moon.MoonPhase.lastQuarter: "Tarbi' Thani",
    hijri_moon.MoonPhase.waningCrescent: 'Hilal Mutanaqis',
  };

  /// Arabic weekday names with meanings (romanized)
  static const _arabicWeekdayMeanings = {
    1: 'al-Ahad (Sunday - 1st Day)',
    2: 'al-Ithnayn (Monday - 2nd Day)',
    3: 'ath-Thulatha (Tuesday - 3rd Day)',
    4: "al-Arba'a (Wednesday - 4th Day)",
    5: 'al-Khamis (Thursday - 5th Day)',
    6: "al-Jumu'ah (Friday - Gathering)",
    7: 'as-Sabt (Saturday - Sabbath)',
  };

  /// Sacred months in Islam (Ashhurul Hurum)
  static const _sacredMonths = {
    1,
    7,
    11,
    12
  }; // Muharram, Rajab, Dhul Qi'dah, Dhul Hijjah

  /// Month meanings (romanized Arabic)
  static const _monthMeanings = {
    1: 'Muharram (Forbidden - Sacred)',
    2: 'Safar (Void/Empty)',
    3: "Rabi' al-Awwal (First Spring)",
    4: "Rabi' al-Thani (Second Spring)",
    5: 'Jumada al-Awwal (First Freeze)',
    6: 'Jumada al-Thani (Second Freeze)',
    7: 'Rajab (Respect - Sacred)',
    8: "Sha'ban (Scattered)",
    9: 'Ramadan (Scorching Heat - Fasting)',
    10: 'Shawwal (Raised)',
    11: "Dhul Qi'dah (Month of Rest - Sacred)",
    12: 'Dhul Hijjah (Month of Pilgrimage - Sacred)',
  };

  @override
  Widget build(BuildContext context) {
    final day = hijriDate.hDay;
    final month = hijriDate.hMonth;
    final year = hijriDate.hYear;
    final monthName = hijriDate.longMonthName;
    final daysInMonth = hijriDate.lengthOfMonth;
    final weekDayNum = hijriDate.wkDay; // 1=Sunday, 7=Saturday
    final weekDayArabic =
        weekDayNum != null ? _arabicWeekdayMeanings[weekDayNum] : null;

    // Check if sacred month
    final isSacredMonth = _sacredMonths.contains(month);
    final monthMeaning = _monthMeanings[month] ?? monthName;

    // Get significant Islamic dates based on day/month
    String? eventName;
    if (month == 1 && day == 1) {
      eventName = 'Islamic New Year';
    } else if (month == 1 && day == 10) {
      eventName = 'Day of Ashura';
    } else if (month == 3 && day == 12) {
      eventName = 'Mawlid an-Nabi (Sunni)';
    } else if (month == 3 && day == 17) {
      eventName = 'Mawlid an-Nabi (Shia)';
    } else if (month == 7 && day == 27) {
      eventName = 'Isra and Mi\'raj';
    } else if (month == 8 && day == 15) {
      eventName = 'Shab-e-Barat';
    } else if (month == 9 && day == 1) {
      eventName = 'First Day of Ramadan';
    } else if (month == 9 && day == 27) {
      eventName = 'Laylat al-Qadr (estimated)';
    } else if (month == 10 && day == 1) {
      eventName = 'Eid al-Fitr';
    } else if (month == 12 && day == 10) {
      eventName = 'Eid al-Adha';
    }

    // Get detailed moon phase info
    final moonPhaseInfo =
        hijri_moon.MoonPhaseCalculator.getMoonPhaseForHijri(hijriDate);
    final illumination = (moonPhaseInfo.illumination * 100).toStringAsFixed(0);
    final phaseEnglish = moonPhaseInfo.englishName;
    final phaseArabic = _arabicPhaseNames[moonPhaseInfo.phase] ?? '';

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Islamic Calendar (Hijri)',
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
                'AH',
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
          // Islamic Event (if any)
          if (eventName != null) ...[
            buildDateComponent('Munasaba (Event)', eventName),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          // Sacred Month indicator
          if (isSacredMonth) ...[
            buildDateComponent('Ashhurul Hurum', 'Sacred Month'),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          // Moon Phase with Arabic name
          buildDateComponent('Qamar (Moon)', '$phaseEnglish • $phaseArabic'),
          const SizedBox(height: AppDimensions.spacingSm),
          // Illumination
          buildDateComponent('Diya (Light)', '$illumination% illuminated'),
          const SizedBox(height: AppDimensions.spacingSm),
          // Day of week with Arabic name and meaning
          if (weekDayArabic != null) ...[
            buildDateComponent('Yawm (Weekday)', weekDayArabic),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          // Day
          buildDateComponent('Yawm al-Shahr (Day)', '$day of $daysInMonth'),
          const SizedBox(height: AppDimensions.spacingSm),
          // Month with meaning
          buildDateComponent('Shahr (Month)', monthMeaning),
          const SizedBox(height: AppDimensions.spacingSm),
          // Year
          buildDateComponent('Sanah (Year)', '$year AH'),
          const SizedBox(height: AppDimensions.spacingMd),
          // Lunar month strip at bottom
          LunarMonthStrip(
            dayOfMonth: day,
            daysInMonth: daysInMonth,
            isDark: isDark,
            calendarType: 'islamic',
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          // Note
          Text(
            'Lunar calendar • Epoch: Hijra (622 CE)',
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
