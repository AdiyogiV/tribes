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
    final c = Offset(w / 2, h / 2); // Centered perfectly
    
    // Massive radius since we are removing labels for now
    final maxR = (math.min(w, h) / 2) - 20.0; 

    final aPitta = -math.pi / 2;       // Top (Fire)
    final aKapha = math.pi / 6;        // Bottom Right (Earth)
    final aVata = 5 * math.pi / 6;     // Bottom Left (Air)

    // Base starts at 20% so it never collapses to 0, maxes out at 100% of maxR
    double getR(int val) => maxR * (0.2 + 0.8 * (val / 100.0));

    final rBasePitta = getR(basePitta);
    final rBaseKapha = getR(baseKapha);
    final rBaseVata = getR(baseVata);

    final rCurPitta = getR(curPitta);
    final rCurKapha = getR(curKapha);
    final rCurVata = getR(curVata);

    Offset getPt(double angle, double r) {
      return Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
    }

    final basePittaPt = getPt(aPitta, rBasePitta);
    final baseKaphaPt = getPt(aKapha, rBaseKapha);
    final baseVataPt = getPt(aVata, rBaseVata);

    final curPittaPt = getPt(aPitta, rCurPitta);
    final curKaphaPt = getPt(aKapha, rCurKapha);
    final curVataPt = getPt(aVata, rCurVata);

    // 1. Draw minimal axis lines all the way to the edge
    final axisPaint = Paint()
      ..color = faintColor.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    canvas.drawLine(c, Offset(c.dx + maxR * math.cos(aPitta), c.dy + maxR * math.sin(aPitta)), axisPaint);
    canvas.drawLine(c, Offset(c.dx + maxR * math.cos(aKapha), c.dy + maxR * math.sin(aKapha)), axisPaint);
    canvas.drawLine(c, Offset(c.dx + maxR * math.cos(aVata), c.dy + maxR * math.sin(aVata)), axisPaint);

    // 2. The Baseline Triangle (Prakriti Anchor) - Massive
    final basePath = Path()
      ..moveTo(basePittaPt.dx, basePittaPt.dy)
      ..lineTo(baseKaphaPt.dx, baseKaphaPt.dy)
      ..lineTo(baseVataPt.dx, baseVataPt.dy)
      ..close();

    canvas.drawPath(basePath, Paint()
      ..color = fgMuted.withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true
    );

    canvas.drawPath(basePath, Paint()
      ..color = fgMuted.withAlpha(5)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
    );

    // 3. The Continuous Wavy Orb (Less wavy, smoother)
    double getSmoothRadius(double t) {
      t = t % (2 * math.pi);
      if (t < 0) t += 2 * math.pi;

      double tPitta = (-math.pi / 2) % (2 * math.pi);
      double tKapha = (math.pi / 6);
      double tVata = (5 * math.pi / 6);

      List<Map<String, dynamic>> anchors = [
        {'a': tKapha, 'r': rCurKapha},
        {'a': tVata, 'r': rCurVata},
        {'a': tPitta, 'r': rCurPitta},
      ];

      double a0 = 0, a1 = 0, r0 = 0, r1 = 0;
      if (t >= anchors[0]['a'] && t < anchors[1]['a']) {
        a0 = anchors[0]['a']; r0 = anchors[0]['r'];
        a1 = anchors[1]['a']; r1 = anchors[1]['r'];
      } else if (t >= anchors[1]['a'] && t < anchors[2]['a']) {
        a0 = anchors[1]['a']; r0 = anchors[1]['r'];
        a1 = anchors[2]['a']; r1 = anchors[2]['r'];
      } else {
        a0 = anchors[2]['a']; r0 = anchors[2]['r'];
        a1 = anchors[0]['a'] + 2 * math.pi; r1 = anchors[0]['r'];
        if (t < anchors[0]['a']) t += 2 * math.pi;
      }

      double f = (t - a0) / (a1 - a0);
      double smoothF = 0.5 - 0.5 * math.cos(f * math.pi); 
      
      double baseR = r0 + smoothF * (r1 - r0);
      
      // Greatly reduced the "waviness" to make it smoother and less frantic
      double waveDrama = 2.0 * math.sin(t * 8); 
      return baseR + waveDrama;
    }

    final orbPath = Path();
    int points = 180;
    for (int i = 0; i <= points; i++) {
      double t = (i / points) * 2 * math.pi;
      double r = getSmoothRadius(t);
      double x = c.dx + r * math.cos(t);
      double y = c.dy + r * math.sin(t);
      if (i == 0) { orbPath.moveTo(x, y); }
      else { orbPath.lineTo(x, y); }
    }
    orbPath.close();

    // Orb Fill
    canvas.drawPath(orbPath, Paint()
      ..color = fgMain.withAlpha(20)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
    );
    // Orb Stroke (thick and bold)
    canvas.drawPath(orbPath, Paint()
      ..color = fgMain
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..isAntiAlias = true
    );

    // 4. Three Variable Circles at the Triangle Points
    void drawAuraCircle(Offset pt, int val, Color col) {
      double circleR = 12.0 + (val / 100.0) * 24.0; 
      
      canvas.drawCircle(pt, circleR, Paint()
        ..color = col.withAlpha(30)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
      );
      canvas.drawCircle(pt, circleR, Paint()
        ..color = col.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true
      );
      canvas.drawCircle(pt, 6, Paint()
        ..color = col
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
      );
    }

    drawAuraCircle(curPittaPt, curPitta, colorPitta);
    drawAuraCircle(curKaphaPt, curKapha, colorKapha);
    drawAuraCircle(curVataPt, curVata, colorVata);
  }

  @override
  bool shouldRepaint(covariant _UnifiedTrifectaPainter old) => true;
}"""

content = re.sub(pattern_painter, new_painter, content, flags=re.DOTALL)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
