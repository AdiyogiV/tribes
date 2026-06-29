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
///
/// When [selectedDate] is provided and differs from today, the card shows
/// that date's Gregorian info and available panchang data, but hides
/// the live Vedic clock and Prahar·Ghati·Pala (those only make sense
/// for "right now").
class CosmicDateTimeCard extends StatefulWidget {
  final Map<String, dynamic>? samvat;
  final Color brown;

  /// When non-null and not today, the card displays this date instead of
  /// the live clock.  The parent should also pass a date-appropriate
  /// [samvat] map (e.g. from AstroCalendarService.panchangMap).
  final DateTime? selectedDate;

  const CosmicDateTimeCard({
    super.key,
    required this.samvat,
    required this.brown,
    this.selectedDate,
  });

  @override
  State<CosmicDateTimeCard> createState() => _CosmicDateTimeCardState();
}

class _CosmicDateTimeCardState extends State<CosmicDateTimeCard> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  /// Whether the card is showing today (live clock) vs a selected date.
  bool get _isShowingToday {
    if (widget.selectedDate == null) return true;
    final today = DateTime.now();
    return widget.selectedDate!.year == today.year &&
        widget.selectedDate!.month == today.month &&
        widget.selectedDate!.day == today.day;
  }

  /// The date to display — live now or the selected date.
  DateTime get _displayDate => _isShowingToday ? _now : widget.selectedDate!;

  @override
  void initState() {
    super.initState();
    // Tick every 15 seconds — half-Pala for smoother live feel.
    // Only meaningful when showing today; the timer is harmless when
    // showing a selected date (setState is cheap, _displayDate ignores _now).
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _isShowingToday) setState(() => _now = DateTime.now());
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
        isDark ? const Color(0xFF000000) : Colors.white;
    final fgMain = isDark ? Colors.white : Colors.black87;
    final fgMuted = isDark ? Colors.white54 : Colors.black54;
    final c = AppTheme.primaryColor;
    final samvat = widget.samvat;

    final showingToday = _isShowingToday;
    final displayDate = _displayDate;
    final vedicTimeShort = showingToday ? VedicTimeUtils.getVedicTimeShort(_now) : null;
    final samvatYear = VedicTimeUtils.buildSamvatYearNameOnly(samvat);
    final vedicNumericDate = VedicTimeUtils.buildVedicNumericDate(samvat);

    // Split Vedic date into tithi line + month line
    // e.g. "Krishna Navami" and "Vaishakha Masa"
    final fullVedicDate = VedicTimeUtils.buildFullVedicDate(samvat);
    final lunarMonth = samvat?['lunar_month_full_name']?.toString() ??
        samvat?['lunar_month_name']?.toString() ??
        samvat?['lunarMonthFull']?.toString() ??
        samvat?['lunarMonth']?.toString();
    // Remove month from fullVedicDate to get just "Paksha Tithi"
    String? tithiLine;
    if (fullVedicDate != null && lunarMonth != null) {
      tithiLine = fullVedicDate.replaceFirst(lunarMonth, '').trim();
      if (tithiLine.isEmpty) tithiLine = null;
    } else {
      tithiLine = fullVedicDate;
    }
    final monthLine = lunarMonth;

    // Extract moon phase data
    int? tithiNumber = _extractTithiNumber(samvat);
    final pakshaRaw = _extractPaksha(samvat);
    final paksha = pakshaRaw.isNotEmpty ? pakshaRaw : 'shukla';

    // Split tithiLine into separate paksha line and tithi name line
    // e.g. "Krishna Chaturdashi" → pakshaLine="Krishna", tithiNameOnly="Chaturdashi"
    String? pakshaLine;
    String? tithiNameOnly;
    if (tithiLine != null) {
      if (pakshaRaw.isNotEmpty) {
        final pakshaCapitalized =
            '${pakshaRaw[0].toUpperCase()}${pakshaRaw.substring(1)}';
        pakshaLine = pakshaCapitalized;
        final withoutPaksha =
            tithiLine.replaceFirst(pakshaCapitalized, '').trim();
        tithiNameOnly = withoutPaksha.isNotEmpty ? withoutPaksha : null;
      } else {
        tithiNameOnly = tithiLine;
      }
    }

    // Log once per session when data arrives
    if (samvat != null && !_loggedMoonPhase && showingToday) {
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
    if (samvat != null && !isValidYear && vikramNumber != null && showingToday) {
      AppLogger.w('CosmicDateTimeCard: STALE birth data in today card!',
          category: LogCategory.ui,
          data: {
            'vikramYear': vikramNumber,
            'expectedRange': '${displayDate.year + 55}-${displayDate.year + 59}',
            'timestamp': samvat['timestamp'],
          });
    }

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: cardColor,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Stack(
          children: [
            // Card content — horizontal: clock left, text right
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingXl,
                vertical: AppDimensions.paddingXl,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Text content — left side
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pr · Gh · Pa — Eyebrow
                        if (vedicTimeShort != null) ...[
                          Text(
                            vedicTimeShort.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                              color: fgMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Tithi name: Chaturdashi
                        if (tithiNameOnly != null)
                          Text(
                            tithiNameOnly,
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontStyle: FontStyle.italic,
                              fontSize: 32,
                              color: fgMain.withValues(alpha: 0.95),
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          
                        // Paksha: Krishna
                        if (pakshaLine != null)
                          Text(
                            pakshaLine,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w300,
                              color: fgMain.withValues(alpha: 0.8),
                              height: 1.2,
                            ),
                          ),
                          
                        if (tithiNameOnly != null || pakshaLine != null)
                          const SizedBox(height: 12),
                          
                        // Month: Vaishakha Masa
                        if (monthLine != null)
                          Text(
                            monthLine,
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                              color: fgMuted.withValues(alpha: 0.8),
                            ),
                          ),
                          
                        // Numeric date
                        if (vedicNumericDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            vedicNumericDate,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: fgMuted.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMdLg),
                  // Vedic Clock — right side
                  if (showingToday)
                    VedicClockWidget(
                      time: _now,
                      isDark: isDark,
                      size: 90,
                    ),
                ],
              ),
            ),
            // Info button — top-right corner
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => _showVedicTimeInfo(context, isDark, c),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: fgMuted.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
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
    'pratipada': 1, 'pratipat': 1, 'prathama': 1, 'padyami': 1, 'pratham': 1,
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

// ─────────────────────────────────────────────────────────────────────────
// Split cards — VedicTimeCard (clock + Pr·Gh·Pa) and VedicDateCard
// (month, paksha, tithi, numeric date).  Used on the HolyCow mobile
// layout to give each section its own card.
// ─────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────
// Combined card — Vedic clock (left) + date info (center) + time readout
// (right).  Replaces the separate VedicTimeCard + VedicDateCard pair on
// mobile to save vertical space.
// ─────────────────────────────────────────────────────────────────────────

/// Single card combining clock, date, and time for the HolyCow mobile layout.
///
/// Combined Vedic date+time card for the HolyCow mobile layout.
///
/// Today layout:   [ Clock | Date | ⓘ + Time ]
/// Other date:     [ ±N days | Date | Today ↩ ]
class VedicCombinedCard extends StatefulWidget {
  final Map<String, dynamic>? samvat;
  final Color brown;
  final DateTime? selectedDate;
  final VoidCallback? onResetToToday;
  final String? nakshatraName;
  final bool embedded;

  const VedicCombinedCard({
    super.key,
    required this.samvat,
    required this.brown,
    this.selectedDate,
    this.onResetToToday,
    this.nakshatraName,
    this.embedded = false,
  });

  @override
  State<VedicCombinedCard> createState() => _VedicCombinedCardState();
}

class _VedicCombinedCardState extends State<VedicCombinedCard> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  bool get _isShowingToday {
    if (widget.selectedDate == null) return true;
    final today = DateTime.now();
    return widget.selectedDate!.year == today.year &&
        widget.selectedDate!.month == today.month &&
        widget.selectedDate!.day == today.day;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _isShowingToday) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final samvat = widget.samvat;
    final showingToday = _isShowingToday;

    // Date info
    final vedicNumericDate = VedicTimeUtils.buildVedicNumericDate(samvat);
    final fullVedicDate = VedicTimeUtils.buildFullVedicDate(samvat);
    final lunarMonth = samvat?['lunar_month_full_name']?.toString() ??
        samvat?['lunar_month_name']?.toString() ??
        samvat?['lunarMonthFull']?.toString() ??
        samvat?['lunarMonth']?.toString();

    String? tithiLine;
    if (fullVedicDate != null && lunarMonth != null) {
      tithiLine = fullVedicDate.replaceFirst(lunarMonth, '').trim();
      if (tithiLine.isEmpty) tithiLine = null;
    } else {
      tithiLine = fullVedicDate;
    }

    final pakshaRaw = _extractPaksha(samvat);
    String? pakshaLine;
    String? tithiNameOnly;
    if (tithiLine != null) {
      if (pakshaRaw.isNotEmpty) {
        final pakshaCapitalized = '${pakshaRaw[0].toUpperCase()}${pakshaRaw.substring(1)}';
        pakshaLine = pakshaCapitalized;
        final withoutPaksha = tithiLine.replaceFirst(pakshaCapitalized, '').trim();
        tithiNameOnly = withoutPaksha.isNotEmpty ? withoutPaksha : null;
      } else {
        tithiNameOnly = tithiLine;
      }
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDate = widget.selectedDate ?? todayDate;
    final displayDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    final praharName = VedicTimeUtils.getPraharName(_now);
    final ghati = VedicTimeUtils.getGhati(_now);
    final pala = VedicTimeUtils.getPala(_now);
    final daysDiff = displayDate.difference(todayDate).inDays;
    final offsetStr = showingToday ? 'TODAY' : (daysDiff > 0 ? 'IN $daysDiff DAYS' : '${daysDiff.abs()} DAYS AGO');

    final primaryWhite = Colors.white.withValues(alpha: 0.95);
    final secondaryWhite = Colors.white.withValues(alpha: 0.5);

    // Left Column: Classic, chic, editorial (Serif Italic)
    final leftStyle = TextStyle(
      fontFamily: 'Georgia',
      fontStyle: FontStyle.italic,
      color: primaryWhite,
      fontSize: 16,
      letterSpacing: 0.5,
      height: 1.5,
    );

    // Right Column: Clean, modern, precise (Sans-serif Light)
    final rightStyle = TextStyle(
      color: primaryWhite.withValues(alpha: 0.9),
      fontSize: 16,
      fontWeight: FontWeight.w300,
      letterSpacing: 1.0,
      height: 1.5,
    );

    // Bottom Footer Tags
    final bottomStyle = TextStyle(
      color: primaryWhite.withValues(alpha: 0.85),
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.5,
      height: 1.5,
    );

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LEFT COLUMN (Date Stack)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (lunarMonth != null) Text(lunarMonth, style: leftStyle),
                    if (pakshaLine != null) Text(pakshaLine, style: leftStyle),
                    if (tithiNameOnly != null) Text(tithiNameOnly, style: leftStyle),
                    if (vedicNumericDate != null) ...[
                      const SizedBox(height: 6),
                      Text(vedicNumericDate.toUpperCase(), style: bottomStyle),
                    ],
                  ],
                ),
              ),
              
              // RIGHT COLUMN (Time Stack)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showingToday) ...[
                    if (ghati != null) Text('${ghati} Ghati', style: rightStyle),
                    if (pala != null) Text('${pala.toString().padLeft(2, '0')} Pala', style: rightStyle),
                    if (praharName != '') Text(praharName, style: rightStyle),
                  ],
                  
                  const SizedBox(height: 6),
                  if (showingToday)
                    Text('LIVE', style: bottomStyle.copyWith(color: primaryWhite))
                  else ...[
                    Text(offsetStr, style: bottomStyle.copyWith(color: primaryWhite)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onResetToToday?.call();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: primaryWhite.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.replay_rounded, size: 10, color: primaryWhite),
                            const SizedBox(width: 4),
                            Text(
                              'TODAY', 
                              style: TextStyle(
                                color: primaryWhite, 
                                fontSize: 9, 
                                fontWeight: FontWeight.w700, 
                                letterSpacing: 1.5,
                              )
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Time-only card: Vedic clock + Prahar · Ghati · Pala readout.
class VedicTimeCard extends StatefulWidget {
  final Color brown;
  const VedicTimeCard({super.key, required this.brown});

  @override
  State<VedicTimeCard> createState() => _VedicTimeCardState();
}

class _VedicTimeCardState extends State<VedicTimeCard> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _clockMagnified = false;

  @override
  void initState() {
    super.initState();
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
    final cardColor = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final c = AppTheme.primaryColor;

    // Compute Prahar, Ghati, Pala individually
    const sunriseHour = 6;
    var secondsFromSunrise = (_now.hour - sunriseHour) * 3600 + _now.minute * 60 + _now.second;
    if (secondsFromSunrise < 0) secondsFromSunrise += 86400;
    final prahar = (secondsFromSunrise ~/ (180 * 60)) % 8 + 1;
    final ghati = secondsFromSunrise ~/ 1440;
    final pala = (secondsFromSunrise - (ghati * 1440)) ~/ 24;

    final textStyle = TextStyle(
      fontSize: AppTheme.holyCowTextSize,
      fontWeight: FontWeight.w500,
      color: c,
      height: 1.4,
    );

    // When the clock is magnified, raise the entire card above siblings
    // so the expanded clock doesn't render behind other cards.
    final card = SizedBox(
      width: double.infinity,
      child: Material(
        color: cardColor,
        elevation: _clockMagnified ? 24 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        clipBehavior: Clip.none,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingLg,
                AppDimensions.paddingMd,
                AppDimensions.paddingLg,
                AppDimensions.paddingMd,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Vedic Clock — left side
                  VedicClockWidget(
                    time: _now,
                    isDark: isDark,
                    size: 80,
                    onMagnifyChanged: (magnified) {
                      setState(() => _clockMagnified = magnified);
                    },
                  ),
                  const SizedBox(width: AppDimensions.spacingLg),
                  // Vedic time text — right side, three lines
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Prahar $prahar', style: textStyle),
                      Text('Ghati $ghati', style: textStyle),
                      Text('Pala $pala', style: textStyle),
                    ],
                  ),
                ],
              ),
            ),
            // Info button — top-right corner
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  AppBottomSheet.show(
                    context,
                    child: VedicTimeInfoSheet(isDark: isDark, brown: c),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: c.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return card;
  }
}

/// Date-only card: lunar month, paksha, tithi name, numeric date.
class VedicDateCard extends StatelessWidget {
  final Map<String, dynamic>? samvat;
  final Color brown;
  final DateTime? selectedDate;

  const VedicDateCard({
    super.key,
    required this.samvat,
    required this.brown,
    this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final c = AppTheme.primaryColor;

    final vedicNumericDate = VedicTimeUtils.buildVedicNumericDate(samvat);
    final fullVedicDate = VedicTimeUtils.buildFullVedicDate(samvat);
    final lunarMonth = samvat?['lunar_month_full_name']?.toString() ??
        samvat?['lunar_month_name']?.toString() ??
        samvat?['lunarMonthFull']?.toString() ??
        samvat?['lunarMonth']?.toString();

    String? tithiLine;
    if (fullVedicDate != null && lunarMonth != null) {
      tithiLine = fullVedicDate.replaceFirst(lunarMonth, '').trim();
      if (tithiLine.isEmpty) tithiLine = null;
    } else {
      tithiLine = fullVedicDate;
    }
    final monthLine = lunarMonth;

    final pakshaRaw = _extractPaksha(samvat);
    String? pakshaLine;
    String? tithiNameOnly;
    if (tithiLine != null) {
      if (pakshaRaw.isNotEmpty) {
        final pakshaCapitalized =
            '${pakshaRaw[0].toUpperCase()}${pakshaRaw.substring(1)}';
        pakshaLine = pakshaCapitalized;
        final withoutPaksha =
            tithiLine.replaceFirst(pakshaCapitalized, '').trim();
        tithiNameOnly = withoutPaksha.isNotEmpty ? withoutPaksha : null;
      } else {
        tithiNameOnly = tithiLine;
      }
    }

    // If there's nothing to show, collapse
    if (monthLine == null && pakshaLine == null && tithiNameOnly == null && vedicNumericDate == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingLg,
            AppDimensions.paddingMd,
            AppDimensions.paddingLg,
            AppDimensions.paddingMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (monthLine != null)
                Text(
                  monthLine,
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    fontWeight: FontWeight.w500,
                    color: c,
                    height: 1.4,
                  ),
                ),
              if (pakshaLine != null)
                Text(
                  pakshaLine,
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    fontWeight: FontWeight.w500,
                    color: c,
                    height: 1.4,
                  ),
                ),
              if (tithiNameOnly != null)
                Text(
                  tithiNameOnly,
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    fontWeight: FontWeight.w500,
                    color: c,
                    height: 1.4,
                  ),
                ),
              if (vedicNumericDate != null)
                Text(
                  vedicNumericDate,
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    fontWeight: FontWeight.w500,
                    color: c.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
