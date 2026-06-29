import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Make sure dart:math is imported
if "import 'dart:math'" not in content:
    content = "import 'dart:math' as math;\n" + content

# We need to insert the orb widget in _buildVennContent
old_build_venn_content = """        // Big Venn Diagram centered
        Center(
          child: SizedBox(
            width: 280,
            height: 280,
            child: _buildVennDiagram(
              pittaVal: vikriti!.pitta,
              kaphaVal: vikriti!.kapha,
              vataVal: vikriti!.vata,
              fgMain: fgMain,
            ),
          ),
        ),"""

new_build_venn_content = """        // The Wavy Elemental Resonance Orbs (Baseline vs Current)
        AspectRatio(
          aspectRatio: 1.0,
          child: CustomPaint(
            painter: _UnifiedTrifectaPainter(
              baseVata: prakriti.vata,
              curVata: vikriti!.vata,
              colorVata: getDoshaColor('vata'),
              basePitta: prakriti.pitta,
              curPitta: vikriti!.pitta,
              colorPitta: getDoshaColor('pitta'),
              baseKapha: prakriti.kapha,
              curKapha: vikriti!.kapha,
              colorKapha: getDoshaColor('kapha'),
              fgMain: fgMain,
              fgMuted: fgMuted,
              accent: getDoshaColor(dominantDosha),
            ),
          ),
        ),

        const SizedBox(height: 60),

        // Big Venn Diagram centered
        Center(
          child: SizedBox(
            width: 280,
            height: 280,
            child: _buildVennDiagram(
              pittaVal: vikriti!.pitta,
              kaphaVal: vikriti!.kapha,
              vataVal: vikriti!.vata,
              fgMain: fgMain,
            ),
          ),
        ),"""

content = content.replace(old_build_venn_content, new_build_venn_content)

# Append the _UnifiedTrifectaPainter class
painter_class = """

// ─────────────────────────────────────────────────────────────────────────────
// _UnifiedTrifectaPainter - Wavy elemental resonance orb (baseline vs current)
// ─────────────────────────────────────────────────────────────────────────────

class _UnifiedTrifectaPainter extends CustomPainter {
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
      if (i == 0) path.moveTo(p.dx, p.dy);
      else path.lineTo(p.dx, p.dy);
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

    final basePath = _pathFrom(basePts, map);
    canvas.drawPath(basePath, Paint()..color = fgMuted.withValues(alpha: 0.18)..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true);

    final curPath = _pathFrom(curPts, map);
    canvas.drawPath(curPath, Paint()..color = accent.withValues(alpha: 0.10)..style = PaintingStyle.fill..isAntiAlias = true);
    canvas.drawPath(curPath, Paint()..color = fgMain..style = PaintingStyle.stroke..strokeWidth = 3.5..isAntiAlias = true);

    Offset anchor(double angle, int val) {
      final r = unitR(val);
      return map(Offset(r * math.cos(angle), r * math.sin(angle)));
    }

    void drawMarker(Offset pt, Color col) {
      canvas.drawCircle(pt, 16.0, Paint()..color = col.withValues(alpha: 0.12)..style = PaintingStyle.fill..isAntiAlias = true);
      canvas.drawCircle(pt, 16.0, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true);
      canvas.drawCircle(pt, 6.0, Paint()..color = col..style = PaintingStyle.fill..isAntiAlias = true);
    }

    drawMarker(anchor(_aPitta, curPitta), colorPitta);
    drawMarker(anchor(_aKapha, curKapha), colorKapha);
    drawMarker(anchor(_aVata, curVata), colorVata);
  }

  @override
  bool shouldRepaint(covariant _UnifiedTrifectaPainter old) => true;
}
"""

if "_UnifiedTrifectaPainter" not in content[content.rfind('}'):]:
    content += painter_class

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
