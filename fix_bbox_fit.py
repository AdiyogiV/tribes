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

    // Angles for three properties
    const aPitta = -math.pi / 2;       // Top (Fire)
    const aKapha = math.pi / 6;        // Bottom Right (Earth)
    const aVata = 5 * math.pi / 6;     // Bottom Left (Air)

    int maxReading = [basePitta, baseKapha, baseVata, curPitta, curKapha, curVata].reduce(math.max);
    if (maxReading < 1) maxReading = 1;

    // Normalised radius in unit space (0..1). Floor at 0.12 so nothing collapses.
    double unitR(int val) => 0.12 + 0.88 * (val / maxReading);

    // Build the 6 raw points in unit space (centre = origin).
    Offset rawPt(double angle, int val) {
      final r = unitR(val);
      return Offset(r * math.cos(angle), r * math.sin(angle));
    }

    final rBaseP = rawPt(aPitta, basePitta);
    final rBaseK = rawPt(aKapha, baseKapha);
    final rBaseV = rawPt(aVata, baseVata);
    final rCurP = rawPt(aPitta, curPitta);
    final rCurK = rawPt(aKapha, curKapha);
    final rCurV = rawPt(aVata, curVata);

    final allPts = [rBaseP, rBaseK, rBaseV, rCurP, rCurK, rCurV];

    // Compute the tight bounding box of every point.
    double minX = allPts.first.dx, maxX = allPts.first.dx;
    double minY = allPts.first.dy, maxY = allPts.first.dy;
    for (final p in allPts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }

    final bboxW = (maxX - minX).clamp(0.0001, double.infinity);
    final bboxH = (maxY - minY).clamp(0.0001, double.infinity);

    // Padding leaves room for the 16px corner markers + a little breathing space.
    const pad = 26.0;
    final availW = w - pad * 2;
    final availH = h - pad * 2;

    // Single uniform scale so the shape fills the box without distortion.
    final scale = math.min(availW / bboxW, availH / bboxH);

    // Centre the bbox inside the canvas.
    final bboxCx = (minX + maxX) / 2;
    final bboxCy = (minY + maxY) / 2;
    final canvasCx = w / 2;
    final canvasCy = h / 2;

    Offset map(Offset p) {
      return Offset(
        canvasCx + (p.dx - bboxCx) * scale,
        canvasCy + (p.dy - bboxCy) * scale,
      );
    }

    final pBaseP = map(rBaseP);
    final pBaseK = map(rBaseK);
    final pBaseV = map(rBaseV);
    final pCurP = map(rCurP);
    final pCurK = map(rCurK);
    final pCurV = map(rCurV);

    // 1. Baseline triangle (Prakriti) - faint anchor
    final basePath = Path()
      ..moveTo(pBaseP.dx, pBaseP.dy)
      ..lineTo(pBaseK.dx, pBaseK.dy)
      ..lineTo(pBaseV.dx, pBaseV.dy)
      ..close();

    canvas.drawPath(basePath, Paint()
      ..color = fgMuted.withAlpha(45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true
    );

    // 2. Current triangle (Vikriti) - bold solid
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
      ..strokeWidth = 4.0
      ..isAntiAlias = true
    );

    // 3. Colour-coded corner markers
    void drawCornerMarker(Offset pt, Color col) {
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
