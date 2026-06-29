import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Fix layout height
content = content.replace("height: 320,", "height: 360,")

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
    final c = Offset(w / 2, h / 2 + 10);
    final maxR = 110.0; // MASSIVE size increase

    final aPitta = -math.pi / 2;       // Top (Fire)
    final aKapha = math.pi / 6;        // Bottom Right (Earth)
    final aVata = 5 * math.pi / 6;     // Bottom Left (Air)

    // Ensure baseline is never too small to see (at least 35% of maxR)
    double getR(int val) => maxR * (0.35 + 0.65 * (val / 100.0));

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

    // 1. Draw minimal axis lines
    final axisPaint = Paint()
      ..color = faintColor.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    canvas.drawLine(c, Offset(c.dx + maxR * 1.4 * math.cos(aPitta), c.dy + maxR * 1.4 * math.sin(aPitta)), axisPaint);
    canvas.drawLine(c, Offset(c.dx + maxR * 1.4 * math.cos(aKapha), c.dy + maxR * 1.4 * math.sin(aKapha)), axisPaint);
    canvas.drawLine(c, Offset(c.dx + maxR * 1.4 * math.cos(aVata), c.dy + maxR * 1.4 * math.sin(aVata)), axisPaint);

    // 2. The Baseline Triangle (Prakriti Anchor) - Made larger and sharper
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

    // 3. The Continuous Wavy Orb with DRAMA (Amplitude increased)
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

      // Sine interpolation for extreme organic curve
      double f = (t - a0) / (a1 - a0);
      double smoothF = 0.5 - 0.5 * math.cos(f * math.pi); 
      
      double baseR = r0 + smoothF * (r1 - r0);
      
      // Add literal "wavy" drama on the perimeter (amplitude 5.0)
      double waveDrama = 5.0 * math.sin(t * 12);
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
      ..strokeWidth = 2.5
      ..isAntiAlias = true
    );

    // 4. Three Variable Circles at the Triangle Points (as requested)
    void drawAuraCircle(Offset pt, int val, Color col) {
      // Radius varies by reading (drama multiplier)
      double circleR = 12.0 + (val / 100.0) * 24.0; 
      
      // Faint glowing aura
      canvas.drawCircle(pt, circleR, Paint()
        ..color = col.withAlpha(40)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
      );
      // Crisp outline
      canvas.drawCircle(pt, circleR, Paint()
        ..color = col.withAlpha(180)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true
      );
      // Hard center node
      canvas.drawCircle(pt, 5, Paint()
        ..color = col
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
      );
    }

    drawAuraCircle(curPittaPt, curPitta, colorPitta);
    drawAuraCircle(curKaphaPt, curKapha, colorKapha);
    drawAuraCircle(curVataPt, curVata, colorVata);

    // 5. Labels pushed far enough out to clear the giant orb and circles
    void drawLabel(String elem, String dosha, int curVal, int baseVal, double angle, Color col) {
      double rCur = getR(curVal);
      double circleR = 12.0 + (curVal / 100.0) * 24.0;
      double lr = rCur + circleR + 25; 
      
      Offset pt = Offset(c.dx + lr * math.cos(angle), c.dy + lr * math.sin(angle));
      
      final shift = curVal - baseVal;
      String status = 'Balanced';
      if (shift > 0) status = 'Elevated +$shift%';
      if (shift < 0) status = 'Decreased $shift%';
      
      final titleSpan = TextSpan(
        children: [
          TextSpan(text: '$elem · $dosha\\n', style: TextStyle(color: fgMain, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          TextSpan(text: '$curVal%  ', style: TextStyle(color: col, fontSize: 14, fontWeight: FontWeight.w700)),
          TextSpan(text: '($status)', style: TextStyle(color: fgMuted, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      );
      
      final tp = TextPainter(text: titleSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - tp.height / 2));
    }

    drawLabel('FIRE', 'Pitta', curPitta, basePitta, aPitta, colorPitta);
    drawLabel('EARTH', 'Kapha', curKapha, baseKapha, aKapha, colorKapha);
    drawLabel('AIR', 'Vata', curVata, baseVata, aVata, colorVata);
  }

  @override
  bool shouldRepaint(covariant _UnifiedTrifectaPainter old) => true;
}"""

content = re.sub(pattern_painter, new_painter, content, flags=re.DOTALL)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)

