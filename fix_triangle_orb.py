import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

pattern_painter = r"class _UnifiedTrifectaPainter extends CustomPainter \{.*?@override\n  bool shouldRepaint\(covariant _UnifiedTrifectaPainter old\) => true;\n\}"

new_painter = """class _UnifiedTrifectaPainter extends CustomPainter {
  final int baseVata, curVata;
  final Color colorVata;
  final int basePitta, curPitta;
  final Color colorPitta;
  final int baseKapha, curKapha;
  final Color colorKapha;
  final Color fgMain, fgMuted, faintColor;

  _UnifiedTrifectaPainter({
    required this.baseVata, required this.curVata, required this.colorVata,
    required this.basePitta, required this.curPitta, required this.colorPitta,
    required this.baseKapha, required this.curKapha, required this.colorKapha,
    required this.fgMain, required this.fgMuted, required this.faintColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h / 2);
    
    final maxR = (math.min(w, h) / 2) - 20.0;

    final aPitta = -math.pi / 2;
    final aKapha = math.pi / 6;
    final aVata = 5 * math.pi / 6;

    // Core triangle larger: Floor is 40%
    double getR(int val) => maxR * (0.40 + 0.60 * (val / 100.0));

    final rBasePitta = getR(basePitta);
    final rBaseKapha = getR(baseKapha);
    final rBaseVata = getR(baseVata);

    final rCurPitta = getR(curPitta);
    final rCurKapha = getR(curKapha);
    final rCurVata = getR(curVata);

    // Minimal axis lines
    final axisPaint = Paint()
      ..color = faintColor.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    canvas.drawLine(c, Offset(c.dx + maxR * math.cos(aPitta), c.dy + maxR * math.sin(aPitta)), axisPaint);
    canvas.drawLine(c, Offset(c.dx + maxR * math.cos(aKapha), c.dy + maxR * math.sin(aKapha)), axisPaint);
    canvas.drawLine(c, Offset(c.dx + maxR * math.cos(aVata), c.dy + maxR * math.sin(aVata)), axisPaint);

    // Shape generator: A triangle with slightly curved "orb" edges
    Path buildSoftTriangle(double rP, double rK, double rV) {
      double getOrbRadius(double t) {
        t = t % (2 * math.pi);
        if (t < 0) t += 2 * math.pi;

        double tPitta = (-math.pi / 2) % (2 * math.pi);
        double tKapha = (math.pi / 6);
        double tVata = (5 * math.pi / 6);

        List<Map<String, dynamic>> anchors = [
          {'a': tKapha, 'r': rK},
          {'a': tVata, 'r': rV},
          {'a': tPitta, 'r': rP},
        ];

        double a0 = 0, a1 = 0, r0 = 0, r1 = 0;
        if (t >= anchors[0]['a'] && t < anchors[1]['a']) {
          a0 = anchors[0]['a']; r0 = anchors[0]['r'].toDouble();
          a1 = anchors[1]['a']; r1 = anchors[1]['r'].toDouble();
        } else if (t >= anchors[1]['a'] && t < anchors[2]['a']) {
          a0 = anchors[1]['a']; r0 = anchors[1]['r'].toDouble();
          a1 = anchors[2]['a']; r1 = anchors[2]['r'].toDouble();
        } else {
          a0 = anchors[2]['a']; r0 = anchors[2]['r'].toDouble();
          a1 = anchors[0]['a'] + 2 * math.pi; r1 = anchors[0]['r'].toDouble();
          if (t < anchors[0]['a']) t += 2 * math.pi;
        }

        // Pure straight line triangle interpolation
        double sinDiff = math.sin(a1 - a0);
        double denom = r0 * math.sin(a1 - t) + r1 * math.sin(t - a0);
        double rLine = (denom == 0) ? r0 : (r0 * r1 * sinDiff) / denom;

        // Pure circular blob interpolation
        double f = (t - a0) / (a1 - a0);
        double smoothF = 0.5 - 0.5 * math.cos(f * math.pi);
        double rCircle = r0 + smoothF * (r1 - r0);

        // Blend them. 0.0 = perfect sharp triangle. 1.0 = circular blob.
        // "more triangleish than circle ish" -> mostly line, slight curve
        double roundness = 0.25; 
        return rLine * (1 - roundness) + rCircle * roundness;
      }

      final path = Path();
      int points = 180;
      for (int i = 0; i <= points; i++) {
        double t = (i / points) * 2 * math.pi;
        double r = getOrbRadius(t);
        double x = c.dx + r * math.cos(t);
        double y = c.dy + r * math.sin(t);
        if (i == 0) { path.moveTo(x, y); }
        else { path.lineTo(x, y); }
      }
      path.close();
      return path;
    }

    // 1. Draw Baseline Orb (Prakriti)
    final basePath = buildSoftTriangle(rBasePitta, rBaseKapha, rBaseVata);
    canvas.drawPath(basePath, Paint()
      ..color = fgMuted.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true
    );
    canvas.drawPath(basePath, Paint()
      ..color = fgMuted.withAlpha(5)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
    );

    // 2. Draw Current Orb (Vikriti)
    final curPath = buildSoftTriangle(rCurPitta, rCurKapha, rCurVata);
    canvas.drawPath(curPath, Paint()
      ..color = fgMain.withAlpha(20)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
    );
    canvas.drawPath(curPath, Paint()
      ..color = fgMain
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..isAntiAlias = true
    );

    // 3. Three Variable Circles at the Triangle Points (Larger and Minimal)
    void drawAuraCircle(double angle, double r, int val, Color col) {
      Offset pt = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
      
      // Make circles larger and minimal
      double circleR = 25.0 + (val / 100.0) * 35.0; 
      
      canvas.drawCircle(pt, circleR, Paint()
        ..color = col.withAlpha(12) // Extremely faint fill
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
      );
      canvas.drawCircle(pt, circleR, Paint()
        ..color = col.withAlpha(160) // Crisp, thin stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true
      );
    }

    drawAuraCircle(aPitta, rCurPitta, curPitta, colorPitta);
    drawAuraCircle(aKapha, rCurKapha, curKapha, colorKapha);
    drawAuraCircle(aVata, rCurVata, curVata, colorVata);
  }

  @override
  bool shouldRepaint(covariant _UnifiedTrifectaPainter old) => true;
}"""

content = re.sub(pattern_painter, new_painter, content, flags=re.DOTALL)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
