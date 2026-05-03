import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Timestamped data point for charts.
typedef TimedValue = ({DateTime time, double value});

// ─────────────────────────────────────────────────────────────────────────────
// TimestampedTrendPainter — Chart that renders real timestamps on x-axis
// ─────────────────────────────────────────────────────────────────────────────

class TimestampedTrendPainter extends CustomPainter {
  final List<TimedValue> data;
  final Color lineColor;
  final Color fillColor;
  final Color dotColor;
  final Color gridColor;
  final Color labelColor;
  final bool isDark;
  final bool showDayBoundaries;

  TimestampedTrendPainter({
    required this.data,
    required this.lineColor,
    required this.fillColor,
    required this.dotColor,
    required this.gridColor,
    required this.labelColor,
    required this.isDark,
    this.showDayBoundaries = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final firstTime = data.first.time;
    final lastTime = data.last.time;
    final totalDuration = lastTime.difference(firstTime).inSeconds.toDouble();
    if (totalDuration <= 0) return;

    final minVal = data.map((d) => d.value).reduce(math.min);
    final maxVal = data.map((d) => d.value).reduce(math.max);
    final range = maxVal - minVal;
    final effectiveRange = range == 0 ? 1.0 : range;
    final padding = effectiveRange * 0.1;

    // Horizontal grid lines with value labels
    final gridPaint = Paint()..color = gridColor;
    for (int i = 0; i <= 3; i++) {
      final y = (i / 3) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      // Value labels on right edge
      final gridVal =
          maxVal + padding - (i / 3) * (effectiveRange + padding * 2);
      final tp = TextPainter(
        text: TextSpan(
          text: gridVal == gridVal.roundToDouble()
              ? '${gridVal.round()}'
              : gridVal.toStringAsFixed(1),
          style: TextStyle(fontSize: 8, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width, y + 2));
    }

    // Day boundary lines (midnight markers)
    if (showDayBoundaries) {
      final boundaryPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1;

      var day = DateTime(firstTime.year, firstTime.month, firstTime.day + 1);
      while (day.isBefore(lastTime)) {
        final x = (day.difference(firstTime).inSeconds / totalDuration)
            * size.width;
        canvas.drawLine(
            Offset(x, 0), Offset(x, size.height), boundaryPaint);
        day = day.add(const Duration(days: 1));
      }
    }

    // Map data points to canvas coordinates
    final points = <Offset>[];
    for (final d in data) {
      final x = (d.time.difference(firstTime).inSeconds / totalDuration)
          * size.width;
      final normalized =
          (d.value - minVal + padding) / (effectiveRange + padding * 2);
      final y = size.height - normalized * size.height;
      points.add(Offset(x, y));
    }

    // Fill area
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);

    // Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots — show all if ≤ 30 points, otherwise only endpoints
    if (points.length <= 30) {
      for (final p in points) {
        canvas.drawCircle(p, 3.5, Paint()..color = dotColor);
        canvas.drawCircle(p, 2,
            Paint()..color = isDark ? const Color(0xFF1E1E1E) : Colors.white);
      }
    } else {
      // Just show first and last
      for (final p in [points.first, points.last]) {
        canvas.drawCircle(p, 4, Paint()..color = dotColor);
        canvas.drawCircle(p, 2.5,
            Paint()..color = isDark ? const Color(0xFF1E1E1E) : Colors.white);
      }
    }

    // Last value label
    final lastPoint = points.last;
    final lastVal = data.last.value;
    final tp = TextPainter(
      text: TextSpan(
        text: lastVal == lastVal.roundToDouble()
            ? '${lastVal.round()}'
            : lastVal.toStringAsFixed(1),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: lineColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(
      lastPoint.dx - tp.width - 6,
      lastPoint.dy - tp.height - 4,
    ));
  }

  @override
  bool shouldRepaint(covariant TimestampedTrendPainter old) =>
      old.data != data || old.lineColor != lineColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// TrendChartPainter — Legacy flat-data chart (backwards compatible)
// ─────────────────────────────────────────────────────────────────────────────

class TrendChartPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final Color fillColor;
  final Color dotColor;
  final Color gridColor;
  final bool isDark;

  TrendChartPainter({
    required this.data,
    required this.lineColor,
    required this.fillColor,
    required this.dotColor,
    required this.gridColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce(math.min);
    final maxVal = data.reduce(math.max);
    final range = maxVal - minVal;
    final effectiveRange = range == 0 ? 1.0 : range;
    final padding = effectiveRange * 0.1;

    for (int i = 0; i <= 3; i++) {
      final y = (i / 3) * size.height;
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), Paint()..color = gridColor);
    }

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final normalized =
          (data[i] - minVal + padding) / (effectiveRange + padding * 2);
      final y = size.height - normalized * size.height;
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = dotColor);
      canvas.drawCircle(p, 2.5,
          Paint()..color = isDark ? const Color(0xFF1E1E1E) : Colors.white);
    }

    final lastPoint = points.last;
    final lastValue = data.last;
    final textPainter = TextPainter(
      text: TextSpan(
        text: lastValue == lastValue.roundToDouble()
            ? '${lastValue.round()}'
            : lastValue.toStringAsFixed(1),
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: lineColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(
      lastPoint.dx - textPainter.width - 6,
      lastPoint.dy - textPainter.height - 4,
    ));
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter old) =>
      old.data != data || old.lineColor != lineColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Helpers
// ─────────────────────────────────────────────────────────────────────────────

String shortDayName(int weekday) {
  const days = ['', 'M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return days[weekday];
}
