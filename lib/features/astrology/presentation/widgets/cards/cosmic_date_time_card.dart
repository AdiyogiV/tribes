import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/vedic_time_utils.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/vedic_clock_painter.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Static flag to track if moon phase has been logged (once per session)
bool _loggedMoonPhase = false;

/// Date and time card for Cosmic Dashboard
/// Shows both Vedic and Western time formats
/// Matches astrology details page card styling
class CosmicDateTimeCard extends StatefulWidget {
  final Map<String, dynamic>? samvat;
  final Color brown;

  const CosmicDateTimeCard({
    super.key,
    required this.samvat,
    required this.brown,
  });

  @override
  State<CosmicDateTimeCard> createState() => _CosmicDateTimeCardState();
}

class _CosmicDateTimeCardState extends State<CosmicDateTimeCard> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Tick every 12 seconds — half-Pala for smoother live feel
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final c = AppTheme.primaryColor;
    final samvat = widget.samvat;

    final vedicPrahar = VedicTimeUtils.getVedicPrahar(_now);
    final vedicTimeShort = VedicTimeUtils.getVedicTimeShort(_now);
    final fullVedicDate = VedicTimeUtils.buildFullVedicDate(samvat);
    final samvatYear = VedicTimeUtils.buildSamvatYearNameOnly(samvat);
    final vedicNumericDate = VedicTimeUtils.buildVedicNumericDate(samvat);

    // Extract moon phase data
    int? tithiNumber = _extractTithiNumber(samvat);
    final pakshaRaw = _extractPaksha(samvat);
    final paksha = pakshaRaw.isNotEmpty ? pakshaRaw : 'shukla';

    // Log once per session when data arrives
    if (samvat != null && !_loggedMoonPhase) {
      _loggedMoonPhase = true;
      AppLogger.d('CosmicDateTimeCard: today panchang',
          category: LogCategory.ui,
          data: {
            'vedicDate': fullVedicDate,
            'samvatYear': samvatYear,
            'tithiNumber': tithiNumber,
            'paksha': paksha,
          });
    }

    // Warn if stale data somehow leaks through (birth date in today's card)
    final vikramNumber = samvat?['vikram_chaitradi_number'];
    final isValidYear = VedicTimeUtils.isValidVikramYearForToday(vikramNumber);
    if (samvat != null && !isValidYear && vikramNumber != null) {
      AppLogger.w('CosmicDateTimeCard: STALE birth data in today card!',
          category: LogCategory.ui,
          data: {
            'vikramYear': vikramNumber,
            'expectedRange': '${_now.year + 55}-${_now.year + 59}',
            'timestamp': samvat['timestamp'],
          });
    }

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: InkWell(
          onTap: () => _showVedicTimeInfo(context, isDark, c),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
              const SizedBox(height: 8),
              // 0. Vedic Analog Clock — full card width, no padding
              LayoutBuilder(
                builder: (context, constraints) {
                  final clockSize = constraints.maxWidth * 0.85;
                  return VedicClockWidget(
                    time: _now,
                    isDark: isDark,
                    size: clockSize,
                  );
                },
              ),
              // Text content with card padding
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingLg,
                  AppDimensions.spacingSm,
                  AppDimensions.paddingLg,
                  0,
                ),
                child: Column(
                  children: [
                    // Line 1: Usha Prahar
                    Text(
                      vedicPrahar,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        fontWeight: FontWeight.w500,
                        color: c,
                        height: 1.5,
                      ),
                    ),
                    // Line 2: Ghati 52 · Pala 29
                    Text(
                      vedicTimeShort,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        fontWeight: FontWeight.w500,
                        color: c,
                        height: 1.5,
                      ),
                    ),
                    // Line 2: Chaitram Krishna Shashthi
                    if (fullVedicDate != null)
                      Text(
                        fullVedicDate,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          fontWeight: FontWeight.w500,
                          color: c,
                          height: 1.5,
                        ),
                      ),
                    // Line 3: Vikram Samvat Rowdri
                    if (samvatYear != null)
                      Text(
                        samvatYear,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          fontWeight: FontWeight.w500,
                          color: c,
                          height: 1.5,
                        ),
                      ),
                    // Line 4: 6/2/1/2083
                    if (vedicNumericDate != null)
                      Text(
                        vedicNumericDate,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          fontWeight: FontWeight.w500,
                          color: c.withValues(alpha: 0.5),
                          height: 1.5,
                        ),
                      ),
                  ],
                ),
              ),
              // 5. Moon Phase Strip — hidden for now
              // TODO: Re-enable moon phase strip
              // if (hasMoonPhase) ...[
              //   ClipRRect(
              //     borderRadius: const BorderRadius.only(
              //       bottomLeft: Radius.circular(AppDimensions.radiusXl),
              //       bottomRight: Radius.circular(AppDimensions.radiusXl),
              //     ),
              //     child: Padding(
              //       padding: const EdgeInsets.only(
              //         top: AppDimensions.paddingSm,
              //         bottom: AppDimensions.paddingSm,
              //       ),
              //       child: MoonPhaseStrip(
              //         tithiNumber: tithiNumber,
              //         paksha: paksha,
              //         isDark: isDark,
              //       ),
              //     ),
              //   ),
              // ] else
              const SizedBox(height: AppDimensions.paddingLg),
            ],
          ),
        ),
      ),
    );
  }

  void _showVedicTimeInfo(BuildContext context, bool isDark, Color c) {
    HapticFeedback.lightImpact();
    AppBottomSheet.show(
      context,
      child: VedicTimeInfoSheet(
        isDark: isDark,
        brown: c,
      ),
    );
  }
}

/// Bottom sheet explaining Vedic time and date concepts
class VedicTimeInfoSheet extends StatelessWidget {
  final bool isDark;
  final Color brown;

  const VedicTimeInfoSheet({
    super.key,
    required this.isDark,
    required this.brown,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.all(AppDimensions.paddingLg),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.sheetDarkColor : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingXl,
              AppDimensions.paddingXl,
              AppDimensions.paddingXl,
              0,
            ),
            child: Text(
              'Vedic Time & Calendar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingXl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // — THE CLOCK —
                  _buildSectionHeader('The Vedic Clock', c),
                  const SizedBox(height: 8),
                  _buildInfoItem(
                    title: 'Prahar (Watch)',
                    description:
                        'The Vedic day is divided into 8 Prahars of ~3 hours each, starting at sunrise. '
                        'Each Prahar has a traditional name:\n'
                        'Purvanha (morning) \u2022 Madhyanha (midday) \u2022 Aparanha (afternoon) \u2022 '
                        'Sayanha (evening) \u2022 Pradosha (dusk) \u2022 Nishitha (midnight) \u2022 '
                        'Triyama (late night) \u2022 Usha (dawn)',
                  ),
                  _buildInfoItem(
                    title: 'Ghati',
                    description:
                        'One day (sunrise to sunrise) = 60 Ghati. '
                        'Each Ghati = 24 minutes. Think of it like the "hour" on a Vedic clock, '
                        'but with 60 divisions instead of 24.',
                  ),
                  _buildInfoItem(
                    title: 'Pala',
                    description:
                        'Each Ghati = 60 Pala. One Pala = 24 seconds. '
                        'Like "minutes" on a Vedic clock. '
                        'So Ghati:Pala is like Hours:Minutes \u2014 a clean base-60 system.',
                  ),
                  // — THE CALENDAR —
                  _buildSectionHeader('The Vedic Calendar', c),
                  const SizedBox(height: 8),
                  _buildInfoItem(
                    title: 'Masa (Month)',
                    description:
                        'The Hindu year has 12 lunar months starting from Chaitra (March\u2013April). '
                        'Months follow the Moon\'s cycle, not the Sun. '
                        'Month 1 = Chaitra, Month 2 = Vaishakha, and so on through Month 12 = Phalguna.',
                  ),
                  _buildInfoItem(
                    title: 'Paksha (Fortnight)',
                    description:
                        'Each month has two halves of 15 days. '
                        'Shukla Paksha (1) = bright/waxing half, new moon \u2192 full moon. '
                        'Krishna Paksha (2) = dark/waning half, full moon \u2192 new moon.',
                  ),
                  _buildInfoItem(
                    title: 'Tithi (Lunar Day)',
                    description:
                        'Each Paksha has 15 Tithis (lunar days), named Pratipada (1st) through '
                        'Purnima (15th full moon) or Amavasya (new moon). '
                        'Unlike solar days, Tithis can be 19\u201326 hours long.',
                  ),
                  _buildInfoItem(
                    title: 'Samvatsara (Year)',
                    description:
                        'Vikram Samvat is the traditional Hindu calendar year, ~57 years ahead of the Gregorian year. '
                        'Each year also has a name from a 60-year cycle (like Siddharthi, Raudri, etc.).',
                  ),
                  // — THE DATE FORMAT —
                  _buildSectionHeader('Reading the Vedic Date', c),
                  const SizedBox(height: 8),
                  _buildInfoItem(
                    title: 'Numeric Format',
                    description:
                        'The numeric date reads as Month / Paksha / Tithi / Year.\n\n'
                        'For example: 2/2/6/2083 means\n'
                        '\u2022 Month 2 (Vaishakha)\n'
                        '\u2022 Paksha 2 (Krishna \u2014 waning moon)\n'
                        '\u2022 Tithi 6 (Shashthi \u2014 6th lunar day)\n'
                        '\u2022 Year 2083 (Vikram Samvat)\n\n'
                        'It maps directly to the text line above it: '
                        'Vaishakha Krishna Shashthi.',
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
          // Fixed footer button
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLg),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Got it',
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    fontWeight: FontWeight.w600,
                    color: c,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color c) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: AppTheme.holyCowTextSize + 1,
          fontWeight: FontWeight.w700,
          color: c.withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required String title,
    required String description,
    bool isLast = false,
  }) {
    final c = AppTheme.primaryColor;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTheme.holyCowTextSize,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTheme.holyCowTextSize,
              fontWeight: FontWeight.w400,
              color: c.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Extract tithi number from panchang data
/// Tries multiple field names and parses from tithi name if needed
/// Returns a value 1-15 (normalized for both pakshas)
int? _extractTithiNumber(Map<String, dynamic>? samvat) {
  if (samvat == null) return null;
  
  // Try direct number fields first (handles both global and insight panchang)
  // Global panchang: 'number', 'tithi_number'
  // Insight panchang: 'tithiNumber'
  final directNumber = samvat['number'] ?? 
                       samvat['tithi_number'] ?? 
                       samvat['tithiNumber'];
  if (directNumber != null) {
    int? rawNumber;
    if (directNumber is int) {
      rawNumber = directNumber;
    } else {
      rawNumber = int.tryParse(directNumber.toString());
    }
    
    if (rawNumber != null) {
      // Some APIs return continuous 1-30 numbering
      // Shukla: 1-15, Krishna: 16-30
      // Normalize to 1-15 for both pakshas
      if (rawNumber > 15 && rawNumber <= 30) {
        return rawNumber - 15;
      }
      return rawNumber;
    }
  }
  
  // Try to extract from tithi name
  // Global panchang: 'name'
  // Insight panchang: 'tithi'
  final tithiName = (samvat['name'] ?? samvat['tithi'] ?? '').toString().toLowerCase();
  if (tithiName.isEmpty) return null;
  
  // Map of tithi names to numbers
  const tithiNames = {
    'pratipada': 1, 'prathama': 1, 'padyami': 1, 'pratham': 1,
    'dwitiya': 2, 'vidiya': 2, 'dwitia': 2, 'dvitiya': 2,
    'tritiya': 3, 'tadiya': 3,
    'chaturthi': 4, 'chaviti': 4, 'chaturti': 4,
    'panchami': 5, 'panchmi': 5,
    'shashthi': 6, 'shashti': 6, 'shasti': 6,
    'saptami': 7, 'saptmi': 7,
    'ashtami': 8, 'ashtmi': 8, 'astami': 8,
    'navami': 9, 'navmi': 9,
    'dashami': 10, 'dashmi': 10, 'dasami': 10,
    'ekadashi': 11, 'ekadasi': 11,
    'dwadashi': 12, 'dwadasi': 12, 'dvadashi': 12,
    'trayodashi': 13, 'trayodasi': 13,
    'chaturdashi': 14, 'chaturdasi': 14,
    'purnima': 15, 'poornima': 15, 'pournami': 15,
    'amavasya': 15, 'amavas': 15, // New moon is also 15th tithi
  };
  
  for (final entry in tithiNames.entries) {
    if (tithiName.contains(entry.key)) {
      return entry.value;
    }
  }
  
  return null;
}

/// Extract paksha from panchang data
String _extractPaksha(Map<String, dynamic>? samvat) {
  if (samvat == null) return '';
  
  // Try direct paksha fields (handles both global and insight panchang)
  // Global panchang: 'paksha'
  // Insight panchang: 'tithiPaksha'
  final paksha = (samvat['paksha'] ?? samvat['tithiPaksha'] ?? '').toString().toLowerCase();
  
  // Check if paksha contains 'shukla' or 'krishna' (handles "Shukla Paksha", "shukla", etc.)
  if (paksha.contains('shukla') || paksha.contains('sukla')) {
    return 'shukla';
  }
  if (paksha.contains('krishna') || paksha.contains('krsna') || paksha.contains('krishan')) {
    return 'krishna';
  }
  
  // Try to infer from tithi name
  // Global panchang: 'name'
  // Insight panchang: 'tithi'
  final name = (samvat['name'] ?? samvat['tithi'] ?? '').toString().toLowerCase();
  final combined = '$paksha $name';
  
  if (combined.contains('shukla') || combined.contains('sukla') || combined.contains('waxing')) {
    return 'shukla';
  }
  if (combined.contains('krishna') || combined.contains('krsna') || combined.contains('waning')) {
    return 'krishna';
  }
  
  // If name contains purnima, it's end of shukla paksha
  if (name.contains('purnima') || name.contains('poornima')) {
    return 'shukla';
  }
  // If name contains amavasya, it's end of krishna paksha
  if (name.contains('amavasya') || name.contains('amavas')) {
    return 'krishna';
  }
  
  // IMPORTANT: Check if tithi number is 16-30 (continuous numbering = Krishna paksha)
  final rawNumber = samvat['number'] ?? 
                    samvat['tithi_number'] ?? 
                    samvat['tithiNumber'];
  if (rawNumber != null) {
    int? num;
    if (rawNumber is int) {
      num = rawNumber;
    } else {
      num = int.tryParse(rawNumber.toString());
    }
    if (num != null && num > 15 && num <= 30) {
      return 'krishna'; // Continuous numbering: 16-30 = Krishna paksha
    }
    if (num != null && num >= 1 && num <= 15) {
      // We have a valid tithi number 1-15, default to shukla if paksha unknown
      return 'shukla';
    }
  }
  
  return '';
}
