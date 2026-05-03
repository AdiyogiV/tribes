import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DoshaTrendPainter — Multi-line timestamped chart with Y-axis labels
// ─────────────────────────────────────────────────────────────────────────────

class DoshaTrendPainter extends CustomPainter {
  final List<({DateTime time, Map<String, double> doshas})> data;
  final Color gridColor;
  final Color labelColor;
  final bool isDark;

  DoshaTrendPainter({
    required this.data,
    required this.gridColor,
    required this.labelColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    // ── Layout: leave room for Y-axis (left), end labels (right), X-axis (bottom)
    const leftPad = 32.0;
    const rightPad = 36.0; // space for end-value labels
    const bottomPad = 20.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - bottomPad;

    // ── Time range
    final firstTime = data.first.time;
    final lastTime = data.last.time;
    final totalSec =
        lastTime.difference(firstTime).inSeconds.toDouble();
    if (totalSec <= 0) return;

    // ── Value range — find the actual min/max across all doshas
    double dataMin = 100, dataMax = 0;
    for (final d in data) {
      for (final v in d.doshas.values) {
        dataMin = math.min(dataMin, v);
        dataMax = math.max(dataMax, v);
      }
    }
    // Add padding so lines don't touch edges
    final dataRange = dataMax - dataMin;
    final displayPad = math.max(dataRange * 0.15, 2.0);
    final yMin = (dataMin - displayPad).clamp(0.0, 100.0);
    final yMax = (dataMax + displayPad).clamp(0.0, 100.0);
    final yRange = yMax - yMin;

    double valToY(double v) {
      if (yRange == 0) return chartH / 2;
      return chartH - ((v - yMin) / yRange) * chartH;
    }

    double timeToX(DateTime t) {
      return leftPad +
          (t.difference(firstTime).inSeconds / totalSec) * chartW;
    }

    // Chart right edge (where lines stop)
    final chartRight = leftPad + chartW;

    // ── Y-axis grid & labels
    final gridSteps = _niceGridSteps(yMin, yMax, 4);
    final gridPaint = Paint()..color = gridColor;
    for (final gv in gridSteps) {
      final y = valToY(gv);
      if (y < 0 || y > chartH) continue;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(chartRight, y),
        gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${gv.round()}%',
          style: TextStyle(fontSize: 9, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // ── X-axis time labels
    _paintXAxisLabels(canvas, size, firstTime, lastTime, leftPad,
        chartW, chartH);

    // ── Day boundary lines
    final bPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    var day =
        DateTime(firstTime.year, firstTime.month, firstTime.day + 1);
    while (day.isBefore(lastTime)) {
      final x = timeToX(day);
      if (x > leftPad && x < chartRight) {
        canvas.drawLine(Offset(x, 0), Offset(x, chartH), bPaint);
      }
      day = day.add(const Duration(days: 1));
    }

    // ── Draw each dosha series (collect end labels to avoid overlap)
    final endLabels = <({double y, String text, Color color})>[];
    _drawSeries(canvas, 'vata', vataColor, timeToX, valToY,
        chartH, chartRight, leftPad, endLabels);
    _drawSeries(canvas, 'pitta', pittaColor, timeToX, valToY,
        chartH, chartRight, leftPad, endLabels);
    _drawSeries(canvas, 'kapha', kaphaColor, timeToX, valToY,
        chartH, chartRight, leftPad, endLabels);

    // ── Paint end labels with collision avoidance (in the right margin)
    _paintEndLabels(canvas, endLabels, chartRight + 4);
  }

  void _drawSeries(
    Canvas canvas,
    String key,
    Color color,
    double Function(DateTime) timeToX,
    double Function(double) valToY,
    double chartH,
    double chartW,
    double leftPad,
    List<({double y, String text, Color color})> endLabels,
  ) {
    final points = <Offset>[];
    for (final d in data) {
      final v = d.doshas[key] ?? 33;
      final x = timeToX(d.time).clamp(leftPad, chartW);
      final y = valToY(v).clamp(0.0, chartH);
      points.add(Offset(x, y));
    }

    if (points.length < 2) return;

    // Smooth path using cubic Bézier curves
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final cpX = (prev.dx + cur.dx) / 2;
      path.cubicTo(cpX, prev.dy, cpX, cur.dy, cur.dx, cur.dy);
    }

    // Fill under curve
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, chartH)
      ..lineTo(points.first.dx, chartH)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = color.withValues(alpha: 0.08),
    );

    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots — only show if ≤30 points, otherwise just first+last
    if (points.length <= 30) {
      for (final p in points) {
        canvas.drawCircle(p, 3, Paint()..color = color);
        canvas.drawCircle(
          p,
          1.5,
          Paint()
            ..color =
                isDark ? const Color(0xFF1E1E1E) : Colors.white,
        );
      }
    } else {
      for (final p in [points.first, points.last]) {
        canvas.drawCircle(p, 4, Paint()..color = color);
        canvas.drawCircle(
          p,
          2,
          Paint()
            ..color =
                isDark ? const Color(0xFF1E1E1E) : Colors.white,
        );
      }
    }

    // Collect end label for later (drawn with collision avoidance)
    final lastVal = data.last.doshas[key] ?? 33;
    final lp = points.last;
    endLabels.add((y: lp.dy, text: '${lastVal.round()}%', color: color));
  }

  /// Paint end-value labels with vertical collision avoidance.
  /// Labels are placed in the right margin, outside the chart lines.
  void _paintEndLabels(
    Canvas canvas,
    List<({double y, String text, Color color})> labels,
    double labelX,
  ) {
    if (labels.isEmpty) return;

    const labelH = 12.0; // approximate height of a 9px label
    const minGap = 2.0;

    // Sort by Y position (top to bottom)
    final sorted = List.of(labels)..sort((a, b) => a.y.compareTo(b.y));

    // Resolve overlaps: push labels apart
    final yPositions = sorted.map((l) => l.y).toList();
    for (int pass = 0; pass < 5; pass++) {
      for (int i = 1; i < yPositions.length; i++) {
        final gap = yPositions[i] - yPositions[i - 1];
        if (gap < labelH + minGap) {
          final push = (labelH + minGap - gap) / 2;
          yPositions[i - 1] -= push;
          yPositions[i] += push;
        }
      }
    }

    for (int i = 0; i < sorted.length; i++) {
      final label = sorted[i];
      final tp = TextPainter(
        text: TextSpan(
          text: label.text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: label.color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final x = labelX;
      tp.paint(canvas, Offset(x, yPositions[i] - tp.height / 2));
    }
  }

  void _paintXAxisLabels(
    Canvas canvas,
    Size size,
    DateTime firstTime,
    DateTime lastTime,
    double leftPad,
    double chartW,
    double chartH,
  ) {
    final totalHours =
        lastTime.difference(firstTime).inMinutes / 60.0;
    final labelY = chartH + 4;

    // Choose step: <24h → 4h, <72h → 12h, else → 1 day
    Duration step;
    String Function(DateTime) fmt;
    if (totalHours <= 24) {
      step = const Duration(hours: 4);
      fmt = (d) => '${d.hour.toString().padLeft(2, '0')}:00';
    } else if (totalHours <= 72) {
      step = const Duration(hours: 12);
      fmt = (d) => '${_monthAbbr(d.month)} ${d.day}, ${d.hour}:00';
    } else {
      step = const Duration(days: 1);
      fmt = (d) => '${_monthAbbr(d.month)} ${d.day}';
    }

    // Start at the next clean boundary
    var t = _ceilToStep(firstTime, step);
    final totalSec =
        lastTime.difference(firstTime).inSeconds.toDouble();

    while (t.isBefore(lastTime)) {
      final x = leftPad +
          (t.difference(firstTime).inSeconds / totalSec) * chartW;
      if (x > leftPad + 10 && x < leftPad + chartW - 10) {
        final tp = TextPainter(
          text: TextSpan(
            text: fmt(t),
            style: TextStyle(fontSize: 9, color: labelColor),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, labelY));
      }
      t = t.add(step);
    }
  }

  /// Compute nice grid step values for Y-axis.
  List<double> _niceGridSteps(double min, double max, int maxSteps) {
    final range = max - min;
    if (range <= 0) return [min];

    final rawStep = range / maxSteps;
    final mag = math.pow(10, (math.log(rawStep) / math.ln10).floor());
    final normalized = rawStep / mag;
    double niceStep;
    if (normalized <= 1.5) {
      niceStep = 1 * mag.toDouble();
    } else if (normalized <= 3) {
      niceStep = 2 * mag.toDouble();
    } else if (normalized <= 7) {
      niceStep = 5 * mag.toDouble();
    } else {
      niceStep = 10 * mag.toDouble();
    }

    final result = <double>[];
    var v = (min / niceStep).ceil() * niceStep;
    while (v <= max) {
      result.add(v);
      v += niceStep;
    }
    return result;
  }

  DateTime _ceilToStep(DateTime t, Duration step) {
    final ms = t.millisecondsSinceEpoch;
    final stepMs = step.inMilliseconds;
    final next = ((ms / stepMs).ceil()) * stepMs;
    return DateTime.fromMillisecondsSinceEpoch(next);
  }

  @override
  bool shouldRepaint(covariant DoshaTrendPainter old) =>
      old.data != data;

  static String _monthAbbr(int m) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m.clamp(1, 12)];
  }
}
