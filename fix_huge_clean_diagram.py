import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Make the canvas larger
content = re.sub(r"height: 400,", "height: 460,", content)

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
    
    // MAXIMAL SIZE: Fill the entire square, leaving just 15px padding
    final maxR = (math.min(w, h) / 2) - 15.0; 

    // Pure 3-axis mapping
    final aPitta = -math.pi / 2;       // Top
    final aKapha = math.pi / 6;        // Bottom Right
    final aVata = 5 * math.pi / 6;     // Bottom Left

    // Auto-scale so the largest value touches the absolute edge (100% of maxR)
    int maxReading = [basePitta, baseKapha, baseVata, curPitta, curKapha, curVata].reduce(math.max);
    if (maxReading < 1) maxReading = 1;

    // Minimum radius 15% so it doesn't collapse
    double getR(int val) => maxR * (0.15 + 0.85 * (val / maxReading));

    final rBasePitta = getR(basePitta);
    final rBaseKapha = getR(baseKapha);
    final rBaseVata = getR(baseVata);

    final rCurPitta = getR(curPitta);
    final rCurKapha = getR(curKapha);
    final rCurVata = getR(curVata);

    Offset getPt(double angle, double r) {
      return Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
    }

    // 1. Draw Radar Background Grid (HUGE)
    final gridPaint = Paint()
      ..color = faintColor.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    canvas.drawCircle(c, maxR, gridPaint);
    canvas.drawCircle(c, maxR * 0.66, gridPaint);
    canvas.drawCircle(c, maxR * 0.33, gridPaint);
    
    canvas.drawLine(c, getPt(aPitta, maxR), gridPaint);
    canvas.drawLine(c, getPt(aKapha, maxR), gridPaint);
    canvas.drawLine(c, getPt(aVata, maxR), gridPaint);

    // 2. Shape Generator: A perfectly smooth 3-point spline (Soft Triangle/Shield)
    // No wiggles. Just beautiful, pure interpolation between the 3 radii.
    Path createSmoothShield(double rP, double rK, double rV) {
      final path = Path();
      const points = 180;
      for (int i = 0; i <= points; i++) {
        double t = (i / points) * 2 * math.pi;
        double tNorm = t % (2 * math.pi);
        if (tNorm < 0) tNorm += 2 * math.pi;

        // Hardcode positive angles for foolproof interpolation
        double tKapha = math.pi / 6;        // 0.52
        double tVata = 5 * math.pi / 6;     // 2.61
        double tPitta = 3 * math.pi / 2;    // 4.71

        List<Map<String, dynamic>> anchors = [
          {'a': tKapha, 'r': rK},
          {'a': tVata, 'r': rV},
          {'a': tPitta, 'r': rP},
        ];

        double a0 = 0, a1 = 0, r0 = 0, r1 = 0;
        if (tNorm >= anchors[0]['a'] && tNorm < anchors[1]['a']) {
          a0 = anchors[0]['a']; r0 = anchors[0]['r'].toDouble();
          a1 = anchors[1]['a']; r1 = anchors[1]['r'].toDouble();
        } else if (tNorm >= anchors[1]['a'] && tNorm < anchors[2]['a']) {
          a0 = anchors[1]['a']; r0 = anchors[1]['r'].toDouble();
          a1 = anchors[2]['a']; r1 = anchors[2]['r'].toDouble();
        } else {
          a0 = anchors[2]['a']; r0 = anchors[2]['r'].toDouble();
          a1 = anchors[0]['a'] + 2 * math.pi; r1 = anchors[0]['r'].toDouble();
          if (tNorm < anchors[0]['a']) tNorm += 2 * math.pi;
        }

        // Cosine easing creates a perfectly smooth curve that hits each point exactly
        double f = (tNorm - a0) / (a1 - a0);
        double smoothF = 0.5 - 0.5 * math.cos(f * math.pi);
        double radius = r0 + smoothF * (r1 - r0);
        
        final x = c.dx + radius * math.cos(t);
        final y = c.dy + radius * math.sin(t);
        
        if (i == 0) { path.moveTo(x, y); }
        else { path.lineTo(x, y); }
      }
      path.close();
      return path;
    }

    // A. Baseline Shape (Faint, Dashed-style via opacity)
    final basePath = createSmoothShield(rBasePitta, rBaseKapha, rBaseVata);
    canvas.drawPath(basePath, Paint()
      ..color = fgMuted.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true
    );

    // B. Current Shape (Solid, Bold)
    final curPath = createSmoothShield(rCurPitta, rCurKapha, rCurVata);
    canvas.drawPath(curPath, Paint()
      ..color = fgMain.withAlpha(25)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
    );
    canvas.drawPath(curPath, Paint()
      ..color = fgMain
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..isAntiAlias = true
    );

    // 3. Huge Minimal Nodes at the Data Points
    void drawNode(double angle, double r, Color col) {
      Offset pt = getPt(angle, r);
      double circleR = 18.0; 
      
      canvas.drawCircle(pt, circleR, Paint()
        ..color = col.withAlpha(20)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
      );
      canvas.drawCircle(pt, circleR, Paint()
        ..color = col.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..isAntiAlias = true
      );
      canvas.drawCircle(pt, 6.0, Paint()
        ..color = col
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
      );
    }

    drawNode(aPitta, rCurPitta, colorPitta);
    drawNode(aKapha, rCurKapha, colorKapha);
    drawNode(aVata, rCurVata, colorVata);
    
    // Labels are completely gone to allow for absolute maximum geometric scale.
  }

  @override
  bool shouldRepaint(covariant _UnifiedTrifectaPainter old) => true;
}"""

content = re.sub(pattern_painter, new_painter, content, flags=re.DOTALL)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
