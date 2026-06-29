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
    final c = Offset(w / 2, h / 2 + 10);
    final maxR = math.min(w, h) / 2 - 45; // Leave room for labels

    // Angles for the 3 axes
    final aPitta = -math.pi / 2;       // Top (Fire)
    final aKapha = math.pi / 6;        // Bottom Right (Earth)
    final aVata = 5 * math.pi / 6;     // Bottom Left (Air)

    // 1. Draw minimal background axes (3 straight lines from center)
    final axisPaint = Paint()
      ..color = faintColor.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    canvas.drawLine(c, Offset(c.dx + maxR * math.cos(aPitta), c.dy + maxR * math.sin(aPitta)), axisPaint);
    canvas.drawLine(c, Offset(c.dx + maxR * math.cos(aKapha), c.dy + maxR * math.sin(aKapha)), axisPaint);
    canvas.drawLine(c, Offset(c.dx + maxR * math.cos(aVata), c.dy + maxR * math.sin(aVata)), axisPaint);

    // One faint reference circle at 100% max radius
    canvas.drawCircle(c, maxR, axisPaint);

    // Helper to get coordinates
    Offset getPt(double angle, int val) {
      double r = maxR * (val / 100.0).clamp(0.1, 1.0);
      return Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
    }

    final basePittaPt = getPt(aPitta, basePitta);
    final baseKaphaPt = getPt(aKapha, baseKapha);
    final baseVataPt = getPt(aVata, baseVata);

    final curPittaPt = getPt(aPitta, curPitta);
    final curKaphaPt = getPt(aKapha, curKapha);
    final curVataPt = getPt(aVata, curVata);

    // 2. Draw Baseline Shape (Prakriti) - Faint sharp triangle
    final basePath = Path()
      ..moveTo(basePittaPt.dx, basePittaPt.dy)
      ..lineTo(baseKaphaPt.dx, baseKaphaPt.dy)
      ..lineTo(baseVataPt.dx, baseVataPt.dy)
      ..close();

    canvas.drawPath(basePath, Paint()
      ..color = fgMuted.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true
    );

    // 3. Draw Current Shape (Vikriti) - Solid sharp triangle
    final curPath = Path()
      ..moveTo(curPittaPt.dx, curPittaPt.dy)
      ..lineTo(curKaphaPt.dx, curKaphaPt.dy)
      ..lineTo(curVataPt.dx, curVataPt.dy)
      ..close();

    // Very faint fill so the intersection/volume is visible
    canvas.drawPath(curPath, Paint()
      ..color = fgMain.withAlpha(8)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
    );

    canvas.drawPath(curPath, Paint()
      ..color = fgMain.withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true
    );

    // 4. Draw Data Points (Nodes)
    void drawDot(Offset pt, Color col) {
      canvas.drawCircle(pt, 3, Paint()..color = col..style=PaintingStyle.fill..isAntiAlias=true);
      canvas.drawCircle(pt, 8, Paint()..color = col.withAlpha(30)..style=PaintingStyle.stroke..strokeWidth=2..isAntiAlias=true);
    }
    
    drawDot(curPittaPt, colorPitta);
    drawDot(curKaphaPt, colorKapha);
    drawDot(curVataPt, colorVata);

    // 5. Draw Labels
    void drawLabel(String elem, String dosha, int curVal, int baseVal, double angle, Color col) {
      double lr = maxR + 32; // Distance for labels
      Offset pt = Offset(c.dx + lr * math.cos(angle), c.dy + lr * math.sin(angle));
      
      final shift = curVal - baseVal;
      final shiftStr = shift > 0 ? '+$shift%' : (shift < 0 ? '$shift%' : 'Balanced');
      
      final titleSpan = TextSpan(
        children: [
          TextSpan(text: '$elem\\n', style: TextStyle(color: fgMain, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.0, height: 1.5)),
          TextSpan(text: '$dosha  ', style: TextStyle(color: fgMuted, fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 12)),
          TextSpan(text: '$curVal%\\n', style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w700)),
          TextSpan(text: shiftStr, style: TextStyle(color: fgMuted, fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
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

