import 'package:flutter/material.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/utils/astrology/astrology_formatters.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/astrology/cards/vedic_time_utils.dart';
import 'package:aurogram/widgets/astrology/cards/world_calendar_cards.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'moon_phase_strip.dart';

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
      // Some APIs return continuous 1-30 numbering
      // Normalize to 1-15 for both pakshas
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

  // Check if tithi number is 16-30 (continuous numbering = Krishna paksha)
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
      return 'shukla'; // Default for 1-15 range
    }
  }

  return paksha.isNotEmpty ? paksha : null;
}

/// Horizontal scrollable widget showing Vedic Samvat calendar info
class VedicSamvatCards extends StatelessWidget {
  final AstrologyProfile profile;

  const VedicSamvatCards({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawSamvat = profile.samvatInfo;
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
            borderRadius: BorderRadius.circular(20),
            child: _SamvatCard(
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
            borderRadius: BorderRadius.circular(20),
            child: _SamvatCard(
              label: 'Śaka Śālivāhana',
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
      final tithiNumber = _extractTithiNumber(samvat);
      final paksha = _extractPaksha(samvat);

      final saptarishiKashmirYear = birthYear + 3076;
      cards.add(
        SizedBox(
          width: cardWidth,
          child: Material(
            color: cardColor,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            child: _SaptarishiCard(
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
            borderRadius: BorderRadius.circular(20),
            child: _SaptarishiCard(
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
            borderRadius: BorderRadius.circular(20),
            child: _VedicEraCard(
              label: 'Mahabharata Samvat',
              year: mahabharataYear,
              yearSuffix: 'MS',
              epochYear: 5561,
              epochNote: 'Mahabharata War • Epoch: Oct 16, 5561 BCE (Oak)',
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
            borderRadius: BorderRadius.circular(20),
            child: _VedicEraCard(
              label: 'Kali Yuga',
              year: kaliYugaYear,
              yearSuffix: 'KY',
              epochYear: 3102,
              epochNote: 'Current Yuga • Epoch: Feb 18, 3102 BCE',
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

class _SamvatCard extends StatelessWidget {
  final String label;
  final dynamic yearNumber;
  final dynamic yearName;
  final Map<String, dynamic>? samvat;
  final bool isDark;
  final double? userLat;
  final double? userLng;
  final String? birthTime;
  final DateTime? birthDate;
  final String? nakshatra;
  final String? yoga;
  final String? karana;

  const _SamvatCard({
    required this.label,
    required this.yearNumber,
    required this.yearName,
    required this.samvat,
    required this.isDark,
    this.userLat,
    this.userLng,
    this.birthTime,
    this.birthDate,
    this.nakshatra,
    this.yoga,
    this.karana,
  });

  /// Vara (weekday) with planetary lord (Sanskrit romanized)
  /// Weekday: 1=Monday, 7=Sunday (Dart DateTime.weekday format)
  static const _varaNames = {
    1: 'Somvaar (Monday - Moon)',
    2: 'Mangalvaar (Tuesday - Mars)',
    3: 'Budhvaar (Wednesday - Mercury)',
    4: 'Guruvaar (Thursday - Jupiter)',
    5: 'Shukravaar (Friday - Venus)',
    6: 'Shanivaar (Saturday - Saturn)',
    7: 'Ravivaar (Sunday - Sun)',
  };

  @override
  Widget build(BuildContext context) {
    final lunarMonthName = samvat?['lunar_month_full_name']?.toString() ??
        samvat?['lunar_month_name']?.toString();
    final lunarMonthNumber = samvat?['lunar_month_number'];
    final tithiName =
        samvat?['name']?.toString() ?? samvat?['tithi']?.toString();

    // Use extraction functions to handle different data formats
    final tithiNumber = _extractTithiNumber(samvat);
    final paksha = _extractPaksha(samvat);

    final pakshaNameEng = paksha == 'shukla'
        ? 'Waxing Moon'
        : paksha == 'krishna'
            ? 'Waning Moon'
            : null;
    final pakshaSanskrit = paksha == 'shukla'
        ? 'Shukla'
        : paksha == 'krishna'
            ? 'Krishna'
            : paksha;
    final pakshaNumber = paksha == 'shukla'
        ? 1
        : paksha == 'krishna'
            ? 2
            : null;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          // Numerical date
          if (lunarMonthNumber != null &&
              tithiNumber != null &&
              yearNumber != null)
            Row(
              children: [
                Text(
                  '$lunarMonthNumber${pakshaNumber != null ? '/$pakshaNumber' : ''}/$tithiNumber/$yearNumber',
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
                    pakshaNumber != null
                        ? '(Māsa/Paksha/Tithi/Varsha)'
                        : '(Māsa/Tithi/Varsha)',
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
            ),
          const SizedBox(height: 12),
          // Month
          if (lunarMonthName != null)
            _buildDateComponent(
              'Māsa (Month)',
              '$lunarMonthName${lunarMonthNumber != null ? ' ($lunarMonthNumber)' : ''}',
            ),
          // Paksha
          if (pakshaSanskrit != null && pakshaNameEng != null) ...[
            const SizedBox(height: 8),
            _buildDateComponent(
              'Paksha (Fortnight)',
              '$pakshaSanskrit • $pakshaNameEng',
            ),
          ],
          // Tithi
          if (tithiName != null) ...[
            const SizedBox(height: 8),
            _buildDateComponent(
              'Tithi (Lunar Day)',
              '$tithiName${tithiNumber != null ? ' ($tithiNumber of 15)' : ''}',
            ),
          ],
          // === PANCHANG ELEMENTS ===
          // Nakshatra (Lunar Mansion)
          if (nakshatra != null && nakshatra!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDateComponent(
              'Nakshatra (Star)',
              nakshatra!,
            ),
          ],
          // Yoga (Sun-Moon combination)
          if (yoga != null && yoga!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDateComponent(
              'Yoga (Combination)',
              yoga!,
            ),
          ],
          // Karana (Half-tithi)
          if (karana != null && karana!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDateComponent(
              'Karana (Half-Day)',
              karana!,
            ),
          ],
          // Vara (Weekday with planetary lord)
          if (birthDate != null) ...[
            const SizedBox(height: 8),
            _buildDateComponent(
              'Vara (Weekday)',
              _varaNames[birthDate!.weekday] ?? 'Unknown',
            ),
          ],
          // Year cycle
          if (yearName != null && yearName.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDateComponent(
              'Varsha (Year)',
              '${yearName.toString()} • $yearNumber',
            ),
          ],
          // Vedic Time - Prahar & Ghati/Pala
          if (birthTime != null && birthTime!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final vedicTime = AstrologyFormatters.calculatePrahar(birthTime);
              if (vedicTime == null) return const SizedBox.shrink();

              return Column(
                children: [
                  _buildDateComponent(
                    'Prahar (Watch)',
                    '${vedicTime['praharName']} • ${vedicTime['prahar']} of 8',
                  ),
                  const SizedBox(height: 8),
                  _buildDateComponent(
                    'Samay (Time)',
                    '${vedicTime['ghatis']} Ghati ${vedicTime['palas']} Pala',
                  ),
                ],
              );
            }),
          ],
          // Reference from Ujjain (Hindu Prime Meridian)
          if (userLat != null && userLng != null) ...[
            const SizedBox(height: 8),
            _buildDateComponent(
              'Akshansha (Latitude)',
              AstrologyFormatters.formatLatitudeFromUjjain(userLat!),
            ),
            const SizedBox(height: 8),
            _buildDateComponent(
              'Desantara (Longitude)',
              AstrologyFormatters.formatLongitudeFromUjjain(userLng!),
            ),
          ],
          // Moon phase visualization at bottom
          if (tithiNumber != null && paksha != null) ...[
            const SizedBox(height: 12),
            MoonPhaseStrip(
              tithiNumber: tithiNumber,
              paksha: paksha,
              isDark: isDark,
            ),
          ],
          const SizedBox(height: 12),
          // Epoch note
          Text(
            label == 'Vikram Samvat'
                ? 'Lunisolar calendar • Epoch: King Vikramaditya (57 BCE)'
                : 'Lunisolar calendar • Epoch: Shalivahana (78 CE)',
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

  Widget _buildDateComponent(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
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

/// Saptarishi Calendar Card
/// Based on movement of Ursa Major (Seven Sages) through 27 Nakshatras
class _SaptarishiCard extends StatelessWidget {
  final String label;
  final int year;
  final int epoch;
  final String epochName;
  final Map<String, dynamic>? samvat;
  final bool isDark;
  final String? nakshatra;
  final String? yoga;
  final String? karana;
  final int? tithiNumber;
  final String? paksha;

  const _SaptarishiCard({
    required this.label,
    required this.year,
    required this.epoch,
    required this.epochName,
    required this.samvat,
    required this.isDark,
    this.nakshatra,
    this.yoga,
    this.karana,
    this.tithiNumber,
    this.paksha,
  });

  /// The 27 Nakshatras in order
  static const _nakshatras = [
    'Ashwini',
    'Bharani',
    'Krittika',
    'Rohini',
    'Mrigashira',
    'Ardra',
    'Punarvasu',
    'Pushya',
    'Ashlesha',
    'Magha',
    'Purva Phalguni',
    'Uttara Phalguni',
    'Hasta',
    'Chitra',
    'Swati',
    'Vishakha',
    'Anuradha',
    'Jyeshtha',
    'Mula',
    'Purva Ashadha',
    'Uttara Ashadha',
    'Shravana',
    'Dhanishta',
    'Shatabhisha',
    'Purva Bhadrapada',
    'Uttara Bhadrapada',
    'Revati',
  ];

  /// Calculate which nakshatra the Saptarishis are residing in
  /// Using traditional 100-year per nakshatra system
  Map<String, dynamic> _calculateNakshatraPosition() {
    // Cycle is 2700 years (27 nakshatras × 100 years each)
    const cycleLength = 2700;
    const yearsPerNakshatra = 100;

    // Starting nakshatra depends on epoch
    // 3076 BCE: Started in Magha (index 9)
    // 6676 BCE: Started in Krittika (index 2)
    final startNakshatraIndex = epoch == 3076 ? 9 : 2; // Magha or Krittika

    // Calculate position in cycle
    final yearsElapsed = year;
    final yearsIntoCycle = yearsElapsed % cycleLength;
    final nakshatrasCompleted = yearsIntoCycle ~/ yearsPerNakshatra;
    final yearsInCurrentNakshatra = yearsIntoCycle % yearsPerNakshatra;

    // Current nakshatra index (wrapping around)
    final currentNakshatraIndex =
        (startNakshatraIndex + nakshatrasCompleted) % 27;
    final currentNakshatra = _nakshatras[currentNakshatraIndex];

    // Cycle number (1-indexed)
    final cycleNumber = (yearsElapsed ~/ cycleLength) + 1;

    return {
      'nakshatra': currentNakshatra,
      'nakshatraIndex': currentNakshatraIndex + 1, // 1-indexed for display
      'yearsInNakshatra': yearsInCurrentNakshatra,
      'yearsRemaining': yearsPerNakshatra - yearsInCurrentNakshatra,
      'cycleNumber': cycleNumber,
      'yearsIntoCycle': yearsIntoCycle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final position = _calculateNakshatraPosition();
    final saptarishiNakshatra = position['nakshatra'] as String;
    final nakshatraIndex = position['nakshatraIndex'] as int;
    final yearsInNakshatra = position['yearsInNakshatra'] as int;
    final cycleNumber = position['cycleNumber'] as int;

    // Extract month/tithi/paksha from samvat (same keys as _SamvatCard)
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
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
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
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    pakshaNumber != null
                        ? '(Māsa/Paksha/Tithi/Varsha)'
                        : '(Māsa/Tithi/Varsha)',
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
                const SizedBox(width: 8),
                Text(
                  'SS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),

          // === SAPTARISHI CYCLE INFO ===
          _buildComponent(
            'Rishi Nakshatra',
            '$saptarishiNakshatra (#$nakshatraIndex of 27)',
          ),
          const SizedBox(height: 8),
          _buildComponent(
            'Years in Nakshatra',
            '$yearsInNakshatra of 100 years',
          ),
          const SizedBox(height: 8),
          _buildComponent(
            'Chakra (Cycle)',
            'Cycle $cycleNumber (2700 years each)',
          ),
          const SizedBox(height: 8),

          // === BIRTH DATE INFO (Lunisolar - shared with Vedic) ===
          if (monthName != null) ...[
            _buildComponent('Māsa (Month)', monthName.toString()),
            const SizedBox(height: 8),
          ],
          if (pakshaName != null) ...[
            _buildComponent(
              'Paksha (Fortnight)',
              pakshaName.toString().toLowerCase().contains('shukla') ||
                      pakshaName.toString().toLowerCase().contains('sukla')
                  ? 'Shukla (Bright/Waxing)'
                  : 'Krishna (Dark/Waning)',
            ),
            const SizedBox(height: 8),
          ],
          if (tithiName != null) ...[
            _buildComponent('Tithi (Lunar Day)', tithiName.toString()),
            const SizedBox(height: 8),
          ],

          // === PANCHANG ELEMENTS ===
          if (nakshatra != null && nakshatra!.isNotEmpty) ...[
            _buildComponent('Nakshatra (Star)', nakshatra!),
            const SizedBox(height: 8),
          ],
          if (yoga != null && yoga!.isNotEmpty) ...[
            _buildComponent('Yoga (Combination)', yoga!),
            const SizedBox(height: 8),
          ],
          if (karana != null && karana!.isNotEmpty) ...[
            _buildComponent('Karana (Half-Day)', karana!),
            const SizedBox(height: 8),
          ],

          // Moon phase visualization
          if (tithiNumber != null && paksha != null) ...[
            const SizedBox(height: 4),
            MoonPhaseStrip(
              tithiNumber: tithiNumber!,
              paksha: paksha!,
              isDark: isDark,
            ),
          ],
          const SizedBox(height: 12),
          // Epoch note
          Text(
            'Saptarishi cycle • Epoch: $epochName ($epoch BCE)',
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

/// Generic Vedic Era Card for epoch-based calendars
/// Used for Mahabharata Samvat, Kali Yuga, etc.
class _VedicEraCard extends StatelessWidget {
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

  const _VedicEraCard({
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
    // Extract month/tithi/paksha from samvat (same keys as _SamvatCard)
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
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
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
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    pakshaNumber != null
                        ? '(Māsa/Paksha/Tithi/Varsha)'
                        : '(Māsa/Tithi/Varsha)',
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
                const SizedBox(width: 8),
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
          const SizedBox(height: 16),

          // === BIRTH DATE INFO (Lunisolar - shared with Vedic) ===
          if (monthName != null) ...[
            _buildComponent('Māsa (Month)', monthName.toString()),
            const SizedBox(height: 8),
          ],
          if (pakshaName != null) ...[
            _buildComponent(
              'Paksha (Fortnight)',
              pakshaName.toString().toLowerCase().contains('shukla') ||
                      pakshaName.toString().toLowerCase().contains('sukla')
                  ? 'Shukla (Bright/Waxing)'
                  : 'Krishna (Dark/Waning)',
            ),
            const SizedBox(height: 8),
          ],
          if (tithiName != null) ...[
            _buildComponent('Tithi (Lunar Day)', tithiName.toString()),
            const SizedBox(height: 8),
          ],

          // === PANCHANG ELEMENTS ===
          if (nakshatra != null && nakshatra!.isNotEmpty) ...[
            _buildComponent('Nakshatra (Star)', nakshatra!),
            const SizedBox(height: 8),
          ],
          if (yoga != null && yoga!.isNotEmpty) ...[
            _buildComponent('Yoga (Combination)', yoga!),
            const SizedBox(height: 8),
          ],
          if (karana != null && karana!.isNotEmpty) ...[
            _buildComponent('Karana (Half-Day)', karana!),
            const SizedBox(height: 8),
          ],

          // Moon phase visualization
          if (tithiNumber != null && paksha != null) ...[
            const SizedBox(height: 4),
            MoonPhaseStrip(
              tithiNumber: tithiNumber!,
              paksha: paksha!,
              isDark: isDark,
            ),
          ],
          const SizedBox(height: 12),
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
