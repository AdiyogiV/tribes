import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:aurogram/features/astrology/data/utils/sky_connection.dart';

class ChicKundaliChart extends StatelessWidget {
  final List<List<String>> houses;
  final List<String>? houseLabels;

  /// The transit planets to draw in the same chart
  final List<List<String>>? transitHouses;

  /// Curated transit→natal aspect lines to draw. When provided (non-empty),
  /// these replace the generic whole-sign drishti — only the tight, meaningful
  /// "sky is touching you" connections are shown.
  final List<SkyConnection>? connections;

  final Color strokeColor;
  final double lineWidth;
  final TextStyle planetStyle;
  final TextStyle? transitPlanetStyle;

  const ChicKundaliChart({
    super.key,
    required this.houses,
    this.houseLabels,
    this.transitHouses,
    this.connections,
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
        connections: connections,
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
  final List<SkyConnection>? connections;

  final Color strokeColor;
  final double lineWidth;
  final TextStyle planetStyle;
  final TextStyle? transitPlanetStyle;

  _KundaliPainter({
    required this.houses,
    required this.houseLabels,
    this.transitHouses,
    this.connections,
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

  /// Vedic drishti offsets (inclusive, own house = 1st, so 7th = +6).
  ///
  /// EVERY planet aspects its 7th house — that is the universal baseline, not
  /// something "special". Mars, Jupiter and Saturn additionally cast their
  /// special drishti *on top of* the 7th (never instead of it), so they get
  /// three aspects each. Clutter is no longer a concern because [_drawAspects]
  /// only draws a line when the aspected house actually holds a planet.
  List<int> _aspectOffsets(String token) {
    final p = token.toLowerCase();
    if (p.startsWith('ma')) return const [3, 6, 7]; // 4th, 7th, 8th
    if (p.startsWith('ju')) return const [4, 6, 8]; // 5th, 7th, 9th
    if (p.startsWith('sa')) return const [2, 6, 9]; // 3rd, 7th, 10th
    return const [6]; // every other planet: universal 7th aspect
  }

  /// A distinct colour per planet so each aspect line can be traced back to
  /// its source. Matched on the first two letters of the token (Su, Mo, Ma,
  /// Me, Ju, Ve, Sa, Ra, Ke).
  Color _planetColor(String token) {
    final p = token.toLowerCase();
    if (p.startsWith('su')) return const Color(0xFFFFB74D); // Sun - amber
    if (p.startsWith('mo')) return const Color(0xFFE0E0E0); // Moon - silver
    if (p.startsWith('ma')) return const Color(0xFFEF5350); // Mars - red
    if (p.startsWith('me')) return const Color(0xFF66BB6A); // Mercury - green
    if (p.startsWith('ju')) return const Color(0xFFFFD54F); // Jupiter - gold
    if (p.startsWith('ve')) return const Color(0xFFF06292); // Venus - pink
    if (p.startsWith('sa')) return const Color(0xFF42A5F5); // Saturn - blue
    if (p.startsWith('ra')) return const Color(0xFF8D6E63); // Rahu - brown
    if (p.startsWith('ke')) return const Color(0xFFBA68C8); // Ketu - purple
    return strokeColor; // fallback
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
          _drawColoredPlanets(
              canvas: canvas,
              planets: tPlanets,
              style: transitPlanetStyle!,
              joinStr: joinStr,
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
          _drawColoredPlanets(
              canvas: canvas,
              planets: tPlanets,
              style: transitPlanetStyle ?? planetStyle,
              joinStr: joinStr,
              center: Offset(ax + (pDir.dx * 46.0), ay + (pDir.dy * 46.0)));
        }
      }
    }
  }

  /// Draws the curated "sky is touching you" lines.
  ///
  /// When [connections] is provided we draw ONLY those — the tight transit→natal
  /// aspects that actually matter right now, coloured by their nature
  /// (supportive gold / tense red / wild purple) with the strongest one drawn
  /// as the bright, thick "hero". An empty list correctly draws nothing (a
  /// quiet sky). When [connections] is null we fall back to the legacy
  /// whole-sign drishti so natal-only charts still show something.
  void _drawAspects(Canvas canvas, double w, double h) {
    final conns = connections;
    if (conns != null) {
      _drawConnections(canvas, w, h, conns);
      return;
    }
    _drawDrishtiFallback(canvas, w, h);
  }

  /// Draws each curated connection as a slightly-wavy line from the transiting
  /// planet (outer ring) to the natal planet (inner ring). The first entry is
  /// the hero (brightest + thickest) since [computeSkyConnections] sorts by
  /// tightness.
  void _drawConnections(
      Canvas canvas, double w, double h, List<SkyConnection> conns) {
    for (int i = 0; i < conns.length; i++) {
      final c = conns[i];
      final isHero = i == 0;
      // Colour the line by its SOURCE planet so it's traceable back to the
      // transiting body (Saturn=blue, Jupiter=gold, ...).
      final base = _planetColor(c.transitPlanet);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..strokeCap = StrokeCap.round
        ..strokeWidth = lineWidth * (isHero ? 3.5 : 2.0)
        ..color = base.withValues(alpha: isHero ? 1.0 : 0.32);

      final a = _planetCenter(c.fromSign, w, h, 64.0); // just below transit planet
      final b = _planetCenter(c.toSign, w, h, 27.0); // just above target zodiac
      var dir = b - a;
      final len = dir.distance;
      if (len == 0) continue;
      dir = dir / len;
      final perp = Offset(-dir.dy, dir.dx);

      final rnd = math.Random(c.fromSign * 100 + c.toSign);
      final amplitude = isHero ? 14.0 : 10.0;

      // Bow the line OUTWARD, around the chart's centre, instead of letting it
      // cut straight through the middle where all the houses meet. We pick the
      // perpendicular side that points away from centre (i.e. the line swings
      // clockwise/anticlockwise around the hub) and keep every control point on
      // that side — so lines arc around rather than crossing the core.
      final center = Offset(w / 2, h / 2);
      final mid0 = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final outward = mid0 - center;
      double biasDir;
      if (outward.distance > 1) {
        biasDir =
            (perp.dx * outward.dx + perp.dy * outward.dy) >= 0 ? 1.0 : -1.0;
      } else {
        // Degenerate: midpoint ~ centre. Use rotational sense instead.
        final cross = (a.dx - center.dx) * (b.dy - center.dy) -
            (a.dy - center.dy) * (b.dx - center.dx);
        biasDir = cross >= 0 ? 1.0 : -1.0;
      }

      // Build an organic wandering arc: a strong outward bow + a little random
      // jitter, all on the same (outward) side. Seeded per connection so it
      // stays stable across repaints.
      final segments = 5 + rnd.nextInt(3); // 5..7 kinks
      final pts = <Offset>[a];
      for (int k = 1; k < segments; k++) {
        final t = k / segments;
        final env = math.sin(t * math.pi); // 0 at ends, 1 mid
        final o = biasDir *
            env *
            (amplitude * 1.6 + rnd.nextDouble() * amplitude * 0.9);
        final baseP =
            Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
        pts.add(Offset(baseP.dx + perp.dx * o, baseP.dy + perp.dy * o));
      }
      pts.add(b);

      // Smooth the polyline through midpoints (quadratic beziers) for a
      // flowing, hand-drawn feel.
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int k = 1; k < pts.length - 1; k++) {
        final mid = Offset(
          (pts[k].dx + pts[k + 1].dx) / 2,
          (pts[k].dy + pts[k + 1].dy) / 2,
        );
        path.quadraticBezierTo(pts[k].dx, pts[k].dy, mid.dx, mid.dy);
      }
      path.lineTo(b.dx, b.dy);

      // The hero gets a soft glow: a wide, blurred pass in its planet colour
      // drawn underneath the crisp stroke.
      if (isHero) {
        final glow = Paint()
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true
          ..strokeCap = StrokeCap.round
          ..strokeWidth = lineWidth * 10.0
          ..color = base.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
        canvas.drawPath(path, glow);
      }

      canvas.drawPath(path, paint);
      _arrowHead(canvas, b, pts[pts.length - 2], paint);
    }
  }

  /// Legacy whole-sign drishti (transit→natal), kept as a fallback for charts
  /// that don't supply curated [connections].
  void _drawDrishtiFallback(Canvas canvas, double w, double h) {
    final bool useTransit = transitHouses != null && transitPlanetStyle != null;
    // Aspecting planets: the moving sky (transit) when available, else natal.
    final source = useTransit ? transitHouses! : houses;
    final srcDist = useTransit ? 72.0 : 42.0;
    // Targets that MATTER: always the native's natal placements.
    final target = houses;
    const tgtDist = 42.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth * 6.0
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round;

    for (int from = 0; from < 12 && from < source.length; from++) {
      final planets = _clean(source[from]);
      if (planets.isEmpty) continue;

      for (int pi = 0; pi < planets.length; pi++) {
        final planet = planets[pi];
        paint.color = _planetColor(planet).withValues(alpha: 0.35);

        for (final off in _aspectOffsets(planet)) {
          final to = (from + off) % 12;

          // A drishti only matters when it lands on the native's chart — i.e.
          // the aspected NATAL house actually holds a planet. Transit→transit
          // (empty natal house) is mundane and skipped.
          if (to >= target.length || _clean(target[to]).isEmpty) continue;

          // Direct, slightly-wavy line from the aspecting planet to the natal
          // placement it touches.
          final rnd = math.Random(from * 1000 + to * 10 + pi);
          final a = _planetCenter(from, w, h, srcDist);
          final b = _planetCenter(to, w, h, tgtDist);
          var dir = b - a;
          final len = dir.distance;
          if (len == 0) continue;
          dir = dir / len;
          final perp = Offset(-dir.dy, dir.dx);

          const amplitude = 6.0; // slight
          final waves = 2 + rnd.nextInt(2); // 2..3
          final phase = rnd.nextDouble() * math.pi;
          Offset pt(double t) {
            final base =
                Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
            final env = math.sin(t * math.pi); // fade to 0 at both ends
            final o = env * amplitude * math.sin(t * math.pi * waves + phase);
            return Offset(base.dx + perp.dx * o, base.dy + perp.dy * o);
          }

          const steps = 32;
          final path = Path()..moveTo(a.dx, a.dy);
          for (int s = 1; s <= steps; s++) {
            final p = pt(s / steps);
            path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(path, paint);

          _arrowHead(canvas, b, pt(0.9), paint);
        }
      }
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

  /// Draws a group of planet tokens, each tinted with its own planet colour.
  void _drawColoredPlanets({
    required Canvas canvas,
    required List<String> planets,
    required TextStyle style,
    required String joinStr,
    required Offset center,
  }) {
    final children = <TextSpan>[];
    for (int i = 0; i < planets.length; i++) {
      children.add(TextSpan(
        text: planets[i],
        style: style.copyWith(color: _planetColor(planets[i])),
      ));
      if (i < planets.length - 1) {
        children.add(TextSpan(text: joinStr, style: style));
      }
    }
    final textPainter = TextPainter(
      text: TextSpan(children: children),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2),
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
        oldDelegate.connections != connections ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.lineWidth != lineWidth;
  }
}
