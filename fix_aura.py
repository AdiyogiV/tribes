import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Fix layout height
content = content.replace("height: 240,", "height: 320,")

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
    final c = Offset(w / 2, h / 2 + 15);
    final maxR = 90.0; // Pushed out to use the empty space

    final aPitta = -math.pi / 2;       // Top (Fire)
    final aKapha = math.pi / 6;        // Bottom Right (Earth)
    final aVata = 5 * math.pi / 6;     // Bottom Left (Air)

    // Helper: Find the anchor point for the baseline triangle
    Offset getBasePt(double angle, int val) {
      double r = maxR * (val / 100.0).clamp(0.15, 1.0);
      return Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
    }

    final basePittaPt = getBasePt(aPitta, basePitta);
    final baseKaphaPt = getBasePt(aKapha, baseKapha);
    final baseVataPt = getBasePt(aVata, baseVata);

    // 1. Draw the dramatic axes radiating from center
    final axisPaint = Paint()
      ..color = faintColor.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    canvas.drawLine(c, Offset(c.dx + maxR * 1.6 * math.cos(aPitta), c.dy + maxR * 1.6 * math.sin(aPitta)), axisPaint);
    canvas.drawLine(c, Offset(c.dx + maxR * 1.6 * math.cos(aKapha), c.dy + maxR * 1.6 * math.sin(aKapha)), axisPaint);
    canvas.drawLine(c, Offset(c.dx + maxR * 1.6 * math.cos(aVata), c.dy + maxR * 1.6 * math.sin(aVata)), axisPaint);

    // 2. The Baseline Triangle (Prakriti Anchor)
    final basePath = Path()
      ..moveTo(basePittaPt.dx, basePittaPt.dy)
      ..lineTo(baseKaphaPt.dx, baseKaphaPt.dy)
      ..lineTo(baseVataPt.dx, baseVataPt.dy)
      ..close();

    canvas.drawPath(basePath, Paint()
      ..color = fgMuted.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true
    );

    // 3. The 3 Intersection Circles (Vikriti Aura)
    // Here we draw circles anchored AT the baseline points. 
    // The radius is driven by the CURRENT value.
    double getCircleRadius(int curVal) {
      // Create massive drama: 100% reading = massive overlapping circle
      return (curVal / 100.0) * maxR * 1.25; 
    }

    void drawAura(Offset center, int val, Color col) {
      double r = getCircleRadius(val);
      
      // The colored transparent fill (Venn overlap drama)
      canvas.drawCircle(center, r, Paint()
        ..color = col.withAlpha(35)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
      );
      
      // The sharp outer ring
      canvas.drawCircle(center, r, Paint()
        ..color = col.withAlpha(200)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true
      );
      
      // The glowing core node exactly on the triangle point
      canvas.drawCircle(center, 4, Paint()
        ..color = col
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
      );
      canvas.drawCircle(center, 12, Paint()
        ..color = col.withAlpha(50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..isAntiAlias = true
      );
    }

    drawAura(basePittaPt, curPitta, colorPitta);
    drawAura(baseKaphaPt, curKapha, colorKapha);
    drawAura(baseVataPt, curVata, colorVata);

    // 4. Labels pushed outside the dramatic auras
    void drawLabel(String elem, String dosha, int curVal, int baseVal, double angle, Color col) {
      double baseDist = maxR * (baseVal / 100.0).clamp(0.15, 1.0);
      double auraRadius = getCircleRadius(curVal);
      // Push label past the triangle point AND past the edge of the aura circle
      double lr = baseDist + auraRadius + 30; 
      
      Offset pt = Offset(c.dx + lr * math.cos(angle), c.dy + lr * math.sin(angle));
      
      final shift = curVal - baseVal;
      String status = 'Balanced';
      if (shift > 0) status = 'Elevated +$shift%';
      if (shift < 0) status = 'Decreased $shift%';
      
      final titleSpan = TextSpan(
        children: [
          TextSpan(text: '$elem · $dosha\\n', style: TextStyle(color: fgMain, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
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

