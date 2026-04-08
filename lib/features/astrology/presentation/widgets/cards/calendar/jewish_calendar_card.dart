import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/moon_phase_strip.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'calendar_card_helpers.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Jewish Calendar Card - Hebrew
class JewishCalendarCard extends StatelessWidget {
  final JewishCalendar jewishCalendar;
  final bool isDark;

  const JewishCalendarCard({
    super.key,
    required this.jewishCalendar,
    required this.isDark,
  });

  /// Hebrew month names with meanings (romanized)
  static const _hebrewMonthNames = [
    'Nissan',
    'Iyar',
    'Sivan',
    'Tammuz',
    'Av',
    'Elul',
    'Tishrei',
    'Cheshvan',
    'Kislev',
    'Tevet',
    'Shevat',
    'Adar',
    'Adar II'
  ];

  /// Month meanings
  static const _hebrewMonthMeanings = {
    'Nissan': 'Miracles',
    'Iyar': 'Blossom',
    'Sivan': 'Season',
    'Tammuz': 'Heat',
    'Av': 'Father',
    'Elul': 'Harvest',
    'Tishrei': 'Beginning',
    'Cheshvan': 'Eighth Month',
    'Kislev': 'Trust',
    'Tevet': 'Goodness',
    'Shevat': 'Rod/Staff',
    'Adar': 'Strength',
    'Adar II': 'Leap Month',
  };

  /// Hebrew day of week names with English meanings (days are numbered, not named)
  static const _hebrewDayNamesWithMeaning = [
    'Yom Rishon (1st Day)', // Sunday
    'Yom Sheni (2nd Day)', // Monday
    'Yom Shlishi (3rd Day)', // Tuesday
    'Yom Revi\'i (4th Day)', // Wednesday
    'Yom Chamishi (5th Day)', // Thursday
    'Yom Shishi (6th Day)', // Friday
    'Shabbat (Sabbath)', // Saturday - only named day
  ];

  /// Jewish holiday names (from JewishCalendar constants)
  static const _holidayNames = {
    0: 'Erev Pesach',
    1: 'Pesach',
    2: 'Chol HaMoed Pesach',
    3: 'Pesach Sheni',
    4: 'Erev Shavuos',
    5: 'Shavuos',
    6: 'Fast of 17th Tammuz',
    7: 'Tisha B\'Av',
    8: 'Tu B\'Av',
    9: 'Erev Rosh Hashana',
    10: 'Rosh Hashana',
    11: 'Fast of Gedalyah',
    12: 'Erev Yom Kippur',
    13: 'Yom Kippur',
    14: 'Erev Succos',
    15: 'Succos',
    16: 'Chol HaMoed Succos',
    17: 'Hoshana Rabba',
    18: 'Shemini Atzeres',
    19: 'Simchas Torah',
    21: 'Chanukah',
    22: 'Fast of 10th Teves',
    23: 'Tu B\'Shvat',
    24: 'Fast of Esther',
    25: 'Purim',
    26: 'Shushan Purim',
    27: 'Purim Katan',
    28: 'Rosh Chodesh',
    29: 'Yom HaShoah',
    30: 'Yom HaZikaron',
    31: 'Yom HaAtzmaut',
    32: 'Yom Yerushalayim',
  };

  /// Parsha names (Torah portions)
  static const _parshaNames = {
    Parsha.BERESHIS: 'Bereshis',
    Parsha.NOACH: 'Noach',
    Parsha.LECH_LECHA: 'Lech Lecha',
    Parsha.VAYERA: 'Vayera',
    Parsha.CHAYEI_SARA: 'Chayei Sara',
    Parsha.TOLDOS: 'Toldos',
    Parsha.VAYETZEI: 'Vayetzei',
    Parsha.VAYISHLACH: 'Vayishlach',
    Parsha.VAYESHEV: 'Vayeshev',
    Parsha.MIKETZ: 'Miketz',
    Parsha.VAYIGASH: 'Vayigash',
    Parsha.VAYECHI: 'Vayechi',
    Parsha.SHEMOS: 'Shemos',
    Parsha.VAERA: 'Vaera',
    Parsha.BO: 'Bo',
    Parsha.BESHALACH: 'Beshalach',
    Parsha.YISRO: 'Yisro',
    Parsha.MISHPATIM: 'Mishpatim',
    Parsha.TERUMAH: 'Terumah',
    Parsha.TETZAVEH: 'Tetzaveh',
    Parsha.KI_SISA: 'Ki Sisa',
    Parsha.VAYAKHEL: 'Vayakhel',
    Parsha.PEKUDEI: 'Pekudei',
    Parsha.VAYIKRA: 'Vayikra',
    Parsha.TZAV: 'Tzav',
    Parsha.SHMINI: 'Shmini',
    Parsha.TAZRIA: 'Tazria',
    Parsha.METZORA: 'Metzora',
    Parsha.ACHREI_MOS: 'Achrei Mos',
    Parsha.KEDOSHIM: 'Kedoshim',
    Parsha.EMOR: 'Emor',
    Parsha.BEHAR: 'Behar',
    Parsha.BECHUKOSAI: 'Bechukosai',
    Parsha.BAMIDBAR: 'Bamidbar',
    Parsha.NASSO: 'Nasso',
    Parsha.BEHAALOSCHA: 'Behaaloscha',
    Parsha.SHLACH: 'Shlach',
    Parsha.KORACH: 'Korach',
    Parsha.CHUKAS: 'Chukas',
    Parsha.BALAK: 'Balak',
    Parsha.PINCHAS: 'Pinchas',
    Parsha.MATOS: 'Matos',
    Parsha.MASEI: 'Masei',
    Parsha.DEVARIM: 'Devarim',
    Parsha.VAESCHANAN: 'Vaeschanan',
    Parsha.EIKEV: 'Eikev',
    Parsha.REEH: 'Reeh',
    Parsha.SHOFTIM: 'Shoftim',
    Parsha.KI_SEITZEI: 'Ki Seitzei',
    Parsha.KI_SAVO: 'Ki Savo',
    Parsha.NITZAVIM: 'Nitzavim',
    Parsha.VAYEILECH: 'Vayeilech',
    Parsha.HAAZINU: 'Haazinu',
  };

  @override
  Widget build(BuildContext context) {
    final day = jewishCalendar.getJewishDayOfMonth();
    final month = jewishCalendar.getJewishMonth();
    final year = jewishCalendar.getJewishYear();
    final isLeapYear = jewishCalendar.isJewishLeapYear();
    final dayOfWeek = jewishCalendar.getDayOfWeek(); // 1=Sunday, 7=Saturday
    final daysInMonth = jewishCalendar.getDaysInJewishMonth();

    // Get holiday info
    final holidayIndex = jewishCalendar.getYomTovIndex();
    final holidayName = holidayIndex >= 0 ? _holidayNames[holidayIndex] : null;

    // Get Parsha (Torah portion) if Shabbat
    final parsha = jewishCalendar.getParshah();
    final parshaName = parsha != Parsha.NONE ? _parshaNames[parsha] : null;

    // Check if Rosh Chodesh
    final isRoshChodesh = jewishCalendar.isRoshChodesh();

    // Get month name and meaning
    final monthName = month > 0 && month <= _hebrewMonthNames.length
        ? _hebrewMonthNames[month - 1]
        : 'Month $month';
    final monthMeaning = _hebrewMonthMeanings[monthName] ?? '';

    // Get day of week name with meaning (1-indexed, Sunday=1)
    final dayNameWithMeaning = dayOfWeek >= 1 && dayOfWeek <= 7
        ? _hebrewDayNamesWithMeaning[dayOfWeek - 1]
        : '';

    // Determine significant moon days (but not if already Rosh Chodesh from holiday)
    String? moonNote;
    if (isRoshChodesh && holidayName != 'Rosh Chodesh') {
      moonNote = 'Rosh Chodesh (New Moon)';
    } else if (day == 15) {
      moonNote = 'Full Moon';
    } else if (day == 29 || day == 30) {
      moonNote = 'Erev Rosh Chodesh';
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Hebrew Calendar',
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
              Flexible(
                child: Text(
                  '$day $monthName $year',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                    height: 1.2,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                'AM',
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
          // Jewish Holiday (if any)
          if (holidayName != null) ...[
            buildDateComponent('Chag (Holiday)', holidayName),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          // Torah portion (Parsha) if Shabbat
          if (parshaName != null) ...[
            buildDateComponent('Parashat HaShavua', 'Parshat $parshaName'),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          // Moon note if significant
          if (moonNote != null) ...[
            buildDateComponent('Levanah (Moon)', moonNote),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          // Day of week (Hebrew days are numbered, not named except Shabbat)
          if (dayNameWithMeaning.isNotEmpty) ...[
            buildDateComponent('Yom (Weekday)', dayNameWithMeaning),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          // Day of month
          buildDateComponent(
              'Yom bachodesh (Day)', 'Day $day of $daysInMonth'),
          const SizedBox(height: AppDimensions.spacingSm),
          // Month with meaning
          buildDateComponent('Chodesh (Month)',
              '$monthName${monthMeaning.isNotEmpty ? ' - "$monthMeaning"' : ''}'),
          const SizedBox(height: AppDimensions.spacingSm),
          // Year
          buildDateComponent('Shanah (Year)', '$year AM'),
          const SizedBox(height: AppDimensions.spacingSm),
          // Leap year indicator - leap years have 13 months (extra Adar II)
          buildDateComponent('Shanah Me\'uberet (Leap Year)',
              isLeapYear ? 'Yes - 13 months (+ Adar II)' : 'No - 12 months'),
          const SizedBox(height: AppDimensions.spacingMd),
          // Lunar month strip at bottom
          LunarMonthStrip(
            dayOfMonth: day,
            daysInMonth: daysInMonth,
            isDark: isDark,
            calendarType: 'jewish',
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          // Note
          Text(
            'Lunisolar calendar • Epoch: Creation (3761 BCE)',
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
