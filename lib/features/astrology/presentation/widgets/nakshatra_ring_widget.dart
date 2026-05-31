import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/features/astrology/data/utils/nakshatra_data.dart';
import 'package:aurogram/features/astrology/data/utils/daily_vibe.dart';
import 'package:aurogram/features/astrology/data/utils/mood_log.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/features/astrology/presentation/widgets/common/pulsing_dot.dart';

// =============================================================================
// NakshatraWheelController
// =============================================================================
//
// Flutter-idiomatic ChangeNotifier (like TabController / ScrollController).
// The wheel writes public state into it on every nakshatra boundary crossing
// during drag, so independent cards anywhere on the page can react live —
// without being nested inside NakshatraRingWidget.
//
// Usage:
//   final _ctrl = NakshatraWheelController();
//   NakshatraRingWidget(controller: _ctrl, ...)
//   ListenableBuilder(listenable: _ctrl, builder: ...)
//   _ctrl.jumpToIndex(nIdx);  // jump wheel from outside

class NakshatraWheelController extends ChangeNotifier {
  static const int _n = 27;

  int _activeIndex = -1;
  int _todayIndex  = -1;
  int _birthIndex  = -1;

  /// Cumulative day offset tracked by boundary crossings.
  /// Forward crossing = +1, backward = −1.  Unbounded (no modulo wrap).
  int _cumulativeOffset = 0;

  /// Index of the nakshatra currently at 12 o'clock / top (−1 before first frame).
  int get activeIndex => _activeIndex;

  /// Today's Moon nakshatra index (−1 when not yet available).
  int get todayIndex => _todayIndex;

  /// User's birth Moon nakshatra index (−1 when no profile).
  int get birthIndex => _birthIndex;

  /// Signed day offset from today — unbounded (infinite scroll).
  int get dateOffsetFromToday => _cumulativeOffset;

  /// The calendar date currently shown at the top of the wheel.
  DateTime get displayedDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .add(Duration(days: _cumulativeOffset));
  }

  /// True when the wheel is at today's position.
  bool get isAtToday => _cumulativeOffset == 0;

  /// Days until the user's next Janma Day (0 = today, −1 = no birth data).
  int get daysUntilJanma {
    if (_birthIndex < 0 || _todayIndex < 0) return -1;
    return (_birthIndex - _todayIndex + _n) % _n;
  }

  /// True when today's Moon is on the birth star.
  bool get isJanmaDay =>
      _birthIndex >= 0 && _todayIndex >= 0 && _birthIndex == _todayIndex;

  // ── Internal API (called by NakshatraRingWidget only) ──────────────────────

  /// Written by the wheel's _onRotation on every boundary crossing.
  void _update({
    required int activeIndex,
    required int todayIndex,
    required int birthIndex,
    required int cumulativeOffset,
  }) {
    if (_activeIndex == activeIndex &&
        _todayIndex  == todayIndex  &&
        _birthIndex  == birthIndex  &&
        _cumulativeOffset == cumulativeOffset) return;
    _activeIndex = activeIndex;
    _todayIndex  = todayIndex;
    _birthIndex  = birthIndex;
    _cumulativeOffset = cumulativeOffset;
    notifyListeners();
  }

  /// Reset cumulative offset to zero (used by "Return to Today").
  void _resetOffset() {
    _cumulativeOffset = 0;
  }

  /// Stored by the wheel so external callers can animate the wheel.
  void Function(int)? _jumpCallback;

  /// Animate the wheel to the given nakshatra index.
  void jumpToIndex(int idx) => _jumpCallback?.call(idx);

  /// Jump the wheel to a specific day offset from today.
  void Function(int)? _jumpToOffsetCallback;

  /// Animate the wheel to a specific day offset from today.
  void jumpToOffset(int dayOffset) => _jumpToOffsetCallback?.call(dayOffset);
}

// =============================================================================

/// Interactive Nakshatra wheel with Tara Bala insights.
///
/// Features:
///  • Illustrated wheel image with color-coded Tara overlay ring
///  • Drag-to-rotate with momentum / fling physics
///  • Haptic ticks on segment boundaries during drag
///  • Pulsing Moon marker + birth-star marker (icons stay upright)
///  • Birth ↔ Today connection arc
///  • Janma Day golden glow when birth star = today's Moon
///  • "Why this vibe?" ⓘ sheet with Tara mechanics + nakshatra details
class NakshatraRingWidget extends StatefulWidget {
  final String? todayNakshatra;
  final String? birthNakshatra;
  final String? sunNakshatra;
  final String? lagnaNakshatra;
  /// Today's merged panchang/samvat map (same data source as CosmicDateTimeCard).
  /// Used to derive today's tithi and project it ±7 days across the forecast strip.
  final Map<String, dynamic>? todaySamvat;

  /// Called once every time the wheel **settles** on a new nakshatra (drag end,
  /// fling coast, or tap-to-jump animation complete).  The parent should write
  /// this date into the shared sky-chart [sliderDateNotifier].
  final ValueChanged<DateTime>? onDateChanged;

  /// When this [Listenable] fires (e.g. sky-chart "Today" button), the wheel
  /// animates back to today and fires [onDateChanged] with today's date.
  final Listenable? wheelResetSignal;

  /// Optional controller — receives live updates on every nakshatra boundary
  /// crossing during drag (not just on settle).  Enables independent cards
  /// elsewhere on the page to react to the wheel without being nested inside
  /// this widget.  The controller also exposes [NakshatraWheelController.jumpToIndex]
  /// so external widgets (e.g. the week forecast chips) can animate the wheel.
  final NakshatraWheelController? controller;

  /// Optional AI-generated daily insight. When the wheel is at today and an
  /// insight is available, the hero card uses [DailyInsight.displayMessage] as
  /// the narrative (richer than the static vibe template). On other days the
  /// card falls back to [DailyVibe.narrative].
  final DailyInsight? insight;

  /// When true, renders the wheel ABOVE the Daily Vibe card (desktop layouts
  /// where the wheel is the visual hero).  Default (false) keeps mobile-style
  /// vibe-first order: read the narrative, then look at the wheel beneath.
  final bool wheelFirst;

  const NakshatraRingWidget({
    super.key,
    this.todayNakshatra,
    this.birthNakshatra,
    this.sunNakshatra,
    this.lagnaNakshatra,
    this.todaySamvat,
    this.onDateChanged,
    this.wheelResetSignal,
    this.controller,
    this.insight,
    this.wheelFirst = false,
  });

  @override
  State<NakshatraRingWidget> createState() => _NakshatraRingWidgetState();
}

class _NakshatraRingWidgetState extends State<NakshatraRingWidget>
    with SingleTickerProviderStateMixin {
  // ─── Rotation ──────────────────────────────────────────────────────────────
  // Unbounded controller — value = angle in radians (grows without limit).
  late AnimationController _controller;
  Timer? _resumeTimer;
  bool _isDragging = false;
  double? _lastPanAngle;
  double _wheelDiameter = 0;

  // ─── Long-press magnifier ─────────────────────────────────────────────────
  Timer? _magnifyTimer;
  bool _isMagnified = false;
  Offset _magnifyOrigin = Offset.zero; // local position of the hold

  // ─── Selection (auto — always the nakshatra at 12 o'clock / top) ──────────
  int _currentBottomIndex = -1;  // field name kept for compatibility

  // ─── Geometry constants ────────────────────────────────────────────────────
  /// Angle of Ashwini's center, clockwise from 12 o'clock, in radians.
  /// Tune this to align the overlay with the artwork.
  static const double _ashwiniOffset = 0.41; // ≈ 24°
  static const int _count = 27;
  static const double _seg = 2 * pi / _count;

  static const double _selectedRingWidth = 5.0;
  static const double _ringGap = 2.0;

  // ─── Derived ───────────────────────────────────────────────────────────────
  // TODO: remove fallbacks once backend wiring is complete
  int get _todayIndex {
    final idx = NakshatraData.findIndex(widget.todayNakshatra);
    return idx >= 0 ? idx : 4; // fallback: Mrigashira (for UI preview)
  }

  int get _birthIndex {
    final idx = NakshatraData.findIndex(widget.birthNakshatra);
    return idx >= 0 ? idx : 16; // fallback: Anuradha (for UI preview)
  }

  int get _sunIndex {
    final idx = NakshatraData.findIndex(widget.sunNakshatra);
    return idx >= 0 ? idx : 9; // fallback: Magha (for UI preview)
  }

  int get _lagnaIndex {
    final idx = NakshatraData.findIndex(widget.lagnaNakshatra);
    return idx >= 0 ? idx : 21; // fallback: Shravana (for UI preview)
  }

  int get _activeIndex =>
      _currentBottomIndex >= 0 ? _currentBottomIndex : _todayIndex;
  bool get _isJanmaDay =>
      _birthIndex >= 0 && _todayIndex >= 0 && _birthIndex == _todayIndex;

  // ─── Cumulative offset tracking ─────────────────────────────────────────────
  //
  // Instead of deriving dates from the modulo-27 nakshatra index (which wraps
  // after one lunar cycle), we track cumulative boundary crossings.  Each
  // forward crossing = +1 day, each backward = −1 day.  This gives infinite
  // scrolling — the date keeps going forward/backward without wrapping.

  /// Cumulative day offset from today.  Incremented/decremented on every
  /// nakshatra boundary crossing.
  int _cumulativeOffset = 0;

  /// True while animating back to today — suppresses cumulative offset
  /// tracking in [_onRotation] so intermediate boundary crossings don't
  /// overwrite the reset.
  bool _isReturningToToday = false;

  int get _dateOffsetFromToday => _cumulativeOffset;

  /// The date currently shown at the top of the wheel.
  DateTime get _displayedDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .add(Duration(days: _cumulativeOffset));
  }

  /// True when the wheel is at today's position (default state).
  bool get _isAtToday => _cumulativeOffset == 0;

  /// Days until the user's next Janma Day (Moon returning to birth star).
  /// Returns 0 today, 1 tomorrow, etc.  Returns -1 when birth data missing.
  int get _daysUntilJanma {
    if (_birthIndex < 0 || _todayIndex < 0) return -1;
    return (_birthIndex - _todayIndex + 27) % 27;
  }

  /// "May 17"-style short date.
  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  /// Animate the wheel back to today's position via the shortest arc.
  void _returnToToday() {
    HapticFeedback.selectionClick();
    _stopAll();
    final todayAngle = -_ashwiniOffset + _todayIndex * _seg;
    final current = _controller.value;
    // Shortest-arc delta in (−π, π]
    final twoPi = 2 * pi;
    final delta = ((todayAngle - current) % twoPi + twoPi + pi) % twoPi - pi;
    // Reset cumulative offset — we're going back to today.
    // Flag suppresses _onRotation from overwriting during animation.
    _cumulativeOffset = 0;
    _isReturningToToday = true;
    widget.controller?._resetOffset();
    _controller
        .animateTo(
          current + delta,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          _isReturningToToday = false;
          _cumulativeOffset = 0; // ensure clean after animation
          if (mounted) widget.onDateChanged?.call(_displayedDate);
        });
  }

  /// Animate the wheel so the given nakshatra index sits at the top.
  /// Also updates the cumulative offset based on the shortest-arc jump
  /// relative to the current position.
  void _jumpToIndex(int targetIdx) {
    if (targetIdx < 0 || targetIdx >= _count) return;
    HapticFeedback.selectionClick();
    _stopAll();

    // Compute the signed segment jump (shortest arc) for cumulative offset.
    if (_currentBottomIndex >= 0) {
      final fwd = (targetIdx - _currentBottomIndex + _count) % _count;
      final bwd = ((_currentBottomIndex - targetIdx + _count) % _count);
      if (fwd <= bwd) {
        _cumulativeOffset += fwd;
      } else {
        _cumulativeOffset -= bwd;
      }
    }

    final targetAngle = -_ashwiniOffset + targetIdx * _seg;
    final current = _controller.value;
    final twoPi = 2 * pi;
    final delta = ((targetAngle - current) % twoPi + twoPi + pi) % twoPi - pi;
    _controller
        .animateTo(
          current + delta,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (mounted) widget.onDateChanged?.call(_displayedDate);
        });
  }

  /// Jump the wheel to a specific day offset from today.
  /// Used by the sky chart slider to sync the wheel to an arbitrary date.
  void _jumpToOffset(int dayOffset) {
    // Compute the target nakshatra index for this offset.
    final targetIdx = (_todayIndex + dayOffset % _count + _count) % _count;
    if (targetIdx < 0 || targetIdx >= _count) return;
    HapticFeedback.selectionClick();
    _stopAll();

    // Set cumulative offset directly — we know exactly where we're going.
    _cumulativeOffset = dayOffset;

    final targetAngle = -_ashwiniOffset + targetIdx * _seg;
    final current = _controller.value;
    final twoPi = 2 * pi;
    final delta = ((targetAngle - current) % twoPi + twoPi + pi) % twoPi - pi;
    _controller
        .animateTo(
          current + delta,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (mounted) widget.onDateChanged?.call(_displayedDate);
        });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    // Place today's nakshatra at 12 o'clock (top).
    final target = -_ashwiniOffset + _todayIndex * _seg;
    _controller = AnimationController.unbounded(vsync: this, value: target);
    _controller.addListener(_onRotation);
    _currentBottomIndex = _nakshatraAtTop();

    // Listen for external "return to today" signals (e.g. sky-chart Today button).
    widget.wheelResetSignal?.addListener(_onExternalResetToToday);

    // Wire the controller: let it call _jumpToIndex and seed its initial state.
    // Seeding is deferred to the first frame so notifyListeners() never fires
    // during the build phase (which would throw a Flutter assertion).
    if (widget.controller != null) {
      widget.controller!._jumpCallback = _jumpToIndex;
      widget.controller!._jumpToOffsetCallback = _jumpToOffset;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.controller?._update(
            activeIndex: _activeIndex,
            todayIndex: _todayIndex,
            birthIndex: _birthIndex,
            cumulativeOffset: _cumulativeOffset,
          );
        }
      });
    }

  }

  @override
  void didUpdateWidget(NakshatraRingWidget old) {
    super.didUpdateWidget(old);
    if (old.wheelResetSignal != widget.wheelResetSignal) {
      old.wheelResetSignal?.removeListener(_onExternalResetToToday);
      widget.wheelResetSignal?.addListener(_onExternalResetToToday);
    }
    // Keep the controller's jump callback current when the controller instance
    // is swapped (rare in practice but required for correctness).
    if (old.controller != widget.controller) {
      old.controller?._jumpCallback = null;
      old.controller?._jumpToOffsetCallback = null;
      if (widget.controller != null) {
        widget.controller!._jumpCallback = _jumpToIndex;
        widget.controller!._jumpToOffsetCallback = _jumpToOffset;
        widget.controller!._update(
          activeIndex: _activeIndex,
          todayIndex: _todayIndex,
          birthIndex: _birthIndex,
          cumulativeOffset: _cumulativeOffset,
        );
      }
    }
  }

  @override
  void dispose() {
    widget.wheelResetSignal?.removeListener(_onExternalResetToToday);
    _controller.removeListener(_onRotation);
    _resumeTimer?.cancel();
    _magnifyTimer?.cancel();
    _controller.dispose();
    // Null out the jump callbacks so a disposed widget is never called.
    widget.controller?._jumpCallback = null;
    widget.controller?._jumpToOffsetCallback = null;
    super.dispose();
  }

  /// Called when the parent fires [wheelResetSignal] — snap wheel back to today.
  void _onExternalResetToToday() {
    if (!mounted) return;
    _returnToToday();
  }

  /// Fires on every animation tick — update bottom selection + haptic.
  /// Also pushes live state to the controller so listeners (sky chart,
  /// standalone mood/forecast cards) react during drag, not just on settle.
  ///
  /// Tracks cumulative boundary crossings for infinite date scrolling:
  /// each forward crossing increments _cumulativeOffset, backward decrements.
  void _onRotation() {
    final seg = _nakshatraAtTop();
    if (seg != _currentBottomIndex && seg >= 0) {
      if (_isDragging) HapticFeedback.lightImpact();

      // Track direction of boundary crossing for cumulative offset.
      // Skip during return-to-today animation — offset is already reset
      // and intermediate crossings would corrupt it.
      if (_currentBottomIndex >= 0 && !_isReturningToToday) {
        final prev = _currentBottomIndex;
        // Detect forward vs backward crossing (handles the 26→0 / 0→26 wrap).
        final forwardDelta = (seg - prev + _count) % _count;
        final backwardDelta = (prev - seg + _count) % _count;
        if (forwardDelta <= backwardDelta) {
          // Forward crossing(s) — usually 1, but fling might skip segments.
          _cumulativeOffset += forwardDelta;
        } else {
          // Backward crossing(s).
          _cumulativeOffset -= backwardDelta;
        }
      }

      setState(() => _currentBottomIndex = seg);
      // Push live update to controller — fires on every nakshatra boundary
      // crossing, enabling the sky chart to move in real time during drag.
      widget.controller?._update(
        activeIndex: _activeIndex,
        todayIndex: _todayIndex,
        birthIndex: _birthIndex,
        cumulativeOffset: _cumulativeOffset,
      );
    }
  }

  /// Which nakshatra is at the 12 o'clock (top) position right now.
  int _nakshatraAtTop() {
    final rotRad = _controller.value % (2 * pi);
    // Top = 0 (no π offset)
    double imgAngle = (4 * pi - rotRad) % (2 * pi);
    double fromAsh = (_ashwiniOffset - imgAngle + 2 * pi) % (2 * pi);
    return (fromAsh / _seg).round() % _count;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Rotation control
  // ═══════════════════════════════════════════════════════════════════════════

  void _stopAll() {
    _controller.stop();
    _resumeTimer?.cancel();
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Long-press magnifier (raw pointer events — no gesture conflict)
  // Hold still for 300 ms → zoom in; lift finger → zoom out.
  // ═══════════════════════════════════════════════════════════════════════════

  void _onPointerDown(PointerDownEvent e) {
    _magnifyOrigin = e.localPosition;
    _magnifyTimer?.cancel();
    _magnifyTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _isMagnified = true);
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    // If the finger moved > 10 px it's a drag, cancel magnify.
    if (!_isMagnified &&
        (e.localPosition - _magnifyOrigin).distance > 10) {
      _magnifyTimer?.cancel();
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _magnifyTimer?.cancel();
    if (_isMagnified) setState(() => _isMagnified = false);
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _magnifyTimer?.cancel();
    if (_isMagnified) setState(() => _isMagnified = false);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Pan handling (drag-to-rotate with momentum)
  // Haptic feedback is handled in _onRotation when segment changes.
  // ═══════════════════════════════════════════════════════════════════════════

  void _handlePanStart(DragStartDetails details) {
    _isDragging = true;
    _stopAll();

    final cx = _wheelDiameter / 2;
    final dx = details.localPosition.dx - cx;
    final dy = details.localPosition.dy - cx;
    _lastPanAngle = atan2(dx, -dy);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_lastPanAngle == null || _wheelDiameter <= 0) return;

    final cx = _wheelDiameter / 2;
    final dx = details.localPosition.dx - cx;
    final dy = details.localPosition.dy - cx;
    final currentAngle = atan2(dx, -dy);

    double delta = currentAngle - _lastPanAngle!;
    if (delta > pi) delta -= 2 * pi;
    if (delta < -pi) delta += 2 * pi;
    _lastPanAngle = currentAngle;

    // Heavy-disc feel: ~35% drag resistance so the wheel doesn't spin too easily.
    _controller.value += delta * 0.65;
  }

  void _handlePanEnd(DragEndDetails details) {
    _isDragging = false;
    final touchAngle = _lastPanAngle;
    _lastPanAngle = null;

    if (touchAngle == null || _wheelDiameter <= 0) {
      _scheduleResume();
      return;
    }

    final r = _wheelDiameter / 2;
    final v = details.velocity.pixelsPerSecond;
    // Tangential velocity at the last touch point
    final tangentialVel = v.dx * cos(touchAngle) + v.dy * sin(touchAngle);
    final angularVel = tangentialVel / r;

    // Higher threshold (0.7) and shorter throw (0.32) give a heavy-disc coast.
    if (angularVel.abs() > 0.7) {
      // Fling with deceleration
      final ms = (angularVel.abs() * 500).clamp(250.0, 1400.0);
      final flingAngle = angularVel * ms / 1000 * 0.32;

      _controller
          .animateTo(
            _controller.value + flingAngle,
            duration: Duration(milliseconds: ms.toInt()),
            curve: Curves.decelerate,
          )
          .whenComplete(() {
            if (mounted) {
              _scheduleResume();
              widget.onDateChanged?.call(_displayedDate);
            }
          });
    } else {
      _scheduleResume();
      widget.onDateChanged?.call(_displayedDate);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    final vibeCard = _buildDailyVibeCard(c, isDark, cardColor);
    final wheel = _buildWheel(c, isDark);
    const gap = SizedBox(height: AppDimensions.spacingMd);

    return Column(
      children: widget.wheelFirst
          ? [wheel, gap, vibeCard]
          : [vibeCard, gap, wheel],
      // Mood check-in + Week forecast have been extracted to standalone
      // NakshatraMoodCheckInCard / NakshatraWeekForecastCard widgets and
      // placed at the bottom of HolyCowCosmicContent so they are independent
      // cards on the page — not buried inside the wheel widget.
    );
  }

  // ─── Daily Vibe card ───────────────────────────────────────────────────
  //
  // Plain-English guidance derived from today's Tara Bala.
  // Styled to match the other dashboard cards (Material, flat, text-focused).

  Widget _buildDailyVibeCard(Color c, bool isDark, Color cardColor) {
    // No birth data yet → invite the user to set it up.
    if (_birthIndex < 0) {
      return _buildVibeEmptyState(c, isDark, cardColor);
    }

    // The vibe is driven by whatever's at the bottom of the wheel — so
    // dragging the wheel becomes a "what does <other day> look like?"
    // exploration affordance.
    final activeIdx = _activeIndex;
    final vibe = DailyVibe.forUser(
      birthIndex: _birthIndex,
      todayIndex: activeIdx,
    );
    if (vibe == null) return _buildVibeEmptyState(c, isDark, cardColor);

    final tara = TaraBala.calculate(_birthIndex, activeIdx);
    final activeInfo = NakshatraData.getInfo(activeIdx);
    final isAtToday = _isAtToday;
    final isJanmaActive =
        _birthIndex >= 0 && activeIdx == _birthIndex;
    // Narrative: AI insight on today, static vibe template otherwise.
    final aiMessage = widget.insight?.displayMessage ?? '';
    final useInsight = isAtToday && aiMessage.isNotEmpty;
    final narrativeText = useInsight ? aiMessage : vibe.narrative;

    // Subtitle: "Mrigashira · Sampat Tara" or "Mrigashira · Janma Day"
    final subtitle = <String>[
      if (activeInfo != null) activeInfo.name,
      isJanmaActive ? 'Janma Day' : tara.name,
    ].join(' · ');

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vibe label
            Text(
              vibe.label,
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize + 4,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),

            // Nakshatra · Tara subtitle
            Text(
              subtitle,
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize - 1,
                fontWeight: FontWeight.w500,
                color: c.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),

            // Narrative
            Text(
              narrativeText,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w400,
                color: c.withValues(alpha: 0.75),
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
          ],
        ),
      ),
    );
  }

  /// Empty-state card shown when birth nakshatra isn't available.
  Widget _buildVibeEmptyState(Color c, bool isDark, Color cardColor) {
    final todayInfo = NakshatraData.getInfo(_todayIndex);
    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          border: Border.all(
            color: c.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('☽', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    todayInfo != null
                        ? 'Today\'s Moon is in ${todayInfo.name}'
                        : 'Today\'s Sky',
                    style: TextStyle(
                      fontSize: AppTheme.holyCowTextSize + 2,
                      fontWeight: FontWeight.w700,
                      color: c,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Add your birth date & time to unlock a personalised daily '
              'energy reading — how today\'s sky interacts with your birth star.',
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                color: c.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a bottom sheet that demystifies the vibe — shows the
  /// underlying Tara, the calculation, and reminds the user that this
  /// is a guide, not a horoscope.  Helps build trust over time.
  void _showWhyThisVibeSheet({
    required Color c,
    required bool isDark,
    required Color cardColor,
    required DailyVibe vibe,
    required TaraBala tara,
    required NakshatraInfo? activeInfo,
    required Color accent,
    required bool isAtToday,
  }) {
    HapticFeedback.selectionClick();
    final birthInfo = NakshatraData.getInfo(_birthIndex);
    final distance =
        ((_activeIndex - _birthIndex + 27) % 27); // 0..26
    final taraSlotIndex = (distance % 9) + 1; // 1..9 for display

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (sheetCtx) {
        Widget step(String num, String title, String body) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      num,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: AppTheme.holyCowTextSize,
                            fontWeight: FontWeight.w700,
                            color: c.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: AppTheme.holyCowTextSize - 1,
                            fontWeight: FontWeight.w400,
                            color: c.withValues(alpha: 0.65),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingLg,
              AppDimensions.paddingMd,
              AppDimensions.paddingLg,
              AppDimensions.paddingLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grabber handle.
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title row.
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        vibe.icon,
                        size: 20,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Why ${vibe.label}?',
                            style: TextStyle(
                              fontSize: AppTheme.holyCowTextSize + 4,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                          Text(
                            isAtToday
                                ? 'Today\'s reading explained'
                                : 'Reading explained',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: c.withValues(alpha: 0.5),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacingLg),

                // The three-step explanation.
                step(
                  '1',
                  'Your birth star',
                  birthInfo != null
                      ? '${birthInfo.name} — the nakshatra the Moon occupied when you were born.'
                      : 'The nakshatra the Moon occupied when you were born.',
                ),
                step(
                  '2',
                  'The Moon\'s current star',
                  activeInfo != null
                      ? '${activeInfo.name} — where the Moon sits ${isAtToday ? "today" : "on ${_formatDate(_displayedDate)}"}.'
                      : 'Where the Moon sits ${isAtToday ? "today" : "on ${_formatDate(_displayedDate)}"}.',
                ),
                step(
                  '3',
                  'Tara Bala distance',
                  'Counting from your birth star to the Moon\'s star gives '
                      'a 1–9 slot. Slot $taraSlotIndex = ${tara.name} '
                      '(${tara.meaning}).',
                ),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WHAT IT MEANS FOR YOU',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tara.guidance,
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          fontWeight: FontWeight.w400,
                          color: c.withValues(alpha: 0.8),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Nakshatra details ──
                if (activeInfo != null) ...[
                  const SizedBox(height: AppDimensions.spacingMd),
                  Divider(color: c.withValues(alpha: 0.08), height: 1),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Text(
                    activeInfo.title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: c.withValues(alpha: 0.4),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activeInfo.description,
                    style: TextStyle(
                      fontSize: AppTheme.holyCowTextSize,
                      fontWeight: FontWeight.w400,
                      color: c.withValues(alpha: 0.75),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  // Ruler / Deity / Nature
                  Row(children: [
                    _meta('Ruler', activeInfo.ruler, c),
                    _dot(c),
                    _meta('Deity', activeInfo.deity, c),
                    _dot(c),
                    _meta('Nature', activeInfo.nature, c),
                  ]),
                  // Next nakshatra preview (today only)
                  if (isAtToday) ...[
                    const SizedBox(height: AppDimensions.spacingMd),
                    Builder(builder: (context) {
                      final nextIdx = (_activeIndex + 1) % 27;
                      final nextInfo = NakshatraData.getInfo(nextIdx);
                      final nextTara = _birthIndex >= 0
                          ? TaraBala.calculate(_birthIndex, nextIdx)
                          : null;
                      if (nextInfo == null) return const SizedBox.shrink();
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingMd,
                          vertical: AppDimensions.paddingSm,
                        ),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: isDark ? 0.06 : 0.03),
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Text.rich(TextSpan(children: [
                          TextSpan(
                            text: 'Next: ${nextInfo.name}',
                            style: TextStyle(
                              fontSize: AppTheme.holyCowTextSize - 1,
                              fontWeight: FontWeight.w600,
                              color: c.withValues(alpha: 0.5),
                            ),
                          ),
                          TextSpan(
                            text: '  ·  ~24hrs',
                            style: TextStyle(
                              fontSize: AppTheme.holyCowTextSize - 1,
                              fontWeight: FontWeight.w400,
                              color: c.withValues(alpha: 0.35),
                            ),
                          ),
                          if (nextTara != null) ...[
                            TextSpan(
                              text: '\nYour Tara shifts to: ${nextTara.name}',
                              style: TextStyle(
                                fontSize: AppTheme.holyCowTextSize - 1,
                                fontWeight: FontWeight.w500,
                                color: _taraColor(nextTara.isFavorable, isDark),
                              ),
                            ),
                            TextSpan(
                              text: nextTara.isFavorable ? ' ✓' : ' ⚠',
                              style: TextStyle(
                                fontSize: 11,
                                color: _taraAccent(nextTara.isFavorable),
                              ),
                            ),
                          ],
                        ])),
                      );
                    }),
                  ],
                ],

                const SizedBox(height: AppDimensions.spacingMd),

                // Disclaimer footer.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: c.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A gentle nudge — not a verdict. Trust what '
                        'lands for you and let the rest go.',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: c.withValues(alpha: 0.5),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Wheel ─────────────────────────────────────────────────────────────────

  /// Maximum wheel diameter on wide layouts. The wheel is decorative — past
  /// ~480px it stops feeling like a piece of UI and starts feeling like a
  /// poster. Keep it tight on desktop and center it within the available width.
  static const double _maxWheelDiameter = 480.0;

  Widget _buildWheel(Color c, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(builder: (context, constraints) {
        final total = constraints.maxWidth.clamp(0.0, _maxWheelDiameter);
        _wheelDiameter = total;
        final imgDia = total - 2 * (_selectedRingWidth + _ringGap);

        // Magnify origin as fraction of wheel size (for alignment).
        final magAlignX = _wheelDiameter > 0
            ? (_magnifyOrigin.dx / _wheelDiameter) * 2 - 1
            : 0.0;
        final magAlignY = _wheelDiameter > 0
            ? (_magnifyOrigin.dy / _wheelDiameter) * 2 - 1
            : 0.0;

        return Center(child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: RawGestureDetector(
          gestures: <Type, GestureRecognizerFactory>{
            _EagerPanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<_EagerPanGestureRecognizer>(
              _EagerPanGestureRecognizer.new,
              (_EagerPanGestureRecognizer instance) {
                instance
                  ..onStart = _handlePanStart
                  ..onUpdate = _handlePanUpdate
                  ..onEnd = _handlePanEnd;
              },
            ),
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: _isMagnified ? 2.2 : 1.0,
            alignment: Alignment(magAlignX.clamp(-1.0, 1.0), magAlignY.clamp(-1.0, 1.0)),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: SizedBox(
            width: total,
            height: total,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final angle = _controller.value;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Rotating layer (image + tara ring)
                    Transform.rotate(angle: angle, child: child),
                    // Markers — positioned in screen-space so icons stay upright
                    ..._buildMarkers(total, c, angle, isDark),
                    // Top indicator — fixed arrow above the ring, points down
                    Positioned(
                      top: -30,
                      left: total / 2 - 16,
                      child: Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 32,
                        color: c.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: imgDia,
                    height: imgDia,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/nakshatra_wheel.jpeg',
                        fit: BoxFit.cover,
                        width: imgDia,
                        height: imgDia,
                        gaplessPlayback: true,
                        frameBuilder: (context, child, frame, loaded) {
                          if (loaded) return child;
                          return AnimatedOpacity(
                            opacity: frame != null ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: child,
                          );
                        },
                      ),
                    ),
                  ),
                  CustomPaint(
                    size: Size(total, total),
                    painter: _TaraRingPainter(
                      birthIndex: _birthIndex,
                      todayIndex: _todayIndex,
                      selectedIndex: _activeIndex,
                      primaryColor: c,
                      isDark: isDark,
                      isJanmaDay: _isJanmaDay,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        )),
        );
      }),
    );
  }

  // ─── Markers (icons stay upright) ──────────────────────────────────────────

  List<Widget> _buildMarkers(
      double diameter, Color c, double rotAngle, bool isDark) {
    final markers = <Widget>[];
    final radius = diameter / 2 - _selectedRingWidth / 2;

    // Marker icon helper — adds a subtle shadow so icons pop on any ring color.
    Widget markerIcon(IconData icon, double size, Color color) {
      return Icon(
        icon,
        size: size,
        color: color,
        shadows: [
          Shadow(
            color: (isDark ? Colors.black : Colors.black54),
            blurRadius: 3,
          ),
        ],
      );
    }

    // Today marker — pulsing blue dot (same style as muhurat timeline)
    if (_todayIndex >= 0) {
      const size = 15.0;
      final nAngle = _ashwiniOffset - _todayIndex * _seg;
      final vAngle = nAngle + rotAngle;
      final x = diameter / 2 + radius * sin(vAngle) - size / 2;
      final y = diameter / 2 - radius * cos(vAngle) - size / 2;
      markers.add(Positioned(
        left: x,
        top: y,
        child: const PulsingDot(
          size: size,
          borderWidth: 1.5,
        ),
      ));
    }

    // Birth moon nakshatra marker — moon icon
    if (_birthIndex >= 0 && _birthIndex != _todayIndex) {
      const size = 20.0;
      final nAngle = _ashwiniOffset - _birthIndex * _seg;
      final vAngle = nAngle + rotAngle;
      final x = diameter / 2 + radius * sin(vAngle) - size / 2;
      final y = diameter / 2 - radius * cos(vAngle) - size / 2;
      final moonColor = isDark
          ? Colors.white.withValues(alpha: 0.9)
          : const Color(0xFF1565C0); // vivid blue in light
      markers.add(Positioned(
        left: x,
        top: y,
        child: markerIcon(Icons.nightlight_round, size, moonColor),
      ));
    }

    // Sun marker
    if (_sunIndex >= 0) {
      const size = 20.0;
      final nAngle = _ashwiniOffset - _sunIndex * _seg;
      final vAngle = nAngle + rotAngle;
      final x = diameter / 2 + radius * sin(vAngle) - size / 2;
      final y = diameter / 2 - radius * cos(vAngle) - size / 2;
      final sunColor = isDark
          ? const Color(0xFFFFD700).withValues(alpha: 0.9)
          : const Color(0xFFFF6D00); // bright orange in light
      markers.add(Positioned(
        left: x,
        top: y,
        child: markerIcon(Icons.wb_sunny_rounded, size, sunColor),
      ));
    }

    // Lagna (Ascendant) marker
    if (_lagnaIndex >= 0) {
      const size = 20.0;
      final nAngle = _ashwiniOffset - _lagnaIndex * _seg;
      final vAngle = nAngle + rotAngle;
      final x = diameter / 2 + radius * sin(vAngle) - size / 2;
      final y = diameter / 2 - radius * cos(vAngle) - size / 2;
      final lagnaColor = isDark
          ? Colors.white.withValues(alpha: 0.85)
          : const Color(0xFF7B1FA2); // vivid purple in light
      markers.add(Positioned(
        left: x,
        top: y,
        child: markerIcon(Icons.change_history_rounded, size, lagnaColor),
      ));
    }

    return markers;
  }

  // ─── Small helpers ─────────────────────────────────────────────────────────

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
          border: Border.all(color: bg.withValues(alpha: 0.2)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.8)),
      );

  Widget _meta(String label, String value, Color c) => Expanded(
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: c.withValues(alpha: 0.35),
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: AppTheme.holyCowTextSize,
                  fontWeight: FontWeight.w600,
                  color: c.withValues(alpha: 0.7))),
        ]),
      );

  Widget _dot(Color c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('·', style: TextStyle(color: c.withValues(alpha: 0.2))),
      );

  Color _taraColor(bool favorable, bool isDark) => favorable
      ? (isDark ? const Color(0xFF81C784) : const Color(0xFF388E3C))
      : (isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828));

  Color _taraAccent(bool favorable) =>
      favorable ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
}

// =============================================================================
// NakshatraMoodCheckInCard
// =============================================================================
//
// Standalone daily mood check-in card.  Listens to [NakshatraWheelController]
// and shows only when the wheel is at today's position and birth data is
// available.  Owns its own [MoodLog] so it can live anywhere on the page.

class NakshatraMoodCheckInCard extends StatefulWidget {
  final NakshatraWheelController controller;

  const NakshatraMoodCheckInCard({super.key, required this.controller});

  @override
  State<NakshatraMoodCheckInCard> createState() =>
      _NakshatraMoodCheckInCardState();
}

class _NakshatraMoodCheckInCardState extends State<NakshatraMoodCheckInCard> {
  final MoodLog _moodLog = MoodLog();
  bool _moodLogReady = false;

  @override
  void initState() {
    super.initState();
    _moodLog.load().then((_) {
      if (!mounted) return;
      setState(() => _moodLogReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use a single AnimatedSize so Flutter can smoothly animate between the
    // shown and hidden states without replacing the widget instance.
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final show = widget.controller.birthIndex >= 0 &&
            widget.controller.isAtToday &&
            _moodLogReady;
        final c = AppTheme.primaryColor;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor =
            isDark ? Theme.of(context).colorScheme.surface : Colors.white;

        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: show
              ? _buildContent(c, isDark, cardColor)
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }

  Widget _buildContent(Color c, bool isDark, Color cardColor) {
    final logged = _moodLog.todayMood;
    final streak = _moodLog.streak;

    return Material(
      color: cardColor,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMd,
          vertical: AppDimensions.paddingMd,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          border: Border.all(color: c.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: prompt + streak chip ──
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      logged != null
                          ? 'HOW TODAY FEELS'
                          : 'HOW DOES TODAY FEEL?',
                      key: ValueKey(logged != null),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: c.withValues(alpha: 0.5),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (streak > 0) _streakChip(streak),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),

            // ── Emoji row ──
            Row(
              children: kMoodOptions.map((opt) {
                final isSelected = logged == opt.mood;
                return Expanded(
                    child: _moodChip(
                  option: opt,
                  isSelected: isSelected,
                  c: c,
                  isDark: isDark,
                ));
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moodChip({
    required MoodOption option,
    required bool isSelected,
    required Color c,
    required bool isDark,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        HapticFeedback.lightImpact();
        await _moodLog.setToday(option.mood);
        if (!mounted) return;
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? option.color.withValues(alpha: isDark ? 0.20 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: isSelected
              ? Border.all(
                  color: option.color.withValues(alpha: 0.5),
                  width: 1.0,
                )
              : Border.all(color: Colors.transparent, width: 1.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.18 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Text(
                option.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              option.label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? option.color
                    : c.withValues(alpha: 0.55),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _streakChip(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6F00).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(
          color: const Color(0xFFFF6F00).withValues(alpha: 0.30),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 13,
            color: const Color(0xFFE65100),
          ),
          const SizedBox(width: 4),
          Text(
            '$streak day${streak == 1 ? "" : "s"}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE65100),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// NakshatraWeekForecastCard
// =============================================================================
//
// Standalone 7-day Tara forecast strip.  Listens to [NakshatraWheelController]
// and hides when birth data is unavailable.  Chips call
// [NakshatraWheelController.jumpToIndex] to animate the wheel to that day.

class NakshatraWeekForecastCard extends StatelessWidget {
  final NakshatraWheelController controller;

  /// Today's merged panchang/samvat — used to derive today's tithi and
  /// project it ±7 days across the forecast strip.
  final Map<String, dynamic>? todaySamvat;

  const NakshatraWeekForecastCard({
    super.key,
    required this.controller,
    this.todaySamvat,
  });

  // ── Tithi helpers ────────────────────────────────────────────────────────

  static int? _todayTithiIndex(Map<String, dynamic>? samvat) {
    if (samvat == null) return null;
    final rawNum = samvat['number'] ??
        samvat['tithi_number'] ??
        samvat['tithiNumber'];
    int? tithiNum;
    if (rawNum is num) {
      tithiNum = rawNum.toInt();
    } else if (rawNum != null) {
      tithiNum = int.tryParse(rawNum.toString());
    }
    if (tithiNum == null) return null;
    if (tithiNum > 15) return tithiNum.clamp(16, 30);
    final rawPaksha = samvat['paksha']?.toString() ??
        samvat['tithiPaksha']?.toString() ??
        '';
    final isKrishna = rawPaksha.toLowerCase().contains('krishna') ||
        rawPaksha.toLowerCase().contains('krsna');
    return isKrishna ? (tithiNum + 15).clamp(16, 30) : tithiNum.clamp(1, 15);
  }

  static String _tithiLabel(int unified) {
    assert(unified >= 1 && unified <= 30);
    if (unified == 15) return 'Purni';
    if (unified == 30) return 'Amav';
    if (unified <= 14) return 'S·$unified';
    return 'K·${unified - 15}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.birthIndex < 0) return const SizedBox.shrink();

        final c = AppTheme.primaryColor;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor =
            isDark ? Theme.of(context).colorScheme.surface : Colors.white;

        return _buildContent(context, c, isDark, cardColor);
      },
    );
  }

  Widget _buildContent(
      BuildContext context, Color c, bool isDark, Color cardColor) {
    const dayGlyphs = ['☉', '☽', '♂', '☿', '♃', '♀', '♄'];
    const dayLabels = [
      'Ravi',
      'Soma',
      'Mangal',
      'Budh',
      'Guru',
      'Shukra',
      'Shani'
    ];
    final now = DateTime.now();
    final todayTithi = _todayTithiIndex(todaySamvat);
    final birthIndex = controller.birthIndex;
    final todayIdx = controller.todayIndex;
    final activeIdx = controller.activeIndex;
    final daysUntilJanma = controller.daysUntilJanma;
    final isJanmaDay = controller.isJanmaDay;
    const count = 27;

    return Material(
      color: cardColor,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingSm,
          vertical: AppDimensions.paddingSm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          border: Border.all(color: c.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Row(
                children: [
                  Text(
                    'AGAMI SAPTAH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: c.withValues(alpha: 0.4),
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (!isJanmaDay &&
                      daysUntilJanma > 0 &&
                      daysUntilJanma <= 13) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '·',
                        style: TextStyle(color: c.withValues(alpha: 0.25)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => controller.jumpToIndex(birthIndex),
                      child: Text(
                        daysUntilJanma == 1
                            ? 'Janma Day tomorrow'
                            : 'Janma Day in $daysUntilJanma days',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB8860B),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final date = now.add(Duration(days: i));
                final nIdx = (todayIdx + i) % count;
                final vibe = DailyVibe.forUser(
                  birthIndex: birthIndex,
                  todayIndex: nIdx,
                );
                if (vibe == null) return const SizedBox.shrink();
                final accent = vibeAccent(vibe.tone, isDark: isDark);
                final isFocused = nIdx == activeIdx;
                final dayIdx = date.weekday % 7;
                final dayLabel = dayLabels[dayIdx];
                final dayGlyph = dayGlyphs[dayIdx];
                final isBestDay = vibe.tone == VibeTone.flow;
                final String? chipTithi = todayTithi != null
                    ? _tithiLabel(((todayTithi - 1 + i) % 30) + 1)
                    : null;

                return Expanded(
                  child: _forecastChip(
                    dayLabel: dayLabel,
                    dayGlyph: dayGlyph,
                    dayNum: date.day.toString(),
                    tithiLabel: chipTithi,
                    icon: vibe.icon,
                    accent: accent,
                    isFocused: isFocused,
                    isToday: i == 0,
                    isBestDay: isBestDay,
                    c: c,
                    isDark: isDark,
                    onTap: () => controller.jumpToIndex(nIdx),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _forecastChip({
    required String dayLabel,
    required String dayGlyph,
    required String dayNum,
    required IconData icon,
    required Color accent,
    required bool isFocused,
    required bool isToday,
    required bool isBestDay,
    required Color c,
    required bool isDark,
    required VoidCallback onTap,
    String? tithiLabel,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              color: isBestDay
                  ? const Color(0xFFFFD700).withValues(
                      alpha: isDark
                          ? (isFocused ? 0.22 : 0.10)
                          : (isFocused ? 0.16 : 0.06))
                  : (isFocused
                      ? accent.withValues(alpha: isDark ? 0.20 : 0.12)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: isBestDay
                  ? Border.all(
                      color: const Color(0xFFFFD700)
                          .withValues(alpha: isFocused ? 0.55 : 0.30),
                      width: isFocused ? 1.0 : 0.8,
                    )
                  : (isToday && !isFocused
                      ? Border.all(
                          color: c.withValues(alpha: 0.25), width: 0.8)
                      : null),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dayGlyph,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                    color: isBestDay
                        ? const Color(0xFFB8860B)
                        : (isFocused ? accent : c.withValues(alpha: 0.45)),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    dayLabel,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isBestDay
                          ? const Color(0xFFB8860B)
                          : (isFocused ? accent : c.withValues(alpha: 0.55)),
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayNum,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isBestDay
                        ? const Color(0xFFB8860B)
                        : (isFocused ? accent : c.withValues(alpha: 0.80)),
                  ),
                ),
                if (tithiLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    tithiLabel,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: isBestDay
                          ? const Color(0xFFB8860B)
                          : (isFocused
                              ? accent.withValues(alpha: 0.85)
                              : c.withValues(alpha: 0.40)),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Icon(
                  icon,
                  size: 16,
                  color: isBestDay
                      ? const Color(0xFFB8860B)
                      : (isFocused ? accent : c.withValues(alpha: 0.45)),
                ),
              ],
            ),
          ),
          if (isBestDay)
            Positioned(
              top: -4,
              right: -2,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFFFFD700).withValues(alpha: 0.45),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 11,
                  color: Color(0xFF7A5C00),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Tara ring painter
// =============================================================================

class _TaraRingPainter extends CustomPainter {
  final int birthIndex;
  final int todayIndex;
  final int selectedIndex;
  final Color primaryColor;
  final bool isDark;
  final bool isJanmaDay;

  _TaraRingPainter({
    required this.birthIndex,
    required this.todayIndex,
    required this.selectedIndex,
    required this.primaryColor,
    required this.isDark,
    required this.isJanmaDay,
  });

  static const int _n = 27;
  static const double _seg = 2 * pi / _n;
  static const double _gap = 0.03;
  static const double _thin = 3.0;
  static const double _thick = 6.0;
  static const double _ashwiniOffset =
      _NakshatraRingWidgetState._ashwiniOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - _thick / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── Janma Day golden glow ────────────────────────────────────────
    if (isJanmaDay) {
      canvas.drawCircle(
        center,
        radius + 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = const Color(0xFFFFD700)
              .withValues(alpha: isDark ? 0.12 : 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // ── Background track ─────────────────────────────────────────────
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _thin
        ..color = primaryColor.withValues(alpha: isDark ? 0.06 : 0.04),
    );

    // ── Tara segments ────────────────────────────────────────────────
    for (int i = 0; i < _n; i++) {
      final isSelected = i == selectedIndex;
      final isToday = i == todayIndex;
      final isBirth = i == birthIndex && !isToday;

      Color color;
      double width;
      double alpha;

      if (birthIndex >= 0) {
        final tara = TaraBala.calculate(birthIndex, i);
        final isFav = tara.isFavorable;
        final isNeutral = tara.type == TaraType.janma;

        if (isSelected) {
          color = isNeutral
              ? const Color(0xFFFFD700)
              : (isFav
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFE53935));
          width = _thick;
          alpha = 0.85;
        } else if (isToday) {
          color = primaryColor;
          width = _thin + 1.5;
          alpha = 0.7;
        } else if (isBirth) {
          color = primaryColor;
          width = _thin + 0.5;
          alpha = 0.5;
        } else {
          color = isNeutral
              ? primaryColor
              : (isFav
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFE53935));
          width = _thin;
          alpha = isDark ? 0.22 : 0.15;
        }
      } else {
        color = primaryColor;
        width = isSelected || isToday ? _thick : _thin;
        alpha = isSelected || isToday ? 0.8 : (isDark ? 0.15 : 0.10);
      }

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width
        ..color = color.withValues(alpha: alpha);

      final ccwEdge = _ashwiniOffset - i * _seg - _seg / 2;
      final start = ccwEdge - pi / 2;

      canvas.drawArc(rect, start + _gap / 2, _seg - _gap, false, paint);

      // ── Today anchor glow ─────────────────────────────────────────────
      // Always visible on today's segment so the user can locate "now"
      // no matter how far they've rotated.  Skipped if it's also the
      // selected one (already glowing below) or Janma day (whole ring glows).
      if (isToday && !isSelected && !isJanmaDay) {
        canvas.drawArc(
          rect,
          start + _gap / 2,
          _seg - _gap,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = width + 6
            ..color = primaryColor.withValues(alpha: isDark ? 0.22 : 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }

      // Glow on selected
      if (isSelected) {
        canvas.drawArc(
          rect,
          start + _gap / 2,
          _seg - _gap,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = width + 5
            ..color = color.withValues(alpha: 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TaraRingPainter old) =>
      old.birthIndex != birthIndex ||
      old.todayIndex != todayIndex ||
      old.selectedIndex != selectedIndex ||
      old.primaryColor != primaryColor ||
      old.isDark != isDark ||
      old.isJanmaDay != isJanmaDay;
}

// =============================================================================
// Pulsing icon (Moon marker) — bare icon with breathing opacity, no container
// =============================================================================

class _PulsingIcon extends StatefulWidget {
  final double size;
  final Color color;
  final IconData icon;

  const _PulsingIcon({
    required this.size,
    required this.color,
    required this.icon,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return Opacity(
          opacity: 0.7 + t * 0.3,
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.color,
          ),
        );
      },
    );
  }
}

// =============================================================================
// Eager pan recognizer — wins the gesture arena immediately so that
// the parent ScrollView cannot steal the drag.
// =============================================================================

class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
