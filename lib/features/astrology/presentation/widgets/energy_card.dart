import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/vedic_time_utils.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/responsive/adaptive_card_body.dart';
import 'package:aurogram/features/astrology/data/utils/nakshatra_data.dart';
import 'package:aurogram/features/astrology/data/utils/daily_vibe.dart';
import 'package:aurogram/features/astrology/domain/forecast_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/common/pulsing_dot.dart';

// =============================================================================
// Global wheel-interaction signal.
// =============================================================================
//
// True while the user's finger is down on any nakshatra wheel.  External
// scrollables (e.g. tab PageView, page CustomScrollView) listen and lock
// themselves so the wheel area never produces accidental scroll/tab-switch.
final ValueNotifier<bool> wheelInteractingNotifier = ValueNotifier<bool>(false);

// =============================================================================
// NakshatraWheelController
// =============================================================================
//
// Flutter-idiomatic ChangeNotifier (like TabController / ScrollController).
// The wheel writes public state into it on every nakshatra boundary crossing
// during drag, so independent cards anywhere on the page can react live —
// without being nested inside EnergyCard.
//
// Usage:
//   final _ctrl = NakshatraWheelController();
//   EnergyCard(controller: _ctrl, ...)
//   ListenableBuilder(listenable: _ctrl, builder: ...)
//   _ctrl.jumpToIndex(nIdx);  // jump wheel from outside

class NakshatraWheelController extends ChangeNotifier {
  static const int _n = 27;

  int _activeIndex = -1;
  int _todayIndex = -1;
  int _birthIndex = -1;

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

  // ── Internal API (called by EnergyCard only) ──────────────────────

  /// Written by the wheel's _onRotation on every boundary crossing.
  void _update({
    required int activeIndex,
    required int todayIndex,
    required int birthIndex,
    required int cumulativeOffset,
  }) {
    if (_activeIndex == activeIndex &&
        _todayIndex == todayIndex &&
        _birthIndex == birthIndex &&
        _cumulativeOffset == cumulativeOffset) {
      return;
    }
    _activeIndex = activeIndex;
    _todayIndex = todayIndex;
    _birthIndex = birthIndex;
    _cumulativeOffset = cumulativeOffset;
    notifyListeners();
  }

  /// True while finger is down on the wheel.  The page uses this to lock
  /// scroll physics so the wheel area never scrolls the page.
  bool _isInteracting = false;
  bool get isInteracting => _isInteracting;
  void _setInteracting(bool v) {
    if (_isInteracting == v) return;
    _isInteracting = v;
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
class EnergyCard extends StatefulWidget {
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

  /// The unified forecast: date (yyyy-MM-dd) → computed day. This is the SINGLE
  /// source of the headline alignment % and the woven narrative — real,
  /// server-computed Vedic day-signals (not the old on-phone `50 + quality×47`).
  /// When a day is present its values win; when absent the wheel shows no
  /// fabricated number.
  final Map<String, ForecastDay>? forecast;

  /// When true, renders the wheel ABOVE the Daily Vibe card (desktop layouts
  /// where the wheel is the visual hero).  Default (false) keeps mobile-style
  /// vibe-first order: read the narrative, then look at the wheel beneath.
  final bool wheelFirst;

  const EnergyCard({
    super.key,
    this.todayNakshatra,
    this.birthNakshatra,
    this.sunNakshatra,
    this.lagnaNakshatra,
    this.todaySamvat,
    this.onDateChanged,
    this.wheelResetSignal,
    this.controller,
    this.forecast,
    this.wheelFirst = false,
  });

  @override
  State<EnergyCard> createState() => _EnergyCardState();
}

class _EnergyCardState extends State<EnergyCard>
    with TickerProviderStateMixin {
  // ─── Rotation ──────────────────────────────────────────────────────────────
  // Unbounded controller — value = angle in radians (grows without limit).
  late AnimationController _controller;
  Timer? _resumeTimer;
  double? _lastPanAngle;
  double _wheelDiameter = 0;

  // ─── Inertia physics (the "weight" of the wheel) ──────────────────────────
  // The wheel has MASS: its angle eases toward the finger instead of snapping.
  // Low follow = laggy/heavy; on release, momentum carries and friction bleeds
  // it off. These two constants are the real heaviness knobs.
  Ticker? _spin;
  double _targetAngle = 0; // where the finger wants the wheel
  double _velocity = 0; // current angular velocity (rad/s)
  int? _lastTickUs;
  bool _spinDragging = false;

  /// Mass time-constant (seconds): how slowly the wheel catches up to the
  /// finger. Bigger = heavier / more lag. ~0.02 feels light, ~0.25 feels like
  /// dragging a millstone.
  static const double _massTau = 0.16;

  /// Friction e-folding rate (per second) after release. Bigger = stops
  /// sooner (more friction). Smaller = longer coast.
  static const double _frictionRate = 3.5;

  /// Below this angular speed (rad/s) the wheel is considered at rest.
  static const double _restSpeed = 0.05;

  // ─── Long-press magnifier ─────────────────────────────────────────────────
  bool _isMagnified = false;
  Offset _magnifyOrigin = Offset.zero; // local press point — scale alignment

  // ─── Overlay portal (paints wheel above adjacent siblings) ────────────────
  // The wheel's visual + gestures live inside this OverlayPortal so the
  // magnified wheel + tara ring always render ABOVE the date card (above)
  // and the energy/vibe card (below). The original spot reserves layout
  // space with a transparent placeholder; the overlay child is positioned
  // via CompositedTransformFollower → LayerLink so it tracks the layout
  // slot exactly during scroll/resize.
  final LayerLink _wheelLayerLink = LayerLink();
  final OverlayPortalController _wheelPortalController =
      OverlayPortalController();

  // ─── Selection (auto — always the nakshatra at 12 o'clock / top) ──────────
  int _currentBottomIndex = -1; // field name kept for compatibility

  // ─── Geometry constants ────────────────────────────────────────────────────
  /// Angle of Ashwini's center, clockwise from 12 o'clock, in radians.
  /// Tune this to align the overlay with the artwork.
  static const double _ashwiniOffset = 0.41; // ≈ 24°
  static const int _count = 27;
  static const double _seg = 2 * pi / _count;

  static const double _selectedRingWidth = 5.0;
  static const double _ringGap = 2.0;

  // ─── Derived ───────────────────────────────────────────────────────────────
  // These indices now position only the DECORATIVE markers (moon/birth stars,
  // aura ring). The headline alignment % and narrative come from the unified
  // forecast (date-keyed, server-computed) — NOT from these indices — so a bad
  // index can no longer produce a wrong reading. The canonical-alias fix in
  // NakshatraData.findIndex means real charts resolve; the constants below are
  // last-resort UI-preview positions only (e.g. a signed-out visitor with no
  // chart) so the wheel still renders something sensible.
  int get _todayIndex {
    final idx = NakshatraData.findIndex(widget.todayNakshatra);
    return idx >= 0 ? idx : 4; // preview only: Mrigashira
  }

  int get _birthIndex {
    final idx = NakshatraData.findIndex(widget.birthNakshatra);
    return idx >= 0 ? idx : 16; // preview only: Anuradha
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

  /// Scrub window (in cumulative day-offsets from today) the wheel is allowed
  /// to rotate across: the contiguous run of days that have BOTH a real
  /// alignment percentage AND a woven narrative. Defaults to [0, 0] (locked to
  /// today) until the forecast loads. Recomputed whenever [widget.forecast]
  /// changes. Rotation is hard-stopped at these edges — the wheel never spins
  /// onto a day we can't fully describe.
  int _minOffset = 0;
  int _maxOffset = 0;

  /// Reentrancy guard: true while [_clampToEdge] snaps the controller back, so
  /// the resulting synchronous [_onRotation] callback is ignored.
  bool _isClamping = false;

  /// True while animating back to today — suppresses cumulative offset
  /// tracking in [_onRotation] so intermediate boundary crossings don't
  /// overwrite the reset.
  bool _isReturningToToday = false;

  /// The date currently shown at the top of the wheel.
  DateTime get _displayedDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .add(Duration(days: _cumulativeOffset));
  }

  /// True when the wheel is at today's position (default state).
  bool get _isAtToday => _cumulativeOffset == 0;

  /// The unified-forecast day for whatever date the wheel is currently showing,
  /// or null if the forecast hasn't been computed for that date yet.
  ForecastDay? get _activeForecastDay =>
      widget.forecast?[ForecastService.dateKey(_displayedDate)];

  /// Recompute the scrub window: the contiguous run of days, starting from
  /// today, that have BOTH a real alignment percentage AND a woven narrative.
  /// The wheel may only rotate within [_minOffset, _maxOffset]. If today's
  /// story isn't ready yet, the window collapses to [0, 0] (locked to today)
  /// so the wheel never scrubs onto a day we can't fully describe.
  void _recomputeForecastBounds() {
    final f = widget.forecast;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool complete(int d) {
      final day = f?[ForecastService.dateKey(today.add(Duration(days: d)))];
      return day != null &&
          day.alignment != null &&
          (day.narrative?.isNotEmpty ?? false);
    }

    if (!complete(0)) {
      _minOffset = 0;
      _maxOffset = 0;
      return;
    }
    var maxOff = 0;
    while (maxOff < 366 && complete(maxOff + 1)) {
      maxOff++;
    }
    var minOff = 0;
    while (minOff > -366 && complete(minOff - 1)) {
      minOff--;
    }
    _minOffset = minOff;
    _maxOffset = maxOff;
  }

  /// Per-nakshatra wave weights (−1..+1) for the aura, derived from the REAL
  /// alignment % of the day each nakshatra maps to (the day nearest the shown
  /// date whose Moon sits in that nakshatra). This is what drives the wave's
  /// in/out shape — replacing the old fixed Tara landscape. The bulge at the
  /// TOP is always the shown day's real %, neighbours show the days around it,
  /// so the wave rolls in and out with the true numbers while the orb's overall
  /// size stays constant. A null entry → no forecast for that day (drawn flat).
  List<double?> _alignmentWave() {
    final out = List<double?>.filled(_count, null);
    final f = widget.forecast;
    if (f == null || f.isEmpty) return out;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIdx = _todayIndex;
    for (int i = 0; i < _count; i++) {
      // Day-offset whose Moon sits in nakshatra i, nearest the displayed offset.
      final base = ((i - todayIdx) % _count + _count) % _count;
      final k = ((_cumulativeOffset - base) / _count).round();
      final offset = base + _count * k;
      final a = f[ForecastService.dateKey(today.add(Duration(days: offset)))]
          ?.alignment;
      if (a != null) {
        // 50% = neutral; ±30 pts spans the full swell so the wave reads clearly.
        out[i] = ((a - 50) / 30.0).clamp(-1.0, 1.0);
      }
    }
    return out;
  }

  /// "May 17"-style short date.
  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
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
    // Keep external jumps (e.g. the sky-chart slider) inside the scrub window.
    final target = dayOffset.clamp(_minOffset, _maxOffset);
    // Compute the target nakshatra index for this offset.
    final targetIdx = (_todayIndex + target % _count + _count) % _count;
    if (targetIdx < 0 || targetIdx >= _count) return;
    HapticFeedback.selectionClick();
    _stopAll();

    // Set cumulative offset directly — we know exactly where we're going.
    _cumulativeOffset = target;

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
    _recomputeForecastBounds();

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

    // Activate the overlay portal so the wheel renders above sibling cards
    // from the very first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_wheelPortalController.isShowing) {
        _wheelPortalController.show();
      }
    });
  }

  @override
  void didUpdateWidget(EnergyCard old) {
    super.didUpdateWidget(old);
    if (old.wheelResetSignal != widget.wheelResetSignal) {
      old.wheelResetSignal?.removeListener(_onExternalResetToToday);
      widget.wheelResetSignal?.addListener(_onExternalResetToToday);
    }
    // Recompute the scrub window whenever the forecast stream emits. If the
    // window shrank below the wheel's current position, pull it back to the
    // nearest edge so it never sits on an undescribable day.
    if (!identical(old.forecast, widget.forecast)) {
      _recomputeForecastBounds();
      if (_cumulativeOffset > _maxOffset) {
        _jumpToOffset(_maxOffset);
      } else if (_cumulativeOffset < _minOffset) {
        _jumpToOffset(_minOffset);
      }
    }
    // Re-center wheel when todayNakshatra arrives for the first time
    // (e.g. calendar data loads after initState positioned using the fallback).
    if (old.todayNakshatra != widget.todayNakshatra &&
        widget.todayNakshatra != null &&
        old.todayNakshatra == null) {
      final target = -_ashwiniOffset + _todayIndex * _seg;
      _controller.value = target;
      _currentBottomIndex = _nakshatraAtTop();
      _cumulativeOffset = 0;
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
    _spin?.dispose();
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
    if (_isClamping) return;
    final seg = _nakshatraAtTop();
    if (seg != _currentBottomIndex && seg >= 0) {
      // Haptic on drag removed — felt like vibration during rotation.

      // Track direction of boundary crossing for cumulative offset.
      // Skip during return-to-today animation — offset is already reset
      // and intermediate crossings would corrupt it.
      if (_currentBottomIndex >= 0 && !_isReturningToToday) {
        final prev = _currentBottomIndex;
        // Detect forward vs backward crossing (handles the 26→0 / 0→26 wrap).
        final forwardDelta = (seg - prev + _count) % _count;
        final backwardDelta = (prev - seg + _count) % _count;
        // Signed day-delta for this crossing (fling can skip several segments).
        final signed =
            forwardDelta <= backwardDelta ? forwardDelta : -backwardDelta;
        final proposed = _cumulativeOffset + signed;
        // Hard-stop at the edges of the known forecast window: never scrub onto
        // a day without both a percentage and story text.
        if (proposed > _maxOffset) {
          _clampToEdge(_maxOffset);
          return;
        }
        if (proposed < _minOffset) {
          _clampToEdge(_minOffset);
          return;
        }
        _cumulativeOffset = proposed;
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

  /// Halt rotation at a scrub-window edge and hold the edge day centered at the
  /// top. Kills all motion (drag chase + inertia) and snaps the controller to
  /// the nearest angle whose top nakshatra is the edge day, so the wheel can't
  /// spin past the last day we can fully describe.
  void _clampToEdge(int edgeOffset) {
    _isClamping = true;
    // Kill both inertia phases so the coast/chase can't push past the edge.
    _velocity = 0;
    _spinDragging = false;
    _spin?.stop();
    _lastTickUs = null;

    final edgeIdx = ((_todayIndex + edgeOffset) % _count + _count) % _count;
    const twoPi = 2 * pi;
    final targetAngle = -_ashwiniOffset + edgeIdx * _seg;
    final current = _controller.value;
    // Shortest-arc snap so we land on the edge day without a full spin.
    final delta = ((targetAngle - current) % twoPi + twoPi + pi) % twoPi - pi;
    _controller.value = current + delta;
    _targetAngle = _controller.value;
    _cumulativeOffset = edgeOffset;
    setState(() => _currentBottomIndex = edgeIdx);
    widget.controller?._update(
      activeIndex: _activeIndex,
      todayIndex: _todayIndex,
      birthIndex: _birthIndex,
      cumulativeOffset: _cumulativeOffset,
    );
    if (mounted) widget.onDateChanged?.call(_displayedDate);
    _isClamping = false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Rotation control
  // ═══════════════════════════════════════════════════════════════════════════

  void _stopAll() {
    _controller.stop();
    _resumeTimer?.cancel();
    _spin?.stop();
    _spinDragging = false;
    _velocity = 0;
    _lastTickUs = null;
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
  }

  // ── Inertia engine ─────────────────────────────────────────────────────────
  // One ticker drives both phases:
  //   • while dragging  → ease the wheel toward the finger (mass/lag),
  //     measuring velocity along the way.
  //   • after release   → apply that velocity and decay it with friction.

  void _startSpin() {
    _spin ??= createTicker(_onSpinTick);
    _lastTickUs = null;
    if (!_spin!.isActive) _spin!.start();
  }

  void _onSpinTick(Duration elapsed) {
    final nowUs = elapsed.inMicroseconds;
    if (_lastTickUs == null) {
      _lastTickUs = nowUs;
      return;
    }
    var dt = (nowUs - _lastTickUs!) / 1e6;
    _lastTickUs = nowUs;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05; // clamp after a stall

    if (_spinDragging) {
      // Critically-damped chase toward the finger target. The wheel lags by
      // ~_massTau seconds → that lag IS the felt weight.
      final k = 1 - exp(-dt / _massTau);
      final prev = _controller.value;
      final next = prev + (_targetAngle - prev) * k;
      _velocity = (next - prev) / dt; // remember speed for the release
      _controller.value = next;
    } else {
      // Friction coast.
      _velocity *= exp(-_frictionRate * dt);
      _controller.value += _velocity * dt;
      if (_velocity.abs() < _restSpeed) {
        _velocity = 0;
        _spin?.stop();
        _lastTickUs = null;
        _scheduleResume();
        if (mounted) widget.onDateChanged?.call(_displayedDate);
      }
    }
  }

  /// Feed a finger-delta into the inertia engine (shared by rotate + magnify).
  void _spinDragBegin(double startAngle) {
    _stopAll();
    _targetAngle = _controller.value;
    _velocity = 0;
    _spinDragging = true;
    _lastPanAngle = startAngle;
    _startSpin();
  }

  void _spinDragUpdate(double delta) {
    _targetAngle += delta;
  }

  void _spinDragRelease() {
    _spinDragging = false;
    // Ticker keeps running; friction now decays _velocity to rest.
    // If it's already basically still, settle immediately.
    if (_velocity.abs() < _restSpeed) {
      _velocity = 0;
      _spin?.stop();
      _lastTickUs = null;
      _scheduleResume();
      if (mounted) widget.onDateChanged?.call(_displayedDate);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Gesture handlers (driven by RawGestureDetector + Flutter's gesture arena).
  //
  // - HorizontalDragGestureRecognizer claims horizontal drags → wheel rotates.
  //   Vertical drags lose to the scroll view → page scrolls.
  // - LongPressGestureRecognizer claims 250 ms holds → magnify; subsequent
  //   movement pans the zoomed view; release unmagnifies.
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Rotation ───────────────────────────────────────────────────────────────

  void _onRotateStart(DragStartDetails d) {
    if (_wheelDiameter <= 0) return;
    final cx = _wheelDiameter / 2;
    _spinDragBegin(atan2(d.localPosition.dx - cx, -(d.localPosition.dy - cx)));
  }

  void _onRotateUpdate(DragUpdateDetails d) {
    if (_lastPanAngle == null || _wheelDiameter <= 0) return;
    final cx = _wheelDiameter / 2;
    final currentAngle =
        atan2(d.localPosition.dx - cx, -(d.localPosition.dy - cx));
    double delta = currentAngle - _lastPanAngle!;
    if (delta > pi) delta -= 2 * pi;
    if (delta < -pi) delta += 2 * pi;
    _lastPanAngle = currentAngle;
    // Move the finger TARGET; the wheel eases toward it with mass.
    _spinDragUpdate(delta);
  }

  void _onRotateEnd(DragEndDetails d) {
    _lastPanAngle = null;
    _spinDragRelease();
  }

  void _onRotateCancel() {
    _lastPanAngle = null;
    _spinDragRelease();
  }

  // ── Magnifier ──────────────────────────────────────────────────────────────

  void _onMagnifyStart(LongPressStartDetails d) {
    setState(() {
      _isMagnified = true;
      _magnifyOrigin = d.localPosition;
    });
    // Seed rotation angle so dragging while zoomed rotates the wheel.
    if (_wheelDiameter > 0) {
      final cx = _wheelDiameter / 2;
      _spinDragBegin(
          atan2(d.localPosition.dx - cx, -(d.localPosition.dy - cx)));
    }
  }

  void _onMagnifyMove(LongPressMoveUpdateDetails d) {
    if (_lastPanAngle == null || _wheelDiameter <= 0) return;
    final cx = _wheelDiameter / 2;
    final currentAngle =
        atan2(d.localPosition.dx - cx, -(d.localPosition.dy - cx));
    double delta = currentAngle - _lastPanAngle!;
    if (delta > pi) delta -= 2 * pi;
    if (delta < -pi) delta += 2 * pi;
    _lastPanAngle = currentAngle;
    _spinDragUpdate(delta);
  }

  void _onMagnifyEnd(LongPressEndDetails d) {
    setState(() => _isMagnified = false);
    _lastPanAngle = null;
    _spinDragRelease();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? Colors.black : Colors.white;

    final wheel = _buildWheel(c, isDark);
    // Header summary: energy label + alignment %.
    // The % is the REAL server-computed Vedic day-signal (Gochara + Ashtakavarga
    // + Vedha + Tara/Chandra Bala + Panchang) for the shown date. The label
    // prefers the AI-narrated heading; the static Tara vibe is a soft fallback
    // for the label text only (never for the number).
    final fday = _activeForecastDay;
    final headerVibe = DailyVibe.forUser(
      birthIndex: _birthIndex,
      todayIndex: _activeIndex,
    );
    final headerAlignment = fday?.alignment; // null → no % shown (no fake)
    // Story still generating: real number present, woven text not yet. Show an
    // honest loading label — never the static template dressed as the reading.
    final headerStoryGenerating = _birthIndex >= 0 &&
        headerAlignment != null &&
        !(fday?.narrative?.isNotEmpty ?? false);
    final headerLabel = (fday?.heading != null && fday!.heading!.isNotEmpty)
        ? fday.heading!
        : (headerStoryGenerating ? 'READING YOUR SKY' : headerVibe?.label);

    return Material(
      color: cardColor,
      elevation: 0,
      child: AdaptiveCardBody(
        visualFirst: true, // wheel is the hero on mobile
        header: (wide) => _energyHeaderSection(
          wide: wide,
          c: c,
          isDark: isDark,
          headerLabel: headerLabel,
          headerAlignment: headerAlignment,
        ),
        info: (wide) => _buildDailyVibeContent(c, isDark, cardColor, wide),
        visual: (wide) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMoon(c, isDark),
            wheel,
          ],
        ),
      ),
    );
  }

  // Editorial header (wide) or centered uppercase header (mobile). Extracted
  // so both layouts share one source.
  Widget _energyHeaderSection({
    required bool wide,
    required Color c,
    required bool isDark,
    required String? headerLabel,
    required int? headerAlignment,
  }) {
    final webHeader = wide;
    final palette = DashboardCardPalette.forBrightness(isDark);
    final fgMain = palette.fgMain;
    final fgMuted = palette.fgMuted;

    if (webHeader) {
      // Editorial header matching Current Sky / Today's Balance:
      // left-aligned, Georgia italic 32, two-tone, muted subheading.
      final children = <Widget>[];
      if (headerLabel != null && headerLabel.isNotEmpty) {
        final words = headerLabel.trim().split(RegExp(r'\s+'));
        final last = words.removeLast();
        final lead = words.isEmpty ? '' : '${words.join(' ')} ';
        children.add(RichText(
          text: TextSpan(
            children: [
              if (lead.isNotEmpty)
                TextSpan(
                  text: lead,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    color: c,
                    fontSize: 32,
                    letterSpacing: -1.2,
                  ),
                ),
              TextSpan(
                text: '$last.',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  color: fgMain,
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -1.2,
                ),
              ),
            ],
          ),
        ));
      }
      if (headerAlignment != null) {
        children.add(const SizedBox(height: 8));
        children.add(Text(
          '$headerAlignment% aligned.',
          style: TextStyle(
            color: fgMuted,
            fontSize: 15.0,
            height: 1.4,
            fontFamily: 'Georgia',
            fontStyle: FontStyle.italic,
          ),
        ));
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
    }

    // MOBILE — original centered uppercase header (untouched).
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (headerLabel != null && headerLabel.isNotEmpty)
            Text(
              headerLabel.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                letterSpacing: 3.0,
                fontWeight: FontWeight.w800,
                color: c,
              ),
            ),
          if (headerAlignment != null)
            Text(
              '$headerAlignment% ALIGNED',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                letterSpacing: 3.0,
                fontWeight: FontWeight.w800,
                color: c,
              ),
            ),
        ],
      ),
    );
  }

  // ─── Daily Vibe ─────────────────────────────────────────────────────────
  //
  // Plain-English guidance derived from today's Tara Bala. Returns content
  // only (no Material) — it now shares the wheel's card. See build().

  Widget _buildDailyVibeContent(Color c, bool isDark, Color cardColor, [bool isWide = false]) {
    // No birth data yet → invite the user to set it up.
    if (_birthIndex < 0) {
      return _buildVibeEmptyContent(c, isDark, cardColor);
    }

    // The vibe is driven by whatever's at the bottom of the wheel — so
    // dragging the wheel becomes a "what does <other day> look like?"
    // exploration affordance.
    final activeIdx = _activeIndex;
    final vibe = DailyVibe.forUser(
      birthIndex: _birthIndex,
      todayIndex: activeIdx,
    );
    if (vibe == null) return _buildVibeEmptyContent(c, isDark, cardColor);

    final fday = _activeForecastDay;
    final forecastNarrative = fday?.narrative;
    // Real number present for this day but the woven story hasn't landed yet →
    // show an honest loading state (the ensure call is generating it), NOT the
    // static template pretending to be the reading.
    final storyGenerating =
        fday?.alignment != null && !(forecastNarrative?.isNotEmpty ?? false);
    if (storyGenerating) {
      return _buildVibeLoadingContent(c);
    }
    // The unified forecast owns every narrated date. Static Tara guidance is
    // only a fallback outside the computed forecast window.
    final narrativeText = forecastNarrative?.isNotEmpty == true
        ? forecastNarrative!
        : vibe.narrative;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Narrative
          Text(
            narrativeText,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isWide ? AppTheme.babaTextSize + 2 : AppTheme.babaTextSize,
              fontWeight: FontWeight.w400,
              color: c.withValues(alpha: 0.75),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
        ],
      ),
    );
  }

  /// Shown when the day's real alignment exists but its woven story is still
  /// being generated (the ensureForecast call is running). Honest "working"
  /// state so we never present the static template as the real reading.
  Widget _buildVibeLoadingContent(Color c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              valueColor: AlwaysStoppedAnimation<Color>(
                c.withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Reading your sky\u2026',
            style: TextStyle(
              fontSize: AppTheme.babaTextSize,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: c.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Empty-state content shown when birth nakshatra isn't available.
  /// Content only (no Material) — shares the wheel's card. See build().
  Widget _buildVibeEmptyContent(Color c, bool isDark, Color cardColor) {
    final todayInfo = NakshatraData.getInfo(_todayIndex);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u263D', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  todayInfo != null
                      ? 'Today\'s Moon is in ${todayInfo.name}'
                      : 'Today\'s Sky',
                  style: TextStyle(
                    fontSize: AppTheme.babaTextSize + 2,
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
              fontSize: AppTheme.babaTextSize,
              color: c.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
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
        // 0.96 leaves a small margin so the wave's bulges breathe outward
        // without poking past the card's side edges.
        final total =
            (constraints.maxWidth * 0.97).clamp(0.0, _maxWheelDiameter);
        _wheelDiameter = total;
        final imgDia = total - 2 * (_selectedRingWidth + _ringGap);

        // How far the wheel box sits from the card's horizontal edges, so the
        // dimmer can stretch all the way out (no uncovered side padding).
        final dimHExt =
            (constraints.maxWidth - total) / 2 + AppDimensions.paddingXs;

        // The bottom dimmer must fade into the CARD surface, not always black,
        // else it smudges black over the white card in light mode.
        final fade = isDark ? Colors.black : Colors.white;

        // Scale alignment — maps press point inside the wheel to AnimatedScale's
        // alignment convention (-1..1). Locked at press; doesn't change on drag.
        final magAlignX = total > 0 ? (_magnifyOrigin.dx / total) * 2 - 1 : 0.0;
        final magAlignY = total > 0 ? (_magnifyOrigin.dy / total) * 2 - 1 : 0.0;

        // Scale alignment
        final Widget rotatingLayer = Stack(
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
                rotation: _controller,
                // Real per-day alignment %, one weight per nakshatra → the wave
                // rolls in/out with the true numbers (top = shown day's %).
                wave: _alignmentWave(),
              ),
            ),
          ],
        );

        // ── The full interactive wheel: strictly square, never distorts ──
        final Widget wheelVisual = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            widget.controller?._setInteracting(true);
            wheelInteractingNotifier.value = true;
          },
          onPointerUp: (_) {
            widget.controller?._setInteracting(false);
            wheelInteractingNotifier.value = false;
          },
          onPointerCancel: (_) {
            widget.controller?._setInteracting(false);
            wheelInteractingNotifier.value = false;
          },
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              PanGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                () => PanGestureRecognizer(),
                (instance) {
                  instance
                    ..onStart = _onRotateStart
                    ..onUpdate = _onRotateUpdate
                    ..onEnd = _onRotateEnd
                    ..onCancel = _onRotateCancel;
                },
              ),
              LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                    // Deliberate press-and-hold to zoom. Long enough that a
                    // quick scroll/flick never accidentally triggers it.
                    duration: const Duration(milliseconds: 400)),
                (instance) {
                  instance
                    ..onLongPressStart = _onMagnifyStart
                    ..onLongPressMoveUpdate = _onMagnifyMove
                    ..onLongPressEnd = _onMagnifyEnd;
                },
              ),
            },
            child: AnimatedScale(
              scale: _isMagnified ? 1.55 : 1.0,
              alignment: Alignment(
                magAlignX.clamp(-1.0, 1.0),
                magAlignY.clamp(-1.0, 1.0),
              ),
              // Slower, silkier zoom in/out.
              duration: const Duration(milliseconds: 380),
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
                        // Rotating artwork + ring
                        Transform.rotate(angle: angle, child: child),

                        // Upright markers (birth / today / selected)
                        ..._buildMarkers(total, c, angle, isDark),

                        // NOTE: bottom dimming is NOT here anymore — it lives at
                        // the CARD level (see build()) so it covers the wave's
                        // outward bulges too, and only applies when unmagnified.

                        // Center date hub
                        _buildDateHub(c, isDark),

                        // NOTE: "DRAG TO EXPLORE" moved to the overlay stack
                        // (above the dim band) so it stays bright.
                      ],
                    );
                  },
                  child: rotatingLayer,
                ),
              ),
            ),
          ),
        );

        // Hoist into the OverlayPortal so the magnified (1.25x) wheel paints
        // above sibling cards. The follower box matches the wheel exactly
        // (square), so nothing is ever compressed into an oval.
        return Center(
          child: CompositedTransformTarget(
            link: _wheelLayerLink,
            child: OverlayPortal(
              controller: _wheelPortalController,
              overlayChildBuilder: (overlayContext) {
                return Positioned(
                  left: 0,
                  top: 0,
                  width: total,
                  height: total,
                  child: CompositedTransformFollower(
                    link: _wheelLayerLink,
                    targetAnchor: Alignment.topLeft,
                    followerAnchor: Alignment.topLeft,
                    showWhenUnlinked: false,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        wheelVisual,
                        // Bottom dimming, painted ON TOP of the whole wheel
                        // (incl. the wave's outward bulges) but OUTSIDE the
                        // zoom scale — so it only applies when unmagnified.
                        if (!_isMagnified)
                          Positioned(
                            left: -dimHExt,
                            right: -dimHExt,
                            top: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      fade.withValues(alpha: 0.00),
                                      fade.withValues(alpha: 0.04),
                                      fade.withValues(alpha: 0.10),
                                      fade.withValues(alpha: 0.18),
                                      fade.withValues(alpha: 0.29),
                                      fade.withValues(alpha: 0.43),
                                      fade.withValues(alpha: 0.59),
                                      fade.withValues(alpha: 0.76),
                                      fade.withValues(alpha: 0.92),
                                      fade,
                                    ],
                                    stops: const [
                                      0.00,
                                      0.30,
                                      0.40,
                                      0.48,
                                      0.55,
                                      0.62,
                                      0.69,
                                      0.76,
                                      0.83,
                                      0.90,
                                      1.00,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // "MOON IN <name>" + "DRAG TO EXPLORE" — above the
                        // dim band so they stay readable as the wheel darkens.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: total * 0.10,
                          child: IgnorePointer(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isMagnified ? 0.0 : 1.0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'MOON IN',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 7,
                                      letterSpacing: 2.0,
                                      fontWeight: FontWeight.w700,
                                      color: c.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    NakshatraData.getInfo(_activeIndex)
                                            ?.name
                                            .toUpperCase() ??
                                        '...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      letterSpacing: 2.5,
                                      fontWeight: FontWeight.w800,
                                      color: c.withValues(alpha: 0.95),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.chevron_left,
                                          size: 11,
                                          color: c.withValues(alpha: 0.7)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'DRAG TO EXPLORE',
                                        style: TextStyle(
                                          fontSize: 7,
                                          letterSpacing: 2.0,
                                          fontWeight: FontWeight.w700,
                                          color: c.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(Icons.chevron_right,
                                          size: 11,
                                          color: c.withValues(alpha: 0.7)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              // Placeholder reserves the square wheel footprint in the Column.
              child: SizedBox(width: total, height: total),
            ),
          ),
        );
      }),
    );
  }

  /// Center date hub — shows the displayed date / TODAY.
  Widget _buildDateHub(Color c, bool isDark) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        // Semi-transparent so the wheel art faintly shows through the hub.
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.70),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.22), blurRadius: 14),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _isAtToday ? _formatDate(DateTime.now()) : _formatDate(_displayedDate),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: c,
        ),
      ),
    );
  }

  /// Elegant hand-drawn moon (custom-painted in the app palette) shown above
  /// the wheel. Replaces the OS emoji for a premium, on-brand look.
  Widget _buildMoon(Color c, bool isDark) {
    // Drive the moon from the SAME panchang tithi shown as the label, so it can
    // never disagree (the old synodic calc drifted: full on Amavasya, dark on
    // Purnima). Falls back to the synodic calc only when no tithi is available.
    final phase = _moonPhaseFromTithi() ??
        VedicTimeUtils.getMoonPhaseFraction(_displayedDate);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(38, 38),
          painter: _MoonPhasePainter(
            phase: phase,
            // A moon should read as a moon in both themes: cream-lit on the
            // dark night sky, warm-gold-lit with a soft grey shadow on light.
            litColor:
                isDark ? const Color(0xFFF3EFE6) : const Color(0xFFE3B24A),
            darkColor: isDark ? Colors.black : const Color(0xFFCFC7B6),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  /// Today's tithi as a continuous 1..30 index (15 = Purnima, 30 = Amavasya),
  /// read from the same panchang the labels use. Returns null if unavailable.
  int? _todayUnifiedTithi() {
    final samvat = widget.todaySamvat;
    if (samvat == null) return null;
    final rawNum =
        samvat['number'] ?? samvat['tithi_number'] ?? samvat['tithiNumber'];
    int? t;
    if (rawNum is num) {
      t = rawNum.toInt();
    } else if (rawNum != null) {
      t = int.tryParse(rawNum.toString());
    }
    if (t == null) return null;
    if (t > 15) return t.clamp(16, 30);
    final paksha = (samvat['paksha'] ?? samvat['tithiPaksha'] ?? '')
        .toString()
        .toLowerCase();
    final isKrishna = paksha.contains('krishna') || paksha.contains('krsna');
    return isKrishna ? (t + 15).clamp(16, 30) : t.clamp(1, 15);
  }

  /// Moon phase fraction (0 = new/Amavasya, 0.5 = full/Purnima) derived from
  /// the tithi, projected across the wheel's day offset (~1 tithi per day).
  /// phase = (tithi - 0.5) / 30 -> tithi 15 ≈ 0.483 (full), 30 ≈ 0.983 (new).
  double? _moonPhaseFromTithi() {
    final today = _todayUnifiedTithi();
    if (today == null) return null;
    final unified = ((today - 1 + _cumulativeOffset) % 30 + 30) % 30 + 1;
    return (unified - 0.5) / 30.0;
  }

  // ─── Markers (icons stay upright) ──────────────────────────────────────────

  List<Widget> _buildMarkers(
      double diameter, Color c, double rotAngle, bool isDark) {
    final markers = <Widget>[];
    // Place markers on the dividing line between the outer nakshatra band and
    // the inner zodiac band of the artwork (~0.73 of the image radius). Fully
    // inside the wheel, so the dimming overlay darkens them completely.
    final imgRadius = diameter / 2 - (_selectedRingWidth + _ringGap);
    final radius = imgRadius * 0.70;

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
}

// =============================================================================
// Moon phase painter
// =============================================================================

/// Draws an elegant moon for a given synodic [phase] (0=new, 0.5=full).
/// Uses two arcs (bright limb + terminator) so crescents and gibbous phases
/// render with a smooth, real terminator curve — no OS emoji.
class _MoonPhasePainter extends CustomPainter {
  _MoonPhasePainter({
    required this.phase,
    required this.litColor,
    required this.darkColor,
  });

  final double phase; // 0..1
  final Color litColor;
  final Color darkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = (size.width < size.height ? size.width : size.height) / 2 - 1;

    // 1. Draw the Base Dark Moon first (pure flat black/darkColor).
    // This perfectly prevents any edge/rim bleeding because the background is already black.
    canvas.drawCircle(center, r, Paint()..color = darkColor);

    // 2. Calculate Illuminated Region (litPath)
    final illum = (1 - cos(2 * pi * phase)) / 2;
    final waxing = phase < 0.5;

    final litPath = Path();
    if (illum > 0.001) {
      // Bulletproof lit-region: sample the bright limb (a semicircle) and the
      // terminator (a half-ellipse whose signed width k goes +1 at new -> -1 at
      // full). The old arcToPoint construction was ambiguous and rendered
      // inverted (full on Amavasya, dark on Purnima); this polygon is not.
      final k = 1 - 2 * illum; // +1 new .. 0 quarter .. -1 full
      final limb = waxing ? 1.0 : -1.0; // N-hemisphere: waxing lit on the right
      const steps = 120;
      for (int i = 0; i <= steps; i++) {
        final s = pi * i / steps;
        final x = center.dx + limb * r * sin(s);
        final y = center.dy - r * cos(s);
        if (i == 0) {
          litPath.moveTo(x, y);
        } else {
          litPath.lineTo(x, y);
        }
      }
      for (int i = steps; i >= 0; i--) {
        final s = pi * i / steps;
        final x = center.dx + limb * k * r * sin(s);
        final y = center.dy - r * cos(s);
        litPath.lineTo(x, y);
      }
      litPath.close();

      // 3. Clip the canvas to ONLY the lit section
      canvas.save();
      canvas.clipPath(litPath);

      // 4. Draw the Lunar Surface (Regolith) INSIDE the clipped area
      canvas.drawCircle(center, r, Paint()..color = litColor);

      // 5. Draw Lunar Maria (dark basaltic plains fixed to the tidally locked face)
      final mariaColor = Color.lerp(litColor, darkColor, 0.3)!;
      final mariaPaint = Paint()
        ..color = mariaColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.15)
        ..isAntiAlias = true;

      // Oceanus Procellarum
      canvas.drawOval(
        Rect.fromCenter(
            center: center + Offset(-r * 0.4, -r * 0.1),
            width: r * 0.5,
            height: r * 1.1),
        mariaPaint,
      );
      // Mare Imbrium
      canvas.drawCircle(
          center + Offset(r * 0.15, -r * 0.45), r * 0.35, mariaPaint);
      // Mare Serenitatis & Tranquillitatis
      canvas.drawOval(
        Rect.fromCenter(
            center: center + Offset(r * 0.45, -r * 0.1),
            width: r * 0.4,
            height: r * 0.6),
        mariaPaint,
      );
      // Mare Fecunditatis
      canvas.drawCircle(
          center + Offset(r * 0.3, r * 0.35), r * 0.25, mariaPaint);
      // Mare Nubium
      canvas.drawCircle(
          center + Offset(-r * 0.15, r * 0.35), r * 0.25, mariaPaint);

      // Tycho Crater
      final tychoPaint = Paint()
        ..color = litColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05);
      canvas.drawCircle(
          center + Offset(-r * 0.1, r * 0.55), r * 0.08, tychoPaint);

      // Restore the canvas (removing the clip)
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MoonPhasePainter old) =>
      old.phase != phase ||
      old.litColor != litColor ||
      old.darkColor != darkColor;
}

// =============================================================================
// Alignment orb painter
// =============================================================================

/// Paints the wheel's orb: a clean circle whose radius is driven purely by the
/// displayed day's REAL alignment % (ForecastDay.alignment). No Tara Bala, no
/// per-nakshatra shape — the orb and the headline number are the same signal.
class _TaraRingPainter extends CustomPainter {
  final int birthIndex;
  final int todayIndex;
  final int selectedIndex;
  final Color primaryColor;
  final bool isDark;
  final bool isJanmaDay;

  /// Signed wave weight (−1..+1) per nakshatra, derived from the REAL alignment
  /// % of the day each nakshatra maps to. Drives the aura's in/out shape so the
  /// wave rolls with the true numbers (a null entry draws flat/neutral).
  final List<double?> wave;

  /// Live wheel rotation. Used both to repaint each frame AND to fade the
  /// wave line toward the SCREEN bottom (so the dimming follows the line
  /// even where it bulges outside the wheel box).
  final Animation<double> rotation;

  _TaraRingPainter({
    required this.birthIndex,
    required this.todayIndex,
    required this.selectedIndex,
    required this.primaryColor,
    required this.isDark,
    required this.isJanmaDay,
    required this.rotation,
    required this.wave,
  }) : super(repaint: rotation);

  static const int _n = 27;
  static const double _seg = 2 * pi / _n;
  static const double _ashwiniOffset = _EnergyCardState._ashwiniOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Aura geometry. The overall orb size is CONSTANT (mean radius ≈ baseR);
    // only the wave rolls in and out. Bulges OUT where the day's alignment % is
    // strong, pinches IN where it's weak — the same real number as the header.
    // Sized to stay just inside the card; the line self-fades toward the screen
    // bottom, so even outward bulges darken as they go down.
    final baseR = size.width / 2 - 9.0;
    const amp = 18.0; // dramatic-ish, spills slightly outside
    final maxR = baseR + amp;

    // Smooth radius at any angle by cosine-interpolating between the two nearest
    // nakshatra weights → soft, continuous waviness. Missing days read as flat.
    double radiusAt(double theta) {
      final f = ((_ashwiniOffset - theta) / _seg) % _n;
      final i0 = f.floor() % _n;
      final i1 = (i0 + 1) % _n;
      final t = f - f.floor();
      final w = (1 - cos(t * pi)) / 2;
      final v0 = wave[i0] ?? 0.0;
      final v1 = wave[i1] ?? 0.0;
      final qv = v0 * (1 - w) + v1 * w;
      return baseR + amp * qv;
    }

    // One continuous, smooth closed path — no segmentation.
    final path = Path();
    const steps = 540;
    for (int s = 0; s <= steps; s++) {
      final theta = (s / steps) * 2 * pi; // 0 = up
      final r = radiusAt(theta);
      final x = center.dx + r * sin(theta);
      final y = center.dy - r * cos(theta);
      if (s == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Screen-vertical fade via a gradient SHADER on the single stroke. It's
    // counter-rotated by the live wheel angle so it stays vertical on screen
    // as the wheel spins — bright across the top, fading out toward the
    // bottom, so the line darkens even where it bulges outside the box.
    final angle = rotation.value;
    // Theme-aware ring ink: white on dark, black on light.
    final ringInk = isDark ? Colors.white : Colors.black;
    final lit = ringInk.withValues(alpha: isDark ? 0.95 : 0.7);
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [lit, lit, ringInk.withValues(alpha: 0.0)],
      stops: const [0.0, 0.52, 0.96],
      transform: GradientRotation(-angle),
    ).createShader(Rect.fromCircle(center: center, radius: maxR));

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_TaraRingPainter old) =>
      old.birthIndex != birthIndex ||
      old.todayIndex != todayIndex ||
      old.selectedIndex != selectedIndex ||
      old.primaryColor != primaryColor ||
      old.isDark != isDark ||
      old.isJanmaDay != isJanmaDay ||
      !listEquals(old.wave, wave);
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
