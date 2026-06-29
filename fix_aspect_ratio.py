import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Replace the SizedBox with AspectRatio
pattern_sized_box = r"SizedBox\(\n\s*height: 460,\n\s*width: double\.infinity,\n\s*child: CustomPaint\("

new_aspect_ratio = """AspectRatio(
          aspectRatio: 1.0,
          child: CustomPaint("""

content = re.sub(pattern_sized_box, new_aspect_ratio, content)

# Replace Painter
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
    
    // We have a perfect square now.
    // Fill the absolute max space. No labels.
    final maxR = (w / 2) - 10.0; 

    // Angles for three properties
    final aPitta = -math.pi / 2;       // Top (Fire)
    final aKapha = math.pi / 6;        // Bottom Right (Earth)
    final aVata = 5 * math.pi / 6;     // Bottom Left (Air)

    int maxReading = [basePitta, baseKapha, baseVata, curPitta, curKapha, curVata].reduce(math.max);
    if (maxReading < 1) maxReading = 1;

    // Radius scaling: 10% base, up to 100% maxR
    double getR(int val) => maxR * (0.10 + 0.90 * (val / maxReading));

    final rBasePitta = getR(basePitta);
    final rBaseKapha = getR(baseKapha);
    final rBaseVata = getR(baseVata);

    final rCurPitta = getR(curPitta);
    final rCurKapha = getR(curKapha);
    final rCurVata = getR(curVata);

    Offset getPt(double angle, double r) {
      return Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
    }

    final pBaseP = getPt(aPitta, rBasePitta);
    final pBaseK = getPt(aKapha, rBaseKapha);
    final pBaseV = getPt(aVata, rBaseVata);

    final pCurP = getPt(aPitta, rCurPitta);
    final pCurK = getPt(aKapha, rCurKapha);
    final pCurV = getPt(aVata, rCurVata);

    // 1. Draw 3 Radial Axis Lines (Very subtle)
    final axisPaint = Paint()
      ..color = faintColor.withAlpha(30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true;

    canvas.drawLine(c, getPt(aPitta, maxR), axisPaint);
    canvas.drawLine(c, getPt(aKapha, maxR), axisPaint);
    canvas.drawLine(c, getPt(aVata, maxR), axisPaint);

    // Grid circles
    canvas.drawCircle(c, maxR, Paint()..color = faintColor.withAlpha(10)..style = PaintingStyle.stroke);
    canvas.drawCircle(c, maxR * 0.5, Paint()..color = faintColor.withAlpha(10)..style = PaintingStyle.stroke);

    // 2. Draw Baseline Shape (Prakriti) - Pure Sharp Triangle
    final basePath = Path()
      ..moveTo(pBaseP.dx, pBaseP.dy)
      ..lineTo(pBaseK.dx, pBaseK.dy)
      ..lineTo(pBaseV.dx, pBaseV.dy)
      ..close();

    canvas.drawPath(basePath, Paint()
      ..color = fgMuted.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true
    );
    canvas.drawPath(basePath, Paint()
      ..color = fgMuted.withAlpha(5)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
    );

    // 3. Draw Current Shape (Vikriti) - Pure Sharp Triangle
    final curPath = Path()
      ..moveTo(pCurP.dx, pCurP.dy)
      ..lineTo(pCurK.dx, pCurK.dy)
      ..lineTo(pCurV.dx, pCurV.dy)
      ..close();

    canvas.drawPath(curPath, Paint()
      ..color = fgMain.withAlpha(25)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
    );
    canvas.drawPath(curPath, Paint()
      ..color = fgMain
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 // Bold and clear
      ..isAntiAlias = true
    );

    // 4. Emphasize the 3 corners with solid, color-coded markers
    void drawCornerMarker(Offset pt, Color col) {
      // Clean modern node
      canvas.drawCircle(pt, 16.0, Paint()
        ..color = col.withAlpha(30)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
      );
      canvas.drawCircle(pt, 16.0, Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..isAntiAlias = true
      );
      canvas.drawCircle(pt, 6.0, Paint()
        ..color = col
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
      );
    }

    drawCornerMarker(pCurP, colorPitta);
    drawCornerMarker(pCurK, colorKapha);
    drawCornerMarker(pCurV, colorVata);
  }

  @override
  bool shouldRepaint(covariant _UnifiedTrifectaPainter old) => true;
}"""

content = re.sub(pattern_painter, new_painter, content, flags=re.DOTALL)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
