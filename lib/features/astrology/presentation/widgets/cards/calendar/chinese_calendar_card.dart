import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/moon_phase_strip.dart';
import 'package:chinese_lunar_calendar/chinese_lunar_calendar.dart';
import 'calendar_card_helpers.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Chinese Calendar Card - Lunar with Zodiac and Bazi
class ChineseCalendarCard extends StatelessWidget {
  final LunarCalendar lunarCalendar;
  final bool isDark;

  const ChineseCalendarCard({
    super.key,
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
  // ignore: unused_field
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
  // ignore: unused_field
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
  // ignore: unused_field
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

  /// Get element meaning for a pillar (e.g., "JiaZi" -> "Yang Wood + Rat/Water")
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
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          buildCalendarHeader('Chinese Lunar Calendar'),
          const SizedBox(height: AppDimensions.spacingMd),
          // Zodiac display with element (e.g., "Wood Dragon Year")
          buildCalendarMainDate('$zodiacElement $zodiacEnglish Year'),
          const SizedBox(height: AppDimensions.spacingLg),
          // Traditional Chinese Year
          buildDateComponent(
              'Nian (Year)', '$chineseYear (Lunar: $lunarYear)'),
          const SizedBox(height: AppDimensions.spacingSm),
          // Lunar Date
          buildDateComponent('Yue/Ri (Month/Day)',
              '${isLeapMonth ? 'Run (Leap) ' : ''}Month $month, Day $day'),
          const SizedBox(height: AppDimensions.spacingSm),
          // Moon Phase
          buildDateComponent('Yueliang (Moon)', moonPhaseName),
          const SizedBox(height: AppDimensions.spacingSm),
          // Bazi - Four Pillars with element meanings
          buildDateComponent('Year Pillar', '$yearPillar ($yearMeaning)'),
          const SizedBox(height: AppDimensions.spacingSm),
          buildDateComponent('Month Pillar', '$monthPillar ($monthMeaning)'),
          const SizedBox(height: AppDimensions.spacingSm),
          buildDateComponent('Day Pillar', '$dayPillar ($dayMeaning)'),
          const SizedBox(height: AppDimensions.spacingSm),
          buildDateComponent('Hour Pillar', '$hourPillar ($hourMeaning)'),
          const SizedBox(height: AppDimensions.spacingMd),
          // Lunar month strip at bottom
          LunarMonthStrip(
            dayOfMonth: day,
            daysInMonth: daysInMonth,
            isDark: isDark,
            calendarType: 'chinese',
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          // Note
          buildCalendarFooter('Lunisolar • Epoch: Yellow Emperor (2697 BCE)'),
        ],
      ),
    );
  }
}
