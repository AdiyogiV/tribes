import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Reduce the SizedBox gap
content = content.replace("height: 340,", "height: 240,")

# 2. Replace the Painter entirely
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

  Offset _getCircumcenter(Offset p1, Offset p2, Offset p3) {
    double d = 2 * (p1.dx * (p2.dy - p3.dy) + p2.dx * (p3.dy - p1.dy) + p3.dx * (p1.dy - p2.dy));
    if (d == 0) return Offset((p1.dx+p2.dx+p3.dx)/3, (p1.dy+p2.dy+p3.dy)/3); 
    double ux = ((p1.dx * p1.dx + p1.dy * p1.dy) * (p2.dy - p3.dy) +
                 (p2.dx * p2.dx + p2.dy * p2.dy) * (p3.dy - p1.dy) +
                 (p3.dx * p3.dx + p3.dy * p3.dy) * (p1.dy - p2.dy)) / d;
    double uy = ((p1.dx * p1.dx + p1.dy * p1.dy) * (p3.dx - p2.dx) +
                 (p2.dx * p2.dx + p2.dy * p2.dy) * (p1.dx - p3.dx) +
                 (p3.dx * p3.dx + p3.dy * p3.dy) * (p2.dx - p1.dx)) / d;
    return Offset(ux, uy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h / 2 + 10);
    final maxR = 60.0; // Tighter radius to reduce gap and fit explicit labels

    final aPitta = -math.pi / 2;       // Top (Fire)
    final aKapha = math.pi / 6;        // Bottom Right (Earth)
    final aVata = 5 * math.pi / 6;     // Bottom Left (Air)

    // 1. Draw minimal axis lines connecting center to the 3 element poles
    final axisPaint = Paint()
      ..color = faintColor.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    canvas.drawLine(c, Offset(c.dx + maxR * math.cos(aPitta), c.dy + maxR * math.sin(aPitta)), axisPaint);
    canvas.drawLine(c, Offset(c.dx + maxR * math.cos(aKapha), c.dy + maxR * math.sin(aKapha)), axisPaint);
    canvas.drawLine(c, Offset(c.dx + maxR * math.cos(aVata), c.dy + maxR * math.sin(aVata)), axisPaint);

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

    // 2. Mathematically Perfect Circular Connections (Circumcircles)
    
    // Baseline Circle (Faint, Dotted or Thin)
    Offset baseCenter = _getCircumcenter(basePittaPt, baseKaphaPt, baseVataPt);
    double baseRadius = (baseCenter - basePittaPt).distance;
    canvas.drawCircle(baseCenter, baseRadius, Paint()
      ..color = fgMuted.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true
    );

    // Current State Circle (Solid, Colored)
    Offset curCenter = _getCircumcenter(curPittaPt, curKaphaPt, curVataPt);
    double curRadius = (curCenter - curPittaPt).distance;
    
    // Fill
    canvas.drawCircle(curCenter, curRadius, Paint()
      ..color = fgMain.withAlpha(10)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
    );
    // Stroke
    canvas.drawCircle(curCenter, curRadius, Paint()
      ..color = fgMain
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true
    );

    // 3. Draw Nodes
    void drawDot(Offset pt, Color col) {
      canvas.drawCircle(pt, 3, Paint()..color = col..style=PaintingStyle.fill..isAntiAlias=true);
      canvas.drawCircle(pt, 8, Paint()..color = col.withAlpha(30)..style=PaintingStyle.stroke..strokeWidth=2..isAntiAlias=true);
    }
    
    drawDot(curPittaPt, colorPitta);
    drawDot(curKaphaPt, colorKapha);
    drawDot(curVataPt, colorVata);

    // 4. Extremely Clear, Explicit Labels
    void drawLabel(String elem, String dosha, int curVal, int baseVal, double angle, Color col) {
      double lr = maxR + 24; 
      Offset pt = Offset(c.dx + lr * math.cos(angle), c.dy + lr * math.sin(angle));
      
      final shift = curVal - baseVal;
      String status = 'Balanced';
      if (shift > 0) status = 'Elevated +$shift%';
      if (shift < 0) status = 'Decreased $shift%';
      
      final titleSpan = TextSpan(
        children: [
          TextSpan(text: '$elem · $dosha\\n', style: TextStyle(color: fgMain, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          TextSpan(text: '$curVal%  ', style: TextStyle(color: col, fontSize: 13, fontWeight: FontWeight.w700)),
          TextSpan(text: '($status)', style: TextStyle(color: fgMuted, fontSize: 10, fontWeight: FontWeight.w500)),
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

