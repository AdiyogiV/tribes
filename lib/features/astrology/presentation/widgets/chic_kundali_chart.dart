import 'package:flutter/material.dart';

class ChicKundaliChart extends StatelessWidget {
  final List<List<String>> houses;
  final List<String>? houseLabels;

  /// The transit planets to draw in the same chart
  final List<List<String>>? transitHouses;

  final Color strokeColor;
  final double lineWidth;
  final TextStyle planetStyle;
  final TextStyle? transitPlanetStyle;

  const ChicKundaliChart({
    super.key,
    required this.houses,
    this.houseLabels,
    this.transitHouses,
    required this.strokeColor,
    required this.lineWidth,
    required this.planetStyle,
    this.transitPlanetStyle,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _KundaliPainter(
        houses: houses,
        houseLabels: houseLabels,
        transitHouses: transitHouses,
        strokeColor: strokeColor,
        lineWidth: lineWidth,
        planetStyle: planetStyle,
        transitPlanetStyle: transitPlanetStyle,
      ),
    );
  }
}

class _KundaliPainter extends CustomPainter {
  final List<List<String>> houses;
  final List<String>? houseLabels;
  final List<List<String>>? transitHouses;

  final Color strokeColor;
  final double lineWidth;
  final TextStyle planetStyle;
  final TextStyle? transitPlanetStyle;

  _KundaliPainter({
    required this.houses,
    required this.houseLabels,
    this.transitHouses,
    required this.strokeColor,
    required this.lineWidth,
    required this.planetStyle,
    this.transitPlanetStyle,
  });

  // North Indian house geometry, declared once (DRY).
  // Anchor = the house's inner vertex (fractional of canvas size).
  static const List<Offset> _anchors = [
    Offset(0.5, 0.5), // H1 (center)
    Offset(0.25, 0.25), // H2 (top-left)
    Offset(0.25, 0.25), // H3 (top-left)
    Offset(0.5, 0.5), // H4 (center)
    Offset(0.25, 0.75), // H5 (bottom-left)
    Offset(0.25, 0.75), // H6 (bottom-left)
    Offset(0.5, 0.5), // H7 (center)
    Offset(0.75, 0.75), // H8 (bottom-right)
    Offset(0.75, 0.75), // H9 (bottom-right)
    Offset(0.5, 0.5), // H10 (center)
    Offset(0.75, 0.25), // H11 (top-right)
    Offset(0.75, 0.25), // H12 (top-right)
  ];

  // Direction each house's content is pushed away from its vertex.
  static const List<Offset> _pushDirs = [
    Offset(0, -1), // H1 up
    Offset(0, -1), // H2 up
    Offset(-1, 0), // H3 left
    Offset(-1, 0), // H4 left
    Offset(-1, 0), // H5 left
    Offset(0, 1), // H6 down
    Offset(0, 1), // H7 down
    Offset(0, 1), // H8 down
    Offset(1, 0), // H9 right
    Offset(1, 0), // H10 right
    Offset(1, 0), // H11 right
    Offset(0, -1), // H12 up
  ];

  /// Splits a raw house entry into clean planet tokens.
  List<String> _clean(List<String> raw) => raw
      .join(' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();

  /// The pixel point where a house's planets are drawn. [dist] matches the
  /// push distance used when rendering the text (42 natal, 72 transit).
  Offset _planetCenter(int i, double w, double h, double dist) => Offset(
        w * _anchors[i].dx + _pushDirs[i].dx * dist,
        h * _anchors[i].dy + _pushDirs[i].dy * dist,
      );

  /// Vedic drishti: house-count offsets a planet aspects. Every planet sees
  /// the 7th; Mars also 4th/8th, Jupiter 5th/9th, Saturn 3rd/10th.
  List<int> _aspectOffsets(String token) {
    final p = token.toLowerCase();
    final offsets = <int>[6];
    if (p.startsWith('ma')) {
      offsets.addAll(const [3, 7]);
    } else if (p.startsWith('ju')) {
      offsets.addAll(const [4, 8]);
    } else if (p.startsWith('sa')) {
      offsets.addAll(const [2, 9]);
    }
    return offsets;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- CHIC LAYERED GEOMETRY ---

    // Core structural paths
    final diagonals = Path()
      ..moveTo(0, 0)
      ..lineTo(w, h)
      ..moveTo(w, 0)
      ..lineTo(0, h);
    final innerDiamond = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..lineTo(0, h / 2)
      ..close();

    // Very subtle structural lines shared by the cross + inner diamond
    final linePaint = Paint()
      ..strokeWidth = lineWidth * 0.5
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..color = strokeColor.withValues(alpha: 0.2);

    canvas.drawPath(diagonals, linePaint);
    canvas.drawPath(innerDiamond, linePaint);

    // Very subtle flat tint for the birth-chart house regions. Built as ONE
    // combined path and filled once so overlapping inner-house triangles
    // don't stack alpha. No glow — just a whisper of color.
    if (transitHouses != null && transitPlanetStyle != null) {
      const s = 56.0;
      final highlightPath = Path();
      for (int i = 0; i < 12 && i < houses.length; i++) {
        final ax = w * _anchors[i].dx;
        final ay = h * _anchors[i].dy;
        final d = _pushDirs[i];
        final e1 = Offset(d.dx + d.dy, d.dy - d.dx);
        final e2 = Offset(d.dx - d.dy, d.dy + d.dx);
        highlightPath
          ..moveTo(ax, ay)
          ..lineTo(ax + e1.dx * s, ay + e1.dy * s)
          ..lineTo(ax + e2.dx * s, ay + e2.dy * s)
          ..close();
      }
      canvas.drawPath(
        highlightPath,
        Paint()
          ..color = strokeColor.withValues(alpha: 0.06)
          ..style = PaintingStyle.fill,
      );
    }

    // Aspect (drishti) connection lines between houses that hold planets.
    _drawAspects(canvas, w, h);

    // 3. Draw the per-house content (labels + planets).
    for (int i = 0; i < 12; i++) {
      if (i >= houses.length) break;

      // Calculate anchor for planets and apply the directional push
      final ax = w * _anchors[i].dx;
      final ay = h * _anchors[i].dy;
      final pDir = _pushDirs[i];

      final rawBPlanets = houses[i];
      final rawTPlanets = transitHouses != null && i < transitHouses!.length
          ? transitHouses![i]
          : const <String>[];

      // Clean the lists (upstream might pass pre-joined strings with spaces)
      final bPlanets = _clean(rawBPlanets);
      final tPlanets = _clean(rawTPlanets);

      final hasBirth = bPlanets.isNotEmpty;
      final hasTransit = tPlanets.isNotEmpty && transitPlanetStyle != null;

      // Dynamic stacking: Vertical for side houses, Horizontal for top/bottom houses
      final isSideHouse = pDir.dx != 0;
      final joinStr = isSideHouse ? '\n' : ' ';

      final bool isOverlayActive =
          transitHouses != null && transitPlanetStyle != null;

      if (houseLabels != null && i < houseLabels!.length) {
        final nameStr = houseLabels![i].trim();

        // Keep the label close to the central anchor with just a little
        // breathing room so it doesn't sit exactly on the vertex.
        final namePush = 20.0;
        final nameX = ax + (pDir.dx * namePush);
        final nameY = ay + (pDir.dy * namePush);

        _drawText(
          canvas: canvas,
          text: nameStr.toUpperCase(),
          style: planetStyle.copyWith(
            fontSize: 7.0, // Keep house labels small regardless of planet size
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
          ),
          center: Offset(nameX, nameY),
        );
      }

      if (isOverlayActive) {
        // Draw Birth Planets INSIDE the geometric triangle (Birth Zone / Inner Sanctum)
        // Pushed further out toward the edge of the highlighted area to make room for the labels
        if (hasBirth) {
          final bText = bPlanets.join(joinStr);
          _drawText(
              canvas: canvas,
              text: bText,
              style: planetStyle,
              center: Offset(ax + (pDir.dx * 42.0),
                  ay + (pDir.dy * 42.0))); // Tucked near the edge of the zone
        }

        // Draw Transits OUTSIDE the geometric triangle (Transit Zone / Weather)
        if (hasTransit) {
          final tText = tPlanets.join(joinStr);
          _drawText(
              canvas: canvas,
              text: tText,
              style: transitPlanetStyle!,
              center: Offset(ax + (pDir.dx * 72.0),
                  ay + (pDir.dy * 72.0))); // Pushed far outside the line
        }
      } else {
        // Standard Single Chart Mode (No overlay ring)
        if (hasBirth) {
          final bText = bPlanets.join(joinStr);
          _drawText(
              canvas: canvas,
              text: bText,
              style: planetStyle,
              center: Offset(
                  ax + (pDir.dx * 46.0),
                  ay +
                      (pDir.dy *
                          46.0))); // Centered in house (pushed out to clear labels)
        } else if (hasTransit) {
          // fallback if rendering just transits
          final tText = tPlanets.join(joinStr);
          _drawText(
              canvas: canvas,
              text: tText,
              style: transitPlanetStyle ?? planetStyle,
              center: Offset(ax + (pDir.dx * 46.0), ay + (pDir.dy * 46.0)));
        }
      }
    }
  }

  /// Draws simple, directional drishti lines from each aspecting planet to the
  /// houses it aspects. Uses transit planets when available (so it moves with
  /// time), else the natal chart. The mutual 7th is drawn once with an
  /// arrowhead on both ends.
  void _drawAspects(Canvas canvas, double w, double h) {
    final bool useTransit = transitHouses != null && transitPlanetStyle != null;
    final source = useTransit ? transitHouses! : houses;
    final dist = useTransit ? 72.0 : 42.0;

    // Collect every directed aspect (from house -> aspected house).
    final aspects = <int>{}; // key = from*12 + to
    for (int from = 0; from < 12 && from < source.length; from++) {
      final planets = _clean(source[from]);
      if (planets.isEmpty) continue;
      for (final p in planets) {
        for (final off in _aspectOffsets(p)) {
          final to = (from + off) % 12;
          if (to != from) aspects.add(from * 12 + to);
        }
      }
    }

    final center = Offset(w / 2, h / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth * 0.6
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..color = strokeColor.withValues(alpha: 0.22);

    final drawn = <int>{};
    for (final key in aspects) {
      if (!drawn.add(key)) continue;
      final from = key ~/ 12;
      final to = key % 12;
      final mutual = aspects.contains(to * 12 + from);
      if (mutual) drawn.add(to * 12 + from); // collapse the mutual 7th

      final a = _planetCenter(from, w, h, dist);
      final b = _planetCenter(to, w, h, 42.0);

      // Angular routing around the busy centre.
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      var dir = b - a;
      final len = dir.distance;
      if (len == 0) continue;
      dir = dir / len;
      var perp = Offset(-dir.dy, dir.dx);
      final fromCenter = mid - center;
      if (perp.dx * fromCenter.dx + perp.dy * fromCenter.dy < 0) {
        perp = Offset(-perp.dx, -perp.dy);
      }
      final ctrl =
          Offset(mid.dx + perp.dx * len * 0.25, mid.dy + perp.dy * len * 0.25);

      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(ctrl.dx, ctrl.dy)
          ..lineTo(b.dx, b.dy),
        paint,
      );

      _arrowHead(canvas, b, ctrl, paint); // gaze lands on the target house
      if (mutual) _arrowHead(canvas, a, ctrl, paint); // both ways for the 7th
    }
  }

  /// Draws a small V arrowhead at [tip], pointing away from [from].
  void _arrowHead(Canvas canvas, Offset tip, Offset from, Paint paint) {
    var d = tip - from;
    final l = d.distance;
    if (l == 0) return;
    d = d / l;
    final perp = Offset(-d.dy, d.dx);
    const headLen = 7.0;
    const headW = 4.0;
    final base = Offset(tip.dx - d.dx * headLen, tip.dy - d.dy * headLen);
    final left = Offset(base.dx + perp.dx * headW, base.dy + perp.dy * headW);
    final right = Offset(base.dx - perp.dx * headW, base.dy - perp.dy * headW);
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(right.dx, right.dy),
      paint,
    );
  }

  void _drawText({
    required Canvas canvas,
    required String text,
    required TextStyle style,
    required Offset center,
  }) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    final offset = Offset(
      center.dx - (textPainter.width / 2),
      center.dy - (textPainter.height / 2),
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _KundaliPainter oldDelegate) {
    return oldDelegate.houses != houses ||
        oldDelegate.houseLabels != houseLabels ||
        oldDelegate.transitHouses != transitHouses ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.lineWidth != lineWidth;
  }
}
