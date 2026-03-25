import 'package:flutter/material.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/calendar/world_calendar_utils.dart';
import 'package:aurogram/widgets/astrology/cards/vedic_time_utils.dart';
import 'package:hijri_date/hijri_date.dart';
import 'package:hijri_date/moon_phases.dart' as hijri_moon;
import 'package:chinese_lunar_calendar/chinese_lunar_calendar.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'moon_phase_strip.dart'; // MoonPhaseStrip for paksha, LunarMonthStrip for non-paksha

/// Extract tithi number from samvat data (normalized to 1-15)
int? _extractTithiNumber(Map<String, dynamic>? samvat) {
  if (samvat == null) return null;

  final directNumber =
      samvat['number'] ?? samvat['tithi_number'] ?? samvat['tithiNumber'];
  if (directNumber != null) {
    int? rawNumber;
    if (directNumber is int) {
      rawNumber = directNumber;
    } else {
      rawNumber = int.tryParse(directNumber.toString());
    }

    if (rawNumber != null) {
      if (rawNumber > 15 && rawNumber <= 30) {
        return rawNumber - 15;
      }
      return rawNumber;
    }
  }
  return null;
}

/// Extract paksha from samvat data
String? _extractPaksha(Map<String, dynamic>? samvat) {
  if (samvat == null) return null;

  final paksha = (samvat['paksha'] ?? samvat['tithiPaksha'] ?? '')
      .toString()
      .toLowerCase();

  if (paksha.contains('shukla') || paksha.contains('sukla')) {
    return 'shukla';
  }
  if (paksha.contains('krishna') ||
      paksha.contains('krsna') ||
      paksha.contains('krishan')) {
    return 'krishna';
  }

  final rawNumber =
      samvat['number'] ?? samvat['tithi_number'] ?? samvat['tithiNumber'];
  if (rawNumber != null) {
    int? num;
    if (rawNumber is int) {
      num = rawNumber;
    } else {
      num = int.tryParse(rawNumber.toString());
    }
    if (num != null && num > 15 && num <= 30) {
      return 'krishna';
    }
    if (num != null && num >= 1 && num <= 15) {
      return 'shukla';
    }
  }

  return paksha.isNotEmpty ? paksha : null;
}

/// Utility class for building world calendar cards.
/// Can be used standalone or integrated into VedicSamvatCards.
class WorldCalendarCards extends StatelessWidget {
  final AstrologyProfile profile;

  const WorldCalendarCards({super.key, required this.profile});

  /// Static method to build world calendar cards list.
  /// Returns a list of card widgets that can be added to any horizontal scroll.
  static List<Widget> buildCardsList({
    required BuildContext context,
    required AstrologyProfile profile,
    required double cardWidth,
    required Color cardColor,
    required bool isDark,
  }) {
    final rawSamvat = profile.samvatInfo;
    final samvat =
        VedicTimeUtils.filterBirthSamvat(rawSamvat, profile.birthDate);

    // Get birth date for calculations
    final birthDate = profile.birthDate;
    final birthYear = profile.birthYear ?? birthDate?.year;

    if (birthYear == null) {
      return [];
    }

    final cards = <Widget>[];

    // Jain Calendar Card (Vira Nirvana Samvat)
    final vikramNumber = samvat?['vikram_chaitradi_number'];
    final viraYear = vikramNumber != null
        ? WorldCalendarUtils.vikramToViraSamvat(
            int.tryParse(vikramNumber.toString()) ?? 0)
        : WorldCalendarUtils.getViraSamvatYear(birthYear);

    if (viraYear > 0) {
      cards.add(
        SizedBox(
          width: cardWidth,
          child: Material(
            color: cardColor,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            child: _JainCalendarCard(
              viraYear: viraYear,
              samvat: samvat,
              isDark: isDark,
            ),
          ),
        ),
      );
    }

    // Buddhist Calendar Card (Buddhist Era)
    final buddhistYear = vikramNumber != null
        ? WorldCalendarUtils.vikramToBuddhistEra(
            int.tryParse(vikramNumber.toString()) ?? 0)
        : WorldCalendarUtils.getBuddhistYear(birthYear);

    if (buddhistYear > 0) {
      cards.add(
        SizedBox(
          width: cardWidth,
          child: Material(
            color: cardColor,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            child: _BuddhistCalendarCard(
              buddhistYear: buddhistYear,
              samvat: samvat,
              isDark: isDark,
            ),
          ),
        ),
      );
    }

    // Sikh Calendar Card (Nanakshahi)
    if (birthDate != null) {
      final nanakshahiDate =
          WorldCalendarUtils.getFullNanakshahiDate(birthDate);
      final nanakshahiYear = nanakshahiDate['year'] as int;

      if (nanakshahiYear > 0) {
        cards.add(
          SizedBox(
            width: cardWidth,
            child: Material(
              color: cardColor,
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              child: _SikhCalendarCard(
                nanakshahiDate: nanakshahiDate,
                isDark: isDark,
              ),
            ),
          ),
        );
      }
    }

    // Jewish Calendar Card (Hebrew) - position 10
    if (birthDate != null) {
      try {
        final jewishCalendar = JewishCalendar.fromDateTime(birthDate);
        cards.add(
          SizedBox(
            width: cardWidth,
            child: Material(
              color: cardColor,
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              child: _JewishCalendarCard(
                jewishCalendar: jewishCalendar,
                isDark: isDark,
              ),
            ),
          ),
        );
      } catch (_) {
        // Skip if conversion fails
      }
    }

    // Chinese Calendar Card
    if (birthDate != null) {
      try {
        final chineseLunar = LunarCalendar.from(utcDateTime: birthDate.toUtc());
        cards.add(
          SizedBox(
            width: cardWidth,
            child: Material(
              color: cardColor,
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              child: _ChineseCalendarCard(
                lunarCalendar: chineseLunar,
                isDark: isDark,
              ),
            ),
          ),
        );
      } catch (_) {
        // Skip if conversion fails
      }
    }

    // Islamic Calendar Card (Hijri) - position 12
    if (birthDate != null) {
      try {
        final hijri = HijriDate.fromDate(birthDate);
        cards.add(
          SizedBox(
            width: cardWidth,
            child: Material(
              color: cardColor,
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              child: _IslamicCalendarCard(
                hijriDate: hijri,
                isDark: isDark,
              ),
            ),
          ),
        );
      } catch (_) {
        // Skip if conversion fails
      }
    }

    return cards;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    const gap = 12.0;
    final screenWidth = MediaQuery.of(context).size.width;
    // Cap card width for web readability - max 400px
    final cardWidth = (screenWidth - 32.0).clamp(280.0, 400.0);

    final cards = buildCardsList(
      context: context,
      profile: profile,
      cardWidth: cardWidth,
      cardColor: cardColor,
      isDark: isDark,
    );

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return IntrinsicHeight(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards.asMap().entries.map((entry) {
            final index = entry.key;
            final card = entry.value;
            return Padding(
              padding:
                  EdgeInsets.only(right: index < cards.length - 1 ? gap : 0),
              child: card,
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Jain Calendar Card - Vira Nirvana Samvat
/// Uses the same lunar structure as Vedic calendar (tithi, paksha, masa)
class _JainCalendarCard extends StatelessWidget {
  final int viraYear;
  final Map<String, dynamic>? samvat;
  final bool isDark;

  const _JainCalendarCard({
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
    final tithiNumber = _extractTithiNumber(samvat);
    final paksha = _extractPaksha(samvat);

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
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
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
                const SizedBox(width: 10),
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
          const SizedBox(height: 16),
          // Parva Tithi (significant days)
          if (parvaTithi != null) ...[
            _buildDateComponent('Parva (Sacred Day)', parvaTithi),
            const SizedBox(height: 8),
          ],
          // Month (Masa)
          if (lunarMonthName != null)
            _buildDateComponent('Masa (Month)',
                '$lunarMonthName${lunarMonthNumber != null ? ' ($lunarMonthNumber)' : ''}'),
          // Tithi
          if (tithiName != null) ...[
            const SizedBox(height: 8),
            _buildDateComponent('Tithi (Lunar Day)',
                '$tithiName${tithiNumber != null ? ' ($tithiNumber)' : ''}'),
          ],
          // Paksha (Prakrit term)
          if (pakshaPrakrit != null && pakshaNameEng != null) ...[
            const SizedBox(height: 8),
            _buildDateComponent(
                'Pakkha (Fortnight)', '$pakshaPrakrit • $pakshaNameEng'),
          ],
          // Year
          const SizedBox(height: 8),
          _buildDateComponent('Varsha (Year)', '$viraYear VNS'),
          const SizedBox(height: 12),
          // Moon phase visualization at bottom
          if (tithiNumber != null && paksha != null)
            MoonPhaseStrip(
              tithiNumber: tithiNumber,
              paksha: paksha,
              isDark: isDark,
            ),
          if (tithiNumber != null && paksha != null) const SizedBox(height: 12),
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

/// Buddhist Calendar Card - Buddhist Era (BE)
/// Uses the same lunar structure as Vedic calendar
class _BuddhistCalendarCard extends StatelessWidget {
  final int buddhistYear;
  final Map<String, dynamic>? samvat;
  final bool isDark;

  const _BuddhistCalendarCard({
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
    final tithiNumber = _extractTithiNumber(samvat);
    final paksha = _extractPaksha(samvat);

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
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
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
              const SizedBox(width: 10),
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
          const SizedBox(height: 16),
          // Uposatha (significant observance days)
          if (uposatha != null) ...[
            _buildDateComponent('Uposatha (Observance)', uposatha),
            const SizedBox(height: 8),
          ],
          // Month (Pali name)
          if (paliMonth != null) _buildDateComponent('Masa (Month)', paliMonth),
          // Day (Tithi)
          if (tithiName != null) ...[
            const SizedBox(height: 8),
            _buildDateComponent('Tithi (Lunar Day)',
                '$tithiName${tithiNumber != null ? ' ($tithiNumber)' : ''}'),
          ],
          // Phase (Paksha in Pali)
          if (pakshaNamePali != null) ...[
            const SizedBox(height: 8),
            _buildDateComponent('Pakkha (Fortnight)', pakshaNamePali),
          ],
          // Year
          const SizedBox(height: 8),
          _buildDateComponent('Vassa (Year)', 'BE $buddhistYear'),
          const SizedBox(height: 12),
          // Moon phase visualization at bottom
          if (tithiNumber != null && paksha != null)
            MoonPhaseStrip(
              tithiNumber: tithiNumber,
              paksha: paksha,
              isDark: isDark,
            ),
          if (tithiNumber != null && paksha != null) const SizedBox(height: 12),
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

/// Sikh Calendar Card - Nanakshahi
/// Solar calendar with fixed month lengths
class _SikhCalendarCard extends StatelessWidget {
  final Map<String, dynamic> nanakshahiDate;
  final bool isDark;

  const _SikhCalendarCard({
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
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
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
              const SizedBox(width: 10),
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
          const SizedBox(height: 16),
          // Sangrand indicator
          if (isSangrand) ...[
            _buildDateComponent(
                'Sangrand (New Month)', 'First day of $monthName'),
            const SizedBox(height: 8),
          ],
          // Season (Rutt)
          if (season.isNotEmpty) ...[
            _buildDateComponent('Rutt (Season)', season),
            const SizedBox(height: 8),
          ],
          // Weekday (Vaar) in Punjabi
          if (weekdayName != null) ...[
            _buildDateComponent('Vaar (Weekday)', weekdayName),
            const SizedBox(height: 8),
          ],
          // Day (Din)
          _buildDateComponent('Din (Day)', 'Day $day'),
          const SizedBox(height: 8),
          // Month (Mahina)
          _buildDateComponent('Mahina (Month)', '$monthName ($month of 12)'),
          const SizedBox(height: 8),
          // Year (Sal)
          _buildDateComponent('Sal (Year)', '$year NS'),
          const SizedBox(height: 12),
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

/// Helper widget to build date component rows
Widget _buildDateComponent(String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 100,
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

/// Islamic Calendar Card - Hijri
/// Lunar calendar based on moon sighting
class _IslamicCalendarCard extends StatelessWidget {
  final HijriDate hijriDate;
  final bool isDark;

  const _IslamicCalendarCard({
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
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
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
              const SizedBox(width: 10),
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
          const SizedBox(height: 16),
          // Islamic Event (if any)
          if (eventName != null) ...[
            _buildDateComponent('Munasaba (Event)', eventName),
            const SizedBox(height: 8),
          ],
          // Sacred Month indicator
          if (isSacredMonth) ...[
            _buildDateComponent('Ashhurul Hurum', 'Sacred Month'),
            const SizedBox(height: 8),
          ],
          // Moon Phase with Arabic name
          _buildDateComponent('Qamar (Moon)', '$phaseEnglish • $phaseArabic'),
          const SizedBox(height: 8),
          // Illumination
          _buildDateComponent('Diya (Light)', '$illumination% illuminated'),
          const SizedBox(height: 8),
          // Day of week with Arabic name and meaning
          if (weekDayArabic != null) ...[
            _buildDateComponent('Yawm (Weekday)', weekDayArabic),
            const SizedBox(height: 8),
          ],
          // Day
          _buildDateComponent('Yawm al-Shahr (Day)', '$day of $daysInMonth'),
          const SizedBox(height: 8),
          // Month with meaning
          _buildDateComponent('Shahr (Month)', monthMeaning),
          const SizedBox(height: 8),
          // Year
          _buildDateComponent('Sanah (Year)', '$year AH'),
          const SizedBox(height: 12),
          // Lunar month strip at bottom
          LunarMonthStrip(
            dayOfMonth: day,
            daysInMonth: daysInMonth,
            isDark: isDark,
            calendarType: 'islamic',
          ),
          const SizedBox(height: 12),
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

/// Chinese Calendar Card - Lunar with Zodiac and Bazi
class _ChineseCalendarCard extends StatelessWidget {
  final LunarCalendar lunarCalendar;
  final bool isDark;

  const _ChineseCalendarCard({
    required this.lunarCalendar,
    required this.isDark,
  });

  /// English zodiac names (index 0-11: Rat to Pig)
  static const _englishZodiacNames = [
    'Rat',
    'Ox',
    'Tiger',
    'Rabbit',
    'Dragon',
    'Snake',
    'Horse',
    'Goat',
    'Monkey',
    'Rooster',
    'Dog',
    'Pig'
  ];

  /// Romanized Heavenly Stems (Tiangan)
  static const _heavenlyStems = [
    'Jia',
    'Yi',
    'Bing',
    'Ding',
    'Wu',
    'Ji',
    'Geng',
    'Xin',
    'Ren',
    'Gui'
  ];

  /// Romanized Earthly Branches (Dizhi)
  static const _earthlyBranches = [
    'Zi',
    'Chou',
    'Yin',
    'Mao',
    'Chen',
    'Si',
    'Wu',
    'Wei',
    'Shen',
    'You',
    'Xu',
    'Hai'
  ];

  /// English weekday names
  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  /// Heavenly Stem elements (index 0-9: Jia to Gui)
  static const _stemElements = [
    'Yang Wood',
    'Yin Wood',
    'Yang Fire',
    'Yin Fire',
    'Yang Earth',
    'Yin Earth',
    'Yang Metal',
    'Yin Metal',
    'Yang Water',
    'Yin Water'
  ];

  /// Earthly Branch animals and elements (index 0-11: Zi to Hai)
  static const _branchMeanings = [
    'Rat/Water',
    'Ox/Earth',
    'Tiger/Wood',
    'Rabbit/Wood',
    'Dragon/Earth',
    'Snake/Fire',
    'Horse/Fire',
    'Goat/Earth',
    'Monkey/Metal',
    'Rooster/Metal',
    'Dog/Earth',
    'Pig/Water'
  ];

  /// Chinese characters for stems and branches
  static const _stemChars = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
  static const _branchChars = [
    '子',
    '丑',
    '寅',
    '卯',
    '辰',
    '巳',
    '午',
    '未',
    '申',
    '酉',
    '戌',
    '亥'
  ];

  /// Convert Chinese 8-char to romanized pinyin with element meanings
  String _romanizeBazi(String char8) {
    const charMap = {
      '甲': 'Jia',
      '乙': 'Yi',
      '丙': 'Bing',
      '丁': 'Ding',
      '戊': 'Wu',
      '己': 'Ji',
      '庚': 'Geng',
      '辛': 'Xin',
      '壬': 'Ren',
      '癸': 'Gui',
      '子': 'Zi',
      '丑': 'Chou',
      '寅': 'Yin',
      '卯': 'Mao',
      '辰': 'Chen',
      '巳': 'Si',
      '午': 'Wu',
      '未': 'Wei',
      '申': 'Shen',
      '酉': 'You',
      '戌': 'Xu',
      '亥': 'Hai',
    };
    String result = '';
    for (int i = 0; i < char8.length; i++) {
      result += charMap[char8[i]] ?? char8[i];
    }
    return result;
  }

  /// Get element meaning for a pillar (e.g., "JiaZi" → "Yang Wood + Rat/Water")
  String _getPillarMeaning(String char8) {
    if (char8.length < 2) return '';

    final stemChar = char8[0];
    final branchChar = char8[1];

    final stemIndex = _stemChars.indexOf(stemChar);
    final branchIndex = _branchChars.indexOf(branchChar);

    if (stemIndex == -1 || branchIndex == -1) return '';

    return '${_stemElements[stemIndex]} + ${_branchMeanings[branchIndex]}';
  }

  /// Get zodiac element from year stem (first character of year8Char)
  String _getZodiacElement(String year8Char) {
    if (year8Char.isEmpty) return '';
    final stemChar = year8Char[0];
    final stemIndex = _stemChars.indexOf(stemChar);
    if (stemIndex == -1) return '';
    // Elements cycle: Wood, Wood, Fire, Fire, Earth, Earth, Metal, Metal, Water, Water
    const elements = [
      'Wood',
      'Wood',
      'Fire',
      'Fire',
      'Earth',
      'Earth',
      'Metal',
      'Metal',
      'Water',
      'Water'
    ];
    return elements[stemIndex];
  }

  @override
  Widget build(BuildContext context) {
    final lunarDate = lunarCalendar.lunarDate;
    final lunarYear = lunarDate.lunarYear
        .number; // This is the lunar year number (similar to Gregorian)
    final month = lunarDate.lunarMonth.number;
    final day = lunarDate.lunarDay;
    final isLeapMonth = lunarDate.lunarMonth.isLeapMonth;
    final zodiac = lunarCalendar.zodiac;

    // Calculate traditional Chinese year (from Yellow Emperor epoch 2697 BCE)
    // Gregorian year + 2697 = Chinese year
    final chineseYear = lunarYear + 2697;

    // Bazi (Four Pillars / Eight Characters)
    final yearPillar = _romanizeBazi(lunarCalendar.year8Char);
    final monthPillar = _romanizeBazi(lunarCalendar.month8Char);
    final dayPillar = _romanizeBazi(lunarCalendar.day8Char);
    final hourPillar = _romanizeBazi(lunarCalendar.twoHour8Char);

    // Get element meanings for each pillar
    final yearMeaning = _getPillarMeaning(lunarCalendar.year8Char);
    final monthMeaning = _getPillarMeaning(lunarCalendar.month8Char);
    final dayMeaning = _getPillarMeaning(lunarCalendar.day8Char);
    final hourMeaning = _getPillarMeaning(lunarCalendar.twoHour8Char);

    // Get zodiac element (Wood, Fire, Earth, Metal, Water)
    final zodiacElement = _getZodiacElement(lunarCalendar.year8Char);

    // Moon phase - derive English name from lunar day
    String moonPhaseName;
    if (day == 1) {
      moonPhaseName = 'New Moon';
    } else if (day <= 7) {
      moonPhaseName = 'Waxing Crescent';
    } else if (day <= 8) {
      moonPhaseName = 'First Quarter';
    } else if (day <= 14) {
      moonPhaseName = 'Waxing Gibbous';
    } else if (day == 15) {
      moonPhaseName = 'Full Moon';
    } else if (day <= 22) {
      moonPhaseName = 'Waning Gibbous';
    } else if (day <= 23) {
      moonPhaseName = 'Last Quarter';
    } else {
      moonPhaseName = 'Waning Crescent';
    }

    // Get English zodiac name from index (0-11)
    final zodiacIndex = zodiac.index;
    final zodiacEnglish =
        zodiacIndex >= 0 && zodiacIndex < _englishZodiacNames.length
            ? _englishZodiacNames[zodiacIndex]
            : 'Unknown';

    // Days in this lunar month
    final daysInMonth = lunarDate.lunarMonth.days;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Chinese Lunar Calendar',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          // Zodiac display with element (e.g., "Wood Dragon Year")
          Row(
            children: [
              Flexible(
                child: Text(
                  '$zodiacElement $zodiacEnglish Year',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                    height: 1.2,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Traditional Chinese Year
          _buildDateComponent(
              'Nian (Year)', '$chineseYear (Lunar: $lunarYear)'),
          const SizedBox(height: 8),
          // Lunar Date
          _buildDateComponent('Yue/Ri (Month/Day)',
              '${isLeapMonth ? 'Run (Leap) ' : ''}Month $month, Day $day'),
          const SizedBox(height: 8),
          // Moon Phase
          _buildDateComponent('Yueliang (Moon)', moonPhaseName),
          const SizedBox(height: 8),
          // Bazi - Four Pillars with element meanings
          _buildDateComponent('Year Pillar', '$yearPillar ($yearMeaning)'),
          const SizedBox(height: 8),
          _buildDateComponent('Month Pillar', '$monthPillar ($monthMeaning)'),
          const SizedBox(height: 8),
          _buildDateComponent('Day Pillar', '$dayPillar ($dayMeaning)'),
          const SizedBox(height: 8),
          _buildDateComponent('Hour Pillar', '$hourPillar ($hourMeaning)'),
          const SizedBox(height: 12),
          // Lunar month strip at bottom
          LunarMonthStrip(
            dayOfMonth: day,
            daysInMonth: daysInMonth,
            isDark: isDark,
            calendarType: 'chinese',
          ),
          const SizedBox(height: 12),
          // Note
          Text(
            'Lunisolar • Epoch: Yellow Emperor (2697 BCE)',
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

/// Jewish Calendar Card - Hebrew
class _JewishCalendarCard extends StatelessWidget {
  final JewishCalendar jewishCalendar;
  final bool isDark;

  const _JewishCalendarCard({
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
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
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
              const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          // Jewish Holiday (if any)
          if (holidayName != null) ...[
            _buildDateComponent('Chag (Holiday)', holidayName),
            const SizedBox(height: 8),
          ],
          // Torah portion (Parsha) if Shabbat
          if (parshaName != null) ...[
            _buildDateComponent('Parashat HaShavua', 'Parshat $parshaName'),
            const SizedBox(height: 8),
          ],
          // Moon note if significant
          if (moonNote != null) ...[
            _buildDateComponent('Levanah (Moon)', moonNote),
            const SizedBox(height: 8),
          ],
          // Day of week (Hebrew days are numbered, not named except Shabbat)
          if (dayNameWithMeaning.isNotEmpty) ...[
            _buildDateComponent('Yom (Weekday)', dayNameWithMeaning),
            const SizedBox(height: 8),
          ],
          // Day of month
          _buildDateComponent(
              'Yom bachodesh (Day)', 'Day $day of $daysInMonth'),
          const SizedBox(height: 8),
          // Month with meaning
          _buildDateComponent('Chodesh (Month)',
              '$monthName${monthMeaning.isNotEmpty ? ' - "$monthMeaning"' : ''}'),
          const SizedBox(height: 8),
          // Year
          _buildDateComponent('Shanah (Year)', '$year AM'),
          const SizedBox(height: 8),
          // Leap year indicator - leap years have 13 months (extra Adar II)
          _buildDateComponent('Shanah Me\'uberet (Leap Year)',
              isLeapYear ? 'Yes - 13 months (+ Adar II)' : 'No - 12 months'),
          const SizedBox(height: 12),
          // Lunar month strip at bottom
          LunarMonthStrip(
            dayOfMonth: day,
            daysInMonth: daysInMonth,
            isDark: isDark,
            calendarType: 'jewish',
          ),
          const SizedBox(height: 12),
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
