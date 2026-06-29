import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Make the canvas larger
content = content.replace("height: 360,", "height: 400,")

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
    
    // Massive base size - labels removed entirely, so we use 100% of the space
    final maxR = (math.min(w, h) / 2) - 10.0; 

    final aPitta = -math.pi / 2;
    final aKapha = math.pi / 6;
    final aVata = 5 * math.pi / 6;

    // Extreme scale differentiation
    // Map 0-100 to 20% -> 100% of the massive radius to make shifts extremely obvious
    double getR(int val) => maxR * (0.20 + 0.80 * (val / 100.0));

    final rBasePitta = getR(basePitta);
    final rBaseKapha = getR(baseKapha);
    final rBaseVata = getR(baseVata);

    final rCurPitta = getR(curPitta);
    final rCurKapha = getR(curKapha);
    final rCurVata = getR(curVata);

    Offset getPt(double angle, double r) {
      return Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
    }

    // 1. Draw Axis lines
    final axisPaint = Paint()
      ..color = faintColor.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    canvas.drawLine(c, getPt(aPitta, maxR), axisPaint);
    canvas.drawLine(c, getPt(aKapha, maxR), axisPaint);
    canvas.drawLine(c, getPt(aVata, maxR), axisPaint);

    // 2. The Core Triangle Anchor (Massive, visible)
    final trianglePath = Path()
      ..moveTo(getPt(aPitta, rBasePitta).dx, getPt(aPitta, rBasePitta).dy)
      ..lineTo(getPt(aKapha, rBaseKapha).dx, getPt(aKapha, rBaseKapha).dy)
      ..lineTo(getPt(aVata, rBaseVata).dx, getPt(aVata, rBaseVata).dy)
      ..close();

    canvas.drawPath(trianglePath, Paint()
      ..color = fgMuted.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true
    );

    // 3. The Nakshatra Wavy Circular Orbs
    Path createAuraPath(double rP, double rK, double rV, double shift) {
      final path = Path();
      const points = 180;
      for (int i = 0; i <= points; i++) {
        double t = (i / points) * 2 * math.pi;
        double tNorm = t % (2 * math.pi);
        if (tNorm < 0) tNorm += 2 * math.pi;

        double tPitta = (-math.pi / 2) % (2 * math.pi);
        double tKapha = (math.pi / 6);
        double tVata = (5 * math.pi / 6);

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

        // Circular interpolation (smoothstep)
        double f = (tNorm - a0) / (a1 - a0);
        double smoothF = 0.5 - 0.5 * math.cos(f * math.pi);
        double baseRadius = r0 + smoothF * (r1 - r0);
        
        // Blend mostly circle, slightly triangle
        double sinDiff = math.sin(a1 - a0);
        double denom = r0 * math.sin(a1 - tNorm) + r1 * math.sin(tNorm - a0);
        double rLine = (denom == 0) ? r0 : (r0 * r1 * sinDiff) / denom;
        
        double finalBaseR = rLine * 0.10 + baseRadius * 0.90; // 90% circular orb

        // Apply Nakshatra math for organic breathing
        final wave1 = math.sin(t * 3) * shift * 0.5;
        final wave2 = math.cos(t * 5) * shift * 0.3;
        final wave3 = math.sin(t * 7 + shift) * shift * 0.2;
        
        final currentRadius = finalBaseR + wave1 + wave2 + wave3;
        
        final x = c.dx + currentRadius * math.cos(t);
        final y = c.dy + currentRadius * math.sin(t);
        
        if (i == 0) { path.moveTo(x, y); }
        else { path.lineTo(x, y); }
      }
      path.close();
      return path;
    }

    // A. Baseline Orb (Faint, calm waves)
    final basePathOrb = createAuraPath(rBasePitta, rBaseKapha, rBaseVata, 2.0);
    canvas.drawPath(basePathOrb, Paint()
      ..color = fgMuted.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true
    );
    canvas.drawPath(basePathOrb, Paint()
      ..color = fgMuted.withAlpha(8)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
    );

    // B. Current Shift Orb (Solid, extremely dramatic waves)
    // Drama based on total shift - heavily amplified so differences are deeply visible
    double totalShift = ((curPitta-basePitta).abs() + (curKapha-baseKapha).abs() + (curVata-baseVata).abs()).toDouble();
    double drama = 8.0 + (totalShift * 0.4).clamp(0.0, 20.0);
    
    final curPathOrb = createAuraPath(rCurPitta, rCurKapha, rCurVata, drama);
    canvas.drawPath(curPathOrb, Paint()
      ..color = fgMain.withAlpha(20)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
    );
    canvas.drawPath(curPathOrb, Paint()
      ..color = fgMain
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..isAntiAlias = true
    );

    // 4. Large Minimal Circles at Points
    void drawAuraCircle(double angle, double r, Color col) {
      Offset pt = getPt(angle, r);
      double circleR = 30.0; // Much larger minimal circles
      
      canvas.drawCircle(pt, circleR, Paint()
        ..color = col.withAlpha(15)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
      );
      canvas.drawCircle(pt, circleR, Paint()
        ..color = col.withAlpha(180)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..isAntiAlias = true
      );
      canvas.drawCircle(pt, 6, Paint()
        ..color = col
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
      );
    }

    drawAuraCircle(aPitta, rCurPitta, colorPitta);
    drawAuraCircle(aKapha, rCurKapha, colorKapha);
    drawAuraCircle(aVata, rCurVata, colorVata);
    
    // Labels completely removed so the shape dominates 100% of the screen width
  }

  @override
  bool shouldRepaint(covariant _UnifiedTrifectaPainter old) => true;
}"""

content = re.sub(pattern_painter, new_painter, content, flags=re.DOTALL)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
