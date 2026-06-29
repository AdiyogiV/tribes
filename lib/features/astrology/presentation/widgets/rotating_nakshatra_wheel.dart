import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Decorative, slowly auto-rotating Nakshatra wheel image with the same
/// press-and-hold magnifier as the dashboard's [NakshatraRingWidget] — minus
/// the Tara ring / data dependencies.
///
/// Magnifier behaviour (identical to the dashboard):
///  • Press-and-hold (50 ms) magnifies the wheel, anchored at the press point.
///  • Dragging while held rotates the wheel.
///  • Releasing animates back to rest and resumes the idle auto-spin.
class RotatingNakshatraWheel extends StatefulWidget {
  /// Diameter of the wheel in logical pixels.
  final double size;

  /// One full idle rotation takes this long. Defaults to a calm 120s spin.
  final Duration rotationPeriod;

  /// When false, the wheel renders static (no idle animation).
  final bool animate;

  /// Enables the press-and-hold magnifier.
  final bool enableZoom;

  /// Magnification applied while held. Defaults to 1.5x.
  final double zoomScale;

  const RotatingNakshatraWheel({
    super.key,
    required this.size,
    this.rotationPeriod = const Duration(seconds: 120),
    this.animate = true,
    this.enableZoom = true,
    this.zoomScale = 1.5,
  });

  @override
  State<RotatingNakshatraWheel> createState() => _RotatingNakshatraWheelState();
}

class _RotatingNakshatraWheelState extends State<RotatingNakshatraWheel>
    with SingleTickerProviderStateMixin {
  /// Idle spin: value 0→1 maps to 0→2π. Paused while magnified.
  late final AnimationController _spin;

  /// Extra rotation accumulated from drag-while-held (radians).
  double _dragAngle = 0;

  bool _isMagnified = false;
  Offset _magnifyOrigin = Offset.zero;
  double? _lastPanAngle;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: widget.rotationPeriod);
    if (widget.animate) _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  /// Fold the current idle-spin angle into [_dragAngle] and zero the spin so
  /// pausing/resuming [repeat] never causes a visual jump.
  void _foldSpin() {
    _dragAngle += _spin.value * 2 * math.pi;
    _spin.value = 0;
  }

  void _onMagnifyStart(LongPressStartDetails d) {
    HapticFeedback.lightImpact();
    _foldSpin();
    _spin.stop();
    setState(() {
      _isMagnified = true;
      _magnifyOrigin = d.localPosition;
    });
    final cx = widget.size / 2;
    _lastPanAngle =
        math.atan2(d.localPosition.dx - cx, -(d.localPosition.dy - cx));
  }

  void _onMagnifyMove(LongPressMoveUpdateDetails d) {
    if (_lastPanAngle == null) return;
    final cx = widget.size / 2;
    final current =
        math.atan2(d.localPosition.dx - cx, -(d.localPosition.dy - cx));
    double delta = current - _lastPanAngle!;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    _lastPanAngle = current;
    setState(() => _dragAngle += delta * 0.65);
  }

  void _onMagnifyEnd(LongPressEndDetails d) {
    setState(() => _isMagnified = false);
    _lastPanAngle = null;
    if (widget.animate) _spin.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.size;

    final image = ClipOval(
      child: Image.asset(
        'assets/images/nakshatra_wheel.jpeg',
        fit: BoxFit.cover,
        width: total,
        height: total,
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
    );

    final rotating = SizedBox(
      width: total,
      height: total,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, child) => Transform.rotate(
          angle: _spin.value * 2 * math.pi + _dragAngle,
          child: child,
        ),
        child: image,
      ),
    );

    if (!widget.enableZoom) return rotating;

    // Map the press point inside the wheel to AnimatedScale's alignment
    // convention (−1..1) so the zoom grows from where the finger lands.
    final magAlignX = total > 0 ? (_magnifyOrigin.dx / total) * 2 - 1 : 0.0;
    final magAlignY = total > 0 ? (_magnifyOrigin.dy / total) * 2 - 1 : 0.0;

    return SizedBox(
      width: total,
      height: total,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
                duration: const Duration(milliseconds: 50)),
            (instance) {
              instance
                ..onLongPressStart = _onMagnifyStart
                ..onLongPressMoveUpdate = _onMagnifyMove
                ..onLongPressEnd = _onMagnifyEnd;
            },
          ),
        },
        child: AnimatedScale(
          scale: _isMagnified ? widget.zoomScale : 1.0,
          alignment: Alignment(
            magAlignX.clamp(-1.0, 1.0),
            magAlignY.clamp(-1.0, 1.0),
          ),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: rotating,
        ),
      ),
    );
  }
}
