import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_date_time_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/vedic_time_utils.dart';

/// Dense single-row "today strip" shown at the top of the desktop/wide
/// cosmic dashboard in place of the mobile split date/time cards.
///
/// Renders a row of compact two-line cells (TODAY, VEDIC clock, VAAR, MOON,
/// TITHI, MASA, NAKSHATRA), skipping any without data. Date-derived cells
/// (VAAR, MOON, weekday) always render so even signed-out users get a rich
/// strip. The live VEDIC clock ticks every 15s and only shows for "now".
class BabaDesktopTodayStrip extends StatefulWidget {
  final Map<String, dynamic>? samvat;
  final Map<String, dynamic>? todayPanchang;
  final Color brown;

  /// Pre-resolved nakshatra name from the parent — uses the same insight
  /// panchang path the wheel relies on, which is the only path that works
  /// for signed-out users (samvat/todayPanchang don't carry nakshatra for them).
  final String? todayNakshatra;

  /// When non-null and not today, the strip adapts to show the selected
  /// date's info.  The VEDIC clock cell is hidden (only meaningful for
  /// "right now") and panchang cells use [selectedDatePanchang].
  final DateTime? selectedDate;

  /// Panchang data for the selected date (from AstroCalendarService).
  /// Used for TITHI, NAKSHATRA cells when showing a non-today date.
  final Map<String, dynamic>? selectedDatePanchang;

  const BabaDesktopTodayStrip({
    super.key,
    required this.samvat,
    required this.todayPanchang,
    required this.brown,
    this.todayNakshatra,
    this.selectedDate,
    this.selectedDatePanchang,
  });

  @override
  State<BabaDesktopTodayStrip> createState() =>
      _BabaDesktopTodayStripState();
}

class _BabaDesktopTodayStripState extends State<BabaDesktopTodayStrip> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Re-render the vedic clock every 15s — same cadence as CosmicDateTimeCard.
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

    // Determine if we're showing today or a selected date.
    final nowDate = _now;
    final isShowingToday = widget.selectedDate == null ||
        (widget.selectedDate!.year == nowDate.year &&
            widget.selectedDate!.month == nowDate.month &&
            widget.selectedDate!.day == nowDate.day);
    final displayDate = isShowingToday ? nowDate : widget.selectedDate!;

    // For today: use full samvat.  For other dates: use calendar panchang.
    final samvat = isShowingToday ? widget.samvat : widget.selectedDatePanchang;
    final vedicTimeShort = isShowingToday ? VedicTimeUtils.getVedicTimeShort(_now) : null;

    // Tithi (e.g. "Krishna Saptami") — derived from the same data that
    // CosmicDateTimeCard parses, but assembled horizontally.
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
    final monthLine = lunarMonth != null ? '$lunarMonth Masa' : null;

    // Nakshatra — for today prefer the parent-resolved value (uses the
    // insight panchang path which works for signed-out users); for other
    // dates use the calendar panchang nakshatra.
    String? displayNakshatra;
    if (isShowingToday) {
      displayNakshatra = widget.todayNakshatra;
      if (displayNakshatra == null || displayNakshatra.isEmpty) {
        for (final raw in [
          widget.todayPanchang?['nakshatra'],
          widget.samvat?['nakshatra'],
          widget.samvat?['nakshatra_name'],
          widget.samvat?['moonNakshatra'],
        ]) {
          if (raw is String && raw.isNotEmpty) {
            displayNakshatra = raw;
            break;
          }
          if (raw is Map) {
            final name = raw['name']?.toString();
            if (name != null && name.isNotEmpty) {
              displayNakshatra = name;
              break;
            }
          }
        }
      }
    } else {
      // Non-today: calendar panchang stores nakshatra as a plain string.
      final raw = samvat?['nakshatra'];
      if (raw is String && raw.isNotEmpty) {
        displayNakshatra = raw;
      } else if (raw is Map) {
        displayNakshatra = raw['name']?.toString();
      }
    }

    // Western date display
    final weekdayShort = _weekdayShort(displayDate.weekday).toUpperCase();
    final monthShort = _monthShort(displayDate.month).toUpperCase();
    final dateStr = '$weekdayShort $monthShort ${displayDate.day}';

    // Vedic weekday (Vaar) — derived purely from the date, so this ALWAYS
    // renders regardless of auth state.  Gives signed-out users a richer
    // strip even when panchang data is unavailable.  Each day corresponds
    // to a classical planetary lord (e.g. Saturday → Saturn → Shanivar).
    final vaarLabel = _vedicWeekday(displayDate.weekday);
    final vaarPlanet = _vedicWeekdayPlanet(displayDate.weekday);

    // Moon phase — astronomical approximation using a reference new moon
    // and the synodic month (29.530588 days).  Computed from the date
    // alone so it works for all users.  Lovely delight element.
    final moonPhase = _moonPhase(displayDate);

    // Build the cells we want to show, skipping any without data.
    final cells = <Widget>[
      _StripCell(
        label: isShowingToday ? 'TODAY' : 'DATE',
        value: dateStr,
        c: c,
      ),
      // VEDIC clock — only for live "now" view
      if (vedicTimeShort != null)
        _StripCell(
          label: 'VEDIC',
          value: vedicTimeShort,
          c: c,
        ),
      // VAAR is always present — purely date-derived.
      _StripCell(
        label: 'VAAR',
        value: '$vaarPlanet $vaarLabel',
        c: c,
      ),
      // MOON phase — always present, also purely date-derived.
      _StripCell(
        label: 'MOON',
        value: '${moonPhase.$1} ${moonPhase.$2}',
        c: c,
      ),
      if (tithiLine != null && tithiLine.isNotEmpty)
        _StripCell(
          label: 'TITHI',
          value: tithiLine,
          c: c,
        ),
      if (monthLine != null)
        _StripCell(
          label: 'MASA',
          value: monthLine,
          c: c,
        ),
      if (displayNakshatra != null && displayNakshatra.isNotEmpty)
        _StripCell(
          label: 'NAKSHATRA',
          value: '\u263D $displayNakshatra',
          c: c,
        ),
    ];

    return Material(
      color: cardColor,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingLg,
          vertical: AppDimensions.paddingMd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Cells with thin vertical dividers between them.
            // Cells size to their content — they don't stretch.  This keeps
            // the strip readable for signed-out users (who only have TODAY +
            // VEDIC) while still looking balanced when all 5 cells render.
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMd,
                  ),
                  color: c.withValues(alpha: 0.10),
                ),
              cells[i],
            ],
            // Push the ⓘ icon to the far right regardless of cell count.
            const Spacer(),
            // ⓘ info — defers to the same explainer sheet as the mobile card.
            GestureDetector(
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
                  size: 16,
                  color: c.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekdayShort(int wd) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(wd - 1).clamp(0, 6)];
  }

  static String _monthShort(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[(m - 1).clamp(0, 11)];
  }

  // Vedic weekday names (Vaar). DateTime.weekday is 1-7 where 1=Monday.
  static String _vedicWeekday(int wd) {
    const names = [
      'Somavar',     // Mon — Moon
      'Mangalvar',   // Tue — Mars
      'Budhvar',     // Wed — Mercury
      'Guruvar',     // Thu — Jupiter
      'Shukravar',   // Fri — Venus
      'Shanivar',    // Sat — Saturn
      'Ravivar',     // Sun — Sun
    ];
    return names[(wd - 1).clamp(0, 6)];
  }

  // Classical planetary lord glyph for each weekday — a subtle visual
  // anchor so the VAAR cell reads as a piece of astrology, not just a
  // translation.
  static String _vedicWeekdayPlanet(int wd) {
    // Moon, Mars, Mercury, Jupiter, Venus, Saturn, Sun glyphs.
    const glyphs = [
      '\u263E', '\u2642', '\u263F', '\u2643', '\u2640', '\u2644', '\u2609',
    ];
    return glyphs[(wd - 1).clamp(0, 6)];
  }

  /// Approximate moon phase for a given date.  Returns a (emoji, label)
  /// tuple computed from a reference new-moon epoch and the synodic
  /// period.  Accurate to within ~½ day, which is plenty for a UI cell.
  ///
  /// Reference: Jan 6 2000 18:14 UTC was an exact new moon.
  /// Synodic month: 29.530588 days.
  static (String, String) _moonPhase(DateTime date) {
    // Days since reference new moon in UTC.
    final ref = DateTime.utc(2000, 1, 6, 18, 14);
    final days = date.toUtc().difference(ref).inSeconds / 86400.0;
    final synodic = 29.530588;
    var phase = (days / synodic) % 1.0;
    if (phase < 0) phase += 1.0;

    // 8 standard moon-phase buckets.  Cutpoints are roughly 1/16 fractions
    // so each named phase gets equal sky time around its peak.
    if (phase < 0.0625) return ('\u{1F311}', 'New');
    if (phase < 0.1875) return ('\u{1F312}', 'Waxing crescent');
    if (phase < 0.3125) return ('\u{1F313}', 'First quarter');
    if (phase < 0.4375) return ('\u{1F314}', 'Waxing gibbous');
    if (phase < 0.5625) return ('\u{1F315}', 'Full');
    if (phase < 0.6875) return ('\u{1F316}', 'Waning gibbous');
    if (phase < 0.8125) return ('\u{1F317}', 'Last quarter');
    if (phase < 0.9375) return ('\u{1F318}', 'Waning crescent');
    return ('\u{1F311}', 'New');
  }
}

/// Small two-line cell used inside [BabaDesktopTodayStrip]. Upper line is
/// the label (small, low-opacity, letter-spaced); lower line is the value
/// (regular weight, full opacity, single-line ellipsised).
class _StripCell extends StatelessWidget {
  final String label;
  final String value;
  final Color c;
  const _StripCell({required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.babaTextSize - 4,
            fontWeight: FontWeight.w600,
            color: c.withValues(alpha: 0.45),
            letterSpacing: 0.8,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTheme.babaTextSize,
            fontWeight: FontWeight.w600,
            color: c,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
