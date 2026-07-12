import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/vedic_time_utils.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/features/astrology/data/utils/nakshatra_data.dart';
import 'package:aurogram/features/astrology/data/utils/daily_vibe.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
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

  // ── Internal API (called by NakshatraRingWidget only) ──────────────────────

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

  /// The date currently shown at the top of the wheel.
  DateTime get _displayedDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .add(Duration(days: _cumulativeOffset));
  }

  /// True when the wheel is at today's position (default state).
  bool get _isAtToday => _cumulativeOffset == 0;

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

    // Activate the overlay portal so the wheel renders above sibling cards
    // from the very first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_wheelPortalController.isShowing) {
        _wheelPortalController.show();
      }
    });
  }

  @override
  void didUpdateWidget(NakshatraRingWidget old) {
    super.didUpdateWidget(old);
    if (old.wheelResetSignal != widget.wheelResetSignal) {
      old.wheelResetSignal?.removeListener(_onExternalResetToToday);
      widget.wheelResetSignal?.addListener(_onExternalResetToToday);
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

    final vibeContent = _buildDailyVibeContent(c, isDark, cardColor);
    final wheel = _buildWheel(c, isDark);

    // Header summary: energy label + alignment %, derived from today's Tara.
    final headerVibe = DailyVibe.forUser(
      birthIndex: _birthIndex,
      todayIndex: _activeIndex,
    );
    final headerTara = TaraBala.calculate(_birthIndex, _activeIndex);
    final headerAlignment = _taraAlignmentPercent(headerTara.type);

    return Material(
      color: cardColor,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── HEADER: Context ──
          Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Prominent: energy label + alignment %.
                for (final line in [
                  if (headerVibe != null) headerVibe.label.toUpperCase(),
                ])
                  Text(
                    line,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      letterSpacing: 3.0,
                      fontWeight: FontWeight.w800,
                      color: c,
                    ),
                  ),
                if (headerVibe != null)
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
          ),

          // ── MOON: elegant, on-brand, sits just above the wheel ──
          _buildMoon(c, isDark),

          // ── WHEEL AREA ──
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingXs,
            ),
            child: wheel,
          ),

          // ── VIBE CONTENT ──
          vibeContent,
        ],
      ),
    );
  }

  // ─── Daily Vibe ─────────────────────────────────────────────────────────
  //
  // Plain-English guidance derived from today's Tara Bala. Returns content
  // only (no Material) — it now shares the wheel's card. See build().

  Widget _buildDailyVibeContent(Color c, bool isDark, Color cardColor) {
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

    final isAtToday = _isAtToday;
    // Narrative: AI insight on today, static vibe template otherwise.
    final aiMessage = widget.insight?.displayMessage ?? '';
    final useInsight = isAtToday && aiMessage.isNotEmpty;
    final narrativeText = useInsight ? aiMessage : vibe.narrative;

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
              fontSize: AppTheme.babaTextSize,
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
            darkColor:
                isDark ? Colors.black : const Color(0xFFCFC7B6),
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
    final rawNum =
        samvat['number'] ?? samvat['tithi_number'] ?? samvat['tithiNumber'];
    int? tithiNum;
    if (rawNum is num) {
      tithiNum = rawNum.toInt();
    } else if (rawNum != null) {
      tithiNum = int.tryParse(rawNum.toString());
    }
    if (tithiNum == null) return null;
    if (tithiNum > 15) return tithiNum.clamp(16, 30);
    final rawPaksha =
        samvat['paksha']?.toString() ?? samvat['tithiPaksha']?.toString() ?? '';
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
                      ? Border.all(color: c.withValues(alpha: 0.25), width: 0.8)
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
                      color: const Color(0xFFFFD700).withValues(alpha: 0.45),
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
// Tara ring painter
// =============================================================================

/// Quality weight per tara type: -1 pinches the aura inward (caution),
/// +1 bulges it outward (most auspicious). Shared by the wave painter and the
/// alignment-percentage readout so they never drift apart.
const Map<TaraType, double> _taraQuality = {
  TaraType.vadha: -1.0,
  TaraType.pratyari: -0.7,
  TaraType.vipat: -0.45,
  TaraType.janma: 0.15,
  TaraType.kshema: 0.5,
  TaraType.mitra: 0.6,
  TaraType.sampat: 0.75,
  TaraType.sadhaka: 0.85,
  TaraType.paramaMitra: 1.0,
};

/// Maps a tara quality (-1..+1) to a friendly 0..100 "alignment" percentage.
int _taraAlignmentPercent(TaraType t) =>
    (50 + (_taraQuality[t] ?? 0.0) * 47).round().clamp(0, 100);

class _TaraRingPainter extends CustomPainter {
  final int birthIndex;
  final int todayIndex;
  final int selectedIndex;
  final Color primaryColor;
  final bool isDark;
  final bool isJanmaDay;

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
  }) : super(repaint: rotation);

  static const int _n = 27;
  static const double _seg = 2 * pi / _n;
  static const double _ashwiniOffset = _NakshatraRingWidgetState._ashwiniOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Per-nakshatra alignment quality relative to the birth star.
    // Without birth data the aura is a calm, perfect circle.
    final q = List<double>.filled(_n, 0.0);
    if (birthIndex >= 0) {
      for (int i = 0; i < _n; i++) {
        final tara = TaraBala.calculate(birthIndex, i);
        q[i] = _taraQuality[tara.type] ?? 0.0;
      }
    }

    // Aura geometry. Bulges OUT past the artwork on auspicious nakshatras,
    // pinches IN on cautionary ones. Sized to stay just inside the card.
    // Dramatic amplitude that bulges OUT past the wheel (and the card edge
    // if needed). The line self-fades toward the screen bottom, so even the
    // outward bulges darken as they go down.
    final baseR = size.width / 2 - 9.0;
    const amp = 18.0; // dramatic-ish, spills slightly outside
    final maxR = baseR + amp;

    // Smooth radius at any angle by cosine-interpolating between the two
    // nearest nakshatra centres → soft, continuous waviness.
    double radiusAt(double theta) {
      final f = ((_ashwiniOffset - theta) / _seg) % _n;
      final i0 = f.floor() % _n;
      final i1 = (i0 + 1) % _n;
      final t = f - f.floor();
      final w = (1 - cos(t * pi)) / 2;
      final qv = q[i0] * (1 - w) + q[i1] * w;
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
