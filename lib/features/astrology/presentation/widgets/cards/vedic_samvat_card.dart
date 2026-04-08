import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/vedic_time_utils.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/world_calendar_cards.dart' hide extractTithiNumber, extractPaksha;
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/samvat/samvat_helpers.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/samvat/samvat_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/samvat/saptarishi_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/samvat/vedic_era_card.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Horizontal scrollable widget showing Vedic Samvat calendar info
class VedicSamvatCards extends StatelessWidget {
  final AstrologyProfile profile;

  const VedicSamvatCards({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawSamvat = profile.birthSamvatInfo;
    final samvat =
        VedicTimeUtils.filterBirthSamvat(rawSamvat, profile.birthDate);
    AppLogger.i('VedicSamvatCards: samvat payload',
        category: LogCategory.general,
        data: {
          'birthDate': profile.birthDate?.toIso8601String(),
          'birthYear': profile.birthYear,
          'birthMonth': profile.birthMonth,
          'birthDay': profile.birthDay,
          'samvatPresent': rawSamvat != null,
          'samvatAfterFilter': samvat != null,
          'samvatKeys': rawSamvat?.keys.toList(),
          'vikramYear': rawSamvat?['vikram_chaitradi_number'],
          'vikramYearName': rawSamvat?['vikram_chaitradi_year_name'],
          'lunarMonth': rawSamvat?['lunar_month_full_name'] ??
              rawSamvat?['lunar_month_name'],
          'tithi': rawSamvat?['name'] ?? rawSamvat?['tithi'],
          'paksha': rawSamvat?['paksha'] ?? rawSamvat?['tithiPaksha'],
          'gregorianYear':
              rawSamvat?['gregorian_year'] ?? rawSamvat?['gregorianYear'],
          'gregorianMonth':
              rawSamvat?['gregorian_month'] ?? rawSamvat?['gregorianMonth'],
          'gregorianDate':
              rawSamvat?['gregorian_date'] ?? rawSamvat?['gregorianDate'],
        });
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    final sakaNumber = samvat?['saka_salivahana_number'];
    final sakaName = samvat?['saka_salivahana_year_name'];
    final vikramNumber = samvat?['vikram_chaitradi_number'];
    final vikramName = samvat?['vikram_chaitradi_year_name'];

    const gap = 12.0;
    final screenWidth = MediaQuery.of(context).size.width;
    // Cap card width for web readability - max 400px
    final cardWidth = (screenWidth - 32.0).clamp(280.0, 400.0);

    final cards = <Widget>[];

    // Get panchang data for nakshatra, yoga, karana
    final panchang = profile.panchang;
    final nakshatra =
        profile.moonNakshatra ?? panchang?['nakshatra']?.toString();
    final yoga = panchang?['yoga']?.toString();
    final karana = panchang?['karana']?.toString();

    // Vedic Vikram Samvat
    if (vikramNumber != null) {
      cards.add(
        SizedBox(
          width: cardWidth,
          child: Material(
            color: cardColor,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            child: SamvatCard(
              label: 'Vikram Samvat',
              yearNumber: vikramNumber,
              yearName: vikramName,
              samvat: samvat,
              isDark: isDark,
              userLat: profile.birthLatitude,
              userLng: profile.birthLongitude,
              birthTime: profile.birthTime,
              birthDate: profile.birthDate,
              nakshatra: nakshatra,
              yoga: yoga,
              karana: karana,
            ),
          ),
        ),
      );
    }
    if (sakaNumber != null) {
      cards.add(
        SizedBox(
          width: cardWidth,
          child: Material(
            color: cardColor,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            child: SamvatCard(
              label: '\u015aaka \u015a\u0101liv\u0101hana',
              yearNumber: sakaNumber,
              yearName: sakaName,
              samvat: samvat,
              isDark: isDark,
              userLat: profile.birthLatitude,
              userLng: profile.birthLongitude,
              birthTime: profile.birthTime,
              birthDate: profile.birthDate,
              nakshatra: nakshatra,
              yoga: yoga,
              karana: karana,
            ),
          ),
        ),
      );
    }

    // Saptarishi Samvat (Kashmir/Laukika) - Epoch: 3076 BCE
    final birthYear = profile.birthYear ?? profile.birthDate?.year;
    if (birthYear != null) {
      // Extract tithi and paksha for moon strip
      final tithiNumber = extractTithiNumber(samvat);
      final paksha = extractPaksha(samvat);

      final saptarishiKashmirYear = birthYear + 3076;
      cards.add(
        SizedBox(
          width: cardWidth,
          child: Material(
            color: cardColor,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            child: SaptarishiCard(
              label: 'Kashmir Laukika Samvat',
              year: saptarishiKashmirYear,
              epoch: 3076,
              epochName: "Yudhishthira's reign",
              samvat: samvat,
              isDark: isDark,
              nakshatra: nakshatra,
              yoga: yoga,
              karana: karana,
              tithiNumber: tithiNumber,
              paksha: paksha,
            ),
          ),
        ),
      );

      // Saptarishi Samvat - Epoch: 6676 BCE
      final saptarishiAncientYear = birthYear + 6676;
      cards.add(
        SizedBox(
          width: cardWidth,
          child: Material(
            color: cardColor,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            child: SaptarishiCard(
              label: 'Saptarishi Samvat',
              year: saptarishiAncientYear,
              epoch: 6676,
              epochName: 'Krittika Nakshatra',
              samvat: samvat,
              isDark: isDark,
              nakshatra: nakshatra,
              yoga: yoga,
              karana: karana,
              tithiNumber: tithiNumber,
              paksha: paksha,
            ),
          ),
        ),
      );

      // Mahabharata Samvat (Nilesh Oak) - Epoch: 5561 BCE
      final mahabharataYear = birthYear + 5561;
      cards.add(
        SizedBox(
          width: cardWidth,
          child: Material(
            color: cardColor,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            child: VedicEraCard(
              label: 'Mahabharata Samvat',
              year: mahabharataYear,
              yearSuffix: 'MS',
              epochYear: 5561,
              epochNote: 'Mahabharata War \u2022 Epoch: Oct 16, 5561 BCE (Oak)',
              samvat: samvat,
              isDark: isDark,
              nakshatra: nakshatra,
              yoga: yoga,
              karana: karana,
              tithiNumber: tithiNumber,
              paksha: paksha,
            ),
          ),
        ),
      );

      // Kali Yuga - Epoch: 3102 BCE
      final kaliYugaYear = birthYear + 3102;
      cards.add(
        SizedBox(
          width: cardWidth,
          child: Material(
            color: cardColor,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            child: VedicEraCard(
              label: 'Kali Yuga',
              year: kaliYugaYear,
              yearSuffix: 'KY',
              epochYear: 3102,
              epochNote: 'Current Yuga \u2022 Epoch: Feb 18, 3102 BCE',
              samvat: samvat,
              isDark: isDark,
              nakshatra: nakshatra,
              yoga: yoga,
              karana: karana,
              tithiNumber: tithiNumber,
              paksha: paksha,
            ),
          ),
        ),
      );
    }

    // Add world calendar cards (Jain, Buddhist, Sikh, Jewish, Chinese, Islamic)
    final worldCards = WorldCalendarCards.buildCardsList(
      context: context,
      profile: profile,
      cardWidth: cardWidth,
      cardColor: cardColor,
      isDark: isDark,
    );
    cards.addAll(worldCards);

    // Return empty if no cards at all
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
