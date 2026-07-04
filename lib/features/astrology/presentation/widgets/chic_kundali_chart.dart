import 'package:flutter/material.dart';

class ChicKundaliChart extends StatelessWidget {
  final List<List<String>> houses;
  final List<String>? houseLabels;

  /// The transit planets to draw in the same chart
  final List<List<String>>? transitHouses;

  final Color strokeColor;
  final double lineWidth;
  final TextStyle houseLabelStyle;
  final TextStyle planetStyle;
  final TextStyle? transitPlanetStyle;

  const ChicKundaliChart({
    super.key,
    required this.houses,
    this.houseLabels,
    this.transitHouses,
    required this.strokeColor,
    required this.lineWidth,
    required this.houseLabelStyle,
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
        houseLabelStyle: houseLabelStyle,
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
  final TextStyle houseLabelStyle;
  final TextStyle planetStyle;
  final TextStyle? transitPlanetStyle;

  _KundaliPainter({
    required this.houses,
    required this.houseLabels,
    this.transitHouses,
    required this.strokeColor,
    required this.lineWidth,
    required this.houseLabelStyle,
    required this.planetStyle,
    this.transitPlanetStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // 1. Draw the Diagonals (X)
    canvas.drawLine(const Offset(0, 0), Offset(w, h), paint);
    canvas.drawLine(Offset(w, 0), Offset(0, h), paint);

    // 2. Draw the Inner Diamond
    final path = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..lineTo(0, h / 2)
      ..close();
    canvas.drawPath(path, paint);

    // 3. Define the true geometric inner corners (anchors) for the planets
    final houseAnchors = [
      const Offset(0.5, 0.5), // H1 (Absolute Center)
      const Offset(0.25, 0.25), // H2 (Top-Left inner corner)
      const Offset(0.25, 0.25), // H3 (Top-Left inner corner)
      const Offset(0.5, 0.5), // H4 (Absolute Center)
      const Offset(0.25, 0.75), // H5 (Bottom-Left inner corner)
      const Offset(0.25, 0.75), // H6 (Bottom-Left inner corner)
      const Offset(0.5, 0.5), // H7 (Absolute Center)
      const Offset(0.75, 0.75), // H8 (Bottom-Right inner corner)
      const Offset(0.75, 0.75), // H9 (Bottom-Right inner corner)
      const Offset(0.5, 0.5), // H10 (Absolute Center)
      const Offset(0.75, 0.25), // H11 (Top-Right inner corner)
      const Offset(0.75, 0.25), // H12 (Top-Right inner corner)
    ];

    // The direction to push the text block away from the vertex to avoid crossing lines
    final housePushDirs = [
      const Offset(0, -1), // H1 (Push Up)
      const Offset(0, -1), // H2 (Push Up)
      const Offset(-1, 0), // H3 (Push Left)
      const Offset(-1, 0), // H4 (Push Left)
      const Offset(-1, 0), // H5 (Push Left)
      const Offset(0, 1), // H6 (Push Down)
      const Offset(0, 1), // H7 (Push Down)
      const Offset(0, 1), // H8 (Push Down)
      const Offset(1, 0), // H9 (Push Right)
      const Offset(1, 0), // H10 (Push Right)
      const Offset(1, 0), // H11 (Push Right)
      const Offset(0, -1), // H12 (Push Up)
    ];

    // Center of mass for the Zodiac labels
    final labelCenters = [
      const Offset(0.5, 0.25), // H1
      const Offset(0.25, 0.12), // H2
      const Offset(0.12, 0.25), // H3
      const Offset(0.25, 0.5), // H4
      const Offset(0.12, 0.75), // H5
      const Offset(0.25, 0.88), // H6
      const Offset(0.5, 0.75), // H7
      const Offset(0.75, 0.88), // H8
      const Offset(0.88, 0.75), // H9
      const Offset(0.75, 0.5), // H10
      const Offset(0.88, 0.25), // H11
      const Offset(0.75, 0.12), // H12
    ];

    for (int i = 0; i < 12; i++) {
      if (i >= houses.length) break;

      // Calculate anchor for planets and apply the directional push
      final ax = w * houseAnchors[i].dx;
      final ay = h * houseAnchors[i].dy;
      final pDir = housePushDirs[i];

      final rawBPlanets = houses[i];
      final rawTPlanets = transitHouses != null && i < transitHouses!.length
          ? transitHouses![i]
          : const <String>[];

      // Clean the lists (upstream might pass pre-joined strings with spaces)
      final bPlanets = rawBPlanets
          .join(' ')
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();
      final tPlanets = rawTPlanets
          .join(' ')
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();

      final hasBirth = bPlanets.isNotEmpty;
      final hasTransit = tPlanets.isNotEmpty && transitPlanetStyle != null;

      // Dynamic stacking: Vertical for side houses, Horizontal for top/bottom houses
      final isSideHouse = pDir.dx != 0;
      final joinStr = isSideHouse ? '\n' : ' ';

      // Calculate perfect geometric background triangle for the corner
      final double S =
          52.0; // The cutoff line distance (increased for larger inner section)
      final edge1 = Offset(pDir.dx + pDir.dy, pDir.dy - pDir.dx);
      final edge2 = Offset(pDir.dx - pDir.dy, pDir.dy + pDir.dx);
      final p2 = Offset(ax + edge1.dx * S, ay + edge1.dy * S);
      final p3 = Offset(ax + edge2.dx * S, ay + edge2.dy * S);

      final bool isOverlayActive =
          transitHouses != null && transitPlanetStyle != null;

      if (houseLabels != null && i < houseLabels!.length) {
        final nameStr = houseLabels![i].trim();

        // Push the Zodiac Name into the innermost corner of the house.
        final namePush = 14.0;
        final nameX = ax + (pDir.dx * namePush);
        final nameY = ay + (pDir.dy * namePush);

        _drawText(
          canvas: canvas,
          text: nameStr.toUpperCase(),
          style: houseLabelStyle.copyWith(
              letterSpacing: 1.0, fontWeight: FontWeight.w500),
          center: Offset(nameX, nameY),
        );
      }

      if (isOverlayActive) {
        // ALWAYS draw the corner-aligned highlighted space to define the structural "Birth Zone"
        // This gives the chart a unified 12-pointed inner ring.
        final bgPath = Path()
          ..moveTo(ax, ay)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close();

        final bgPaint = Paint()
          ..color = strokeColor.withValues(
              alpha:
                  0.08) // More subtle highlight, removing the harsh cutoff line entirely
          ..style = PaintingStyle.fill;
        canvas.drawPath(bgPath, bgPaint);

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
