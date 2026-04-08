import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/features/astrology/data/utils/world_calendar_utils.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/vedic_time_utils.dart';
import 'package:hijri_date/hijri_date.dart';
import 'package:chinese_lunar_calendar/chinese_lunar_calendar.dart';
import 'package:kosher_dart/kosher_dart.dart';

// Extracted calendar card widgets
import 'package:aurogram/features/astrology/presentation/widgets/cards/calendar/jain_calendar_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/calendar/buddhist_calendar_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/calendar/sikh_calendar_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/calendar/islamic_calendar_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/calendar/chinese_calendar_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/calendar/jewish_calendar_card.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

// Re-export for backward compatibility
export 'package:aurogram/features/astrology/presentation/widgets/cards/calendar/calendar_card_helpers.dart';
export 'package:aurogram/features/astrology/presentation/widgets/cards/calendar/jain_calendar_card.dart';
export 'package:aurogram/features/astrology/presentation/widgets/cards/calendar/buddhist_calendar_card.dart';
export 'package:aurogram/features/astrology/presentation/widgets/cards/calendar/sikh_calendar_card.dart';
export 'package:aurogram/features/astrology/presentation/widgets/cards/calendar/islamic_calendar_card.dart';
export 'package:aurogram/features/astrology/presentation/widgets/cards/calendar/chinese_calendar_card.dart';
export 'package:aurogram/features/astrology/presentation/widgets/cards/calendar/jewish_calendar_card.dart';

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
    final rawSamvat = profile.birthSamvatInfo;
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
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            child: JainCalendarCard(
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
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            child: BuddhistCalendarCard(
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
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              child: SikhCalendarCard(
                nanakshahiDate: nanakshahiDate,
                isDark: isDark,
              ),
            ),
          ),
        );
      }
    }

    // Jewish Calendar Card (Hebrew)
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
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              child: JewishCalendarCard(
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
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              child: ChineseCalendarCard(
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

    // Islamic Calendar Card (Hijri)
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
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              child: IslamicCalendarCard(
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
