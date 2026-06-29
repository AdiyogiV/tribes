import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

start_idx = content.find('class _UnifiedTrifectaPainter extends CustomPainter {')
safe_top = content[:start_idx]

new_painter = """class _UnifiedTrifectaPainter extends CustomPainter {
  final int baseVata, curVata;
  final Color colorVata;
  final int basePitta, curPitta;
  final Color colorPitta;
  final int baseKapha, curKapha;
  final Color colorKapha;
  final Color fgMain, fgMuted, accent;

  _UnifiedTrifectaPainter({
    required this.baseVata,
    required this.curVata,
    required this.colorVata,
    required this.basePitta,
    required this.curPitta,
    required this.colorPitta,
    required this.baseKapha,
    required this.curKapha,
    required this.colorKapha,
    required this.fgMain,
    required this.fgMuted,
    required this.accent,
  });

  static const double _aPitta = -math.pi / 2;
  static const double _aKapha = math.pi / 6;
  static const double _aVata = 5 * math.pi / 6;
  static const int _samples = 240;

  List<Offset> _orbPoints(double rP, double rK, double rV, double wave) {
    const tK = math.pi / 6;
    const tV = 5 * math.pi / 6;
    const tP = 3 * math.pi / 2;

    final pts = <Offset>[];
    for (int i = 0; i <= _samples; i++) {
      final t = (i / _samples) * 2 * math.pi;
      double tNorm = t % (2 * math.pi);
      if (tNorm < 0) tNorm += 2 * math.pi;

      double a0, a1, r0, r1;
      if (tNorm >= tK && tNorm < tV) {
        a0 = tK; r0 = rK; a1 = tV; r1 = rV;
      } else if (tNorm >= tV && tNorm < tP) {
        a0 = tV; r0 = rV; a1 = tP; r1 = rP;
      } else {
        a0 = tP; r0 = rP; a1 = tK + 2 * math.pi; r1 = rK;
        if (tNorm < tK) tNorm += 2 * math.pi;
      }

      final f = (tNorm - a0) / (a1 - a0);
      final smooth = 0.5 - 0.5 * math.cos(f * math.pi);
      final baseRadius = r0 + smooth * (r1 - r0);

      final wobble = math.sin(t * 3) * wave * 0.5 +
          math.cos(t * 5) * wave * 0.3 +
          math.sin(t * 7 + wave) * wave * 0.2;

      final radius = baseRadius + wobble;
      pts.add(Offset(radius * math.cos(t), radius * math.sin(t)));
    }
    return pts;
  }

  Path _pathFrom(List<Offset> pts, Offset Function(Offset) map) {
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final p = map(pts[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  // Generate a wavy circle path for the Venn shapes
  Path _wavyCirclePath(Offset center, double baseRadius) {
    final path = Path();
    const int samples = 120;
    for (int i = 0; i <= samples; i++) {
      final double t = (i / samples) * 2 * math.pi;
      // Organic wobble
      final double wobble = math.sin(t * 4) * (baseRadius * 0.05) + 
                            math.cos(t * 7) * (baseRadius * 0.03);
      final double r = baseRadius + wobble;
      final double x = center.dx + r * math.cos(t);
      final double y = center.dy + r * math.sin(t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    int maxReading = [basePitta, baseKapha, baseVata, curPitta, curKapha, curVata].reduce(math.max);
    if (maxReading < 1) maxReading = 1;

    double unitR(int val) => 0.25 + 0.75 * (val / maxReading);

    final totalShift = ((curPitta - basePitta).abs() + (curKapha - baseKapha).abs() + (curVata - baseVata).abs()).toDouble();
    final curWave = (0.03 + totalShift * 0.0015).clamp(0.03, 0.12);
    const baseWave = 0.02;

    final basePts = _orbPoints(unitR(basePitta), unitR(baseKapha), unitR(baseVata), baseWave);
    final curPts = _orbPoints(unitR(curPitta), unitR(curKapha), unitR(curVata), curWave);

    final allPts = [...basePts, ...curPts];
    double minX = allPts.first.dx, maxX = allPts.first.dx;
    double minY = allPts.first.dy, maxY = allPts.first.dy;
    for (final p in allPts) {
      minX = math.min(minX, p.dx); maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy); maxY = math.max(maxY, p.dy);
    }

    final bboxW = (maxX - minX).clamp(0.0001, double.infinity);
    final bboxH = (maxY - minY).clamp(0.0001, double.infinity);

    const pad = 24.0;
    final scale = math.min((w - pad * 2) / bboxW, (h - pad * 2) / bboxH);

    final bboxCx = (minX + maxX) / 2;
    final bboxCy = (minY + maxY) / 2;

    Offset map(Offset p) => Offset(w / 2 + (p.dx - bboxCx) * scale, h / 2 + (p.dy - bboxCy) * scale);

    // 1. Draw base path faint line
    final basePath = _pathFrom(basePts, map);
    canvas.drawPath(basePath, Paint()..color = fgMuted.withValues(alpha: 0.18)..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true);

    // 2. Draw current path background fill
    final curPath = _pathFrom(curPts, map);
    canvas.drawPath(curPath, Paint()..color = accent.withValues(alpha: 0.10)..style = PaintingStyle.fill..isAntiAlias = true);

    // Calculate anchors moved slightly INSIDE by multiplying radius by 0.65 (was 1.0)
    Offset anchor(double angle, int val) {
      final r = unitR(val) * 0.65;
      return map(Offset(r * math.cos(angle), r * math.sin(angle)));
    }

    void drawWavyVennCircle(Offset pt, Color col, String label, int val) {
      // Circle sized proportionally to its value
      final double radius = 45.0 + (val / maxReading) * 45.0;
      final Path wavyPath = _wavyCirclePath(pt, radius);

      canvas.drawPath(
        wavyPath, 
        Paint()
          ..color = col.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true
      );

      final namePainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontStyle: FontStyle.italic,
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.95),
            shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final valPainter = TextPainter(
        text: TextSpan(
          text: '$val%',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
            shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final totalHeight = namePainter.height + 4 + valPainter.height;
      namePainter.paint(canvas, Offset(pt.dx - namePainter.width / 2, pt.dy - totalHeight / 2));
      valPainter.paint(canvas, Offset(pt.dx - valPainter.width / 2, pt.dy - totalHeight / 2 + namePainter.height + 4));
    }

    // 3. Draw the Wavy Venn Circles (they sit below the solid line)
    drawWavyVennCircle(anchor(_aPitta, curPitta), colorPitta, 'Pitta', curPitta);
    drawWavyVennCircle(anchor(_aVata, curVata), colorVata, 'Vata', curVata);
    drawWavyVennCircle(anchor(_aKapha, curKapha), colorKapha, 'Kapha', curKapha);

    // 4. Draw current path solid stroke OVER the circles
    canvas.drawPath(curPath, Paint()..color = fgMain..style = PaintingStyle.stroke..strokeWidth = 3.5..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _UnifiedTrifectaPainter old) => true;
}
"""

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(safe_top + new_painter)
