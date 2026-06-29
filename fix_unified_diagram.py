import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Replace the 3-column layout with the unified diagram
pattern_layout = r"        // The \"Resonance Orbs\".*?        const SizedBox\(height: 48\),"

new_layout = """        const SizedBox(height: 24),
        // The "Unified Elemental Resonance" Diagram
        SizedBox(
          height: 340,
          width: double.infinity,
          child: CustomPaint(
            painter: _UnifiedTrifectaPainter(
              baseVata: prakriti.vata,
              curVata: vikriti!.vata,
              colorVata: _getDoshaColor('vata'),
              basePitta: prakriti.pitta,
              curPitta: vikriti!.pitta,
              colorPitta: _getDoshaColor('pitta'),
              baseKapha: prakriti.kapha,
              curKapha: vikriti!.kapha,
              colorKapha: _getDoshaColor('kapha'),
              fgMain: fgMain,
              fgMuted: fgMuted,
              faintColor: fgFaint,
            ),
          ),
        ),
        const SizedBox(height: 48),"""

content = re.sub(pattern_layout, new_layout, content, flags=re.DOTALL)

# 2. Remove _buildWaveRingCard entirely
content = re.sub(r"  Widget _buildWaveRingCard.*?  Widget _buildTipSection", "  Widget _buildTipSection", content, flags=re.DOTALL)

# 3. Replace _WaveRingPainter with _UnifiedTrifectaPainter
pattern_painter = r"class _WaveRingPainter extends CustomPainter \{.*"

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
    final maxR = math.min(w, h) / 2 - 50; // Leave room for labels

    // Angles for the 3 corners
    final aPitta = -math.pi / 2;       // Top (Fire)
    final aKapha = math.pi / 6;        // Bottom Right (Earth)
    final aVata = 5 * math.pi / 6;     // Bottom Left (Air)

    // 1. Draw Intersecting Background Circles (Triquetra / Venn grid)
    final gridPaint = Paint()
      ..color = faintColor.withAlpha(30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;
      
    final offsetR = maxR * 0.35;
    final vennR = maxR * 0.65;
    canvas.drawCircle(Offset(c.dx + offsetR * math.cos(aPitta), c.dy + offsetR * math.sin(aPitta)), vennR, gridPaint);
    canvas.drawCircle(Offset(c.dx + offsetR * math.cos(aKapha), c.dy + offsetR * math.sin(aKapha)), vennR, gridPaint);
    canvas.drawCircle(Offset(c.dx + offsetR * math.cos(aVata), c.dy + offsetR * math.sin(aVata)), vennR, gridPaint);

    // 2. Interpolation function to draw the continuous shape
    double getRadiusAtAngle(double angle, bool isBase) {
      // Normalize angle to 0 .. 2PI
      double t = angle % (2 * math.pi);
      if (t < 0) t += 2 * math.pi;

      // Define our 3 anchor points in 0..2PI space
      double tPitta = (-math.pi / 2) % (2 * math.pi); // 1.5 PI
      double tKapha = (math.pi / 6);                  // 0.166 PI
      double tVata = (5 * math.pi / 6);               // 0.833 PI

      // Sort anchors for easy interpolation
      List<Map<String, dynamic>> anchors = [
        {'a': tKapha, 'v': isBase ? baseKapha : curKapha},
        {'a': tVata, 'v': isBase ? baseVata : curVata},
        {'a': tPitta, 'v': isBase ? basePitta : curPitta},
      ];

      // Find which segment t is in
      double a0 = 0, a1 = 0, v0 = 0, v1 = 0;
      if (t >= anchors[0]['a'] && t < anchors[1]['a']) {
        a0 = anchors[0]['a']; v0 = anchors[0]['v'].toDouble();
        a1 = anchors[1]['a']; v1 = anchors[1]['v'].toDouble();
      } else if (t >= anchors[1]['a'] && t < anchors[2]['a']) {
        a0 = anchors[1]['a']; v0 = anchors[1]['v'].toDouble();
        a1 = anchors[2]['a']; v1 = anchors[2]['v'].toDouble();
      } else {
        a0 = anchors[2]['a']; v0 = anchors[2]['v'].toDouble();
        a1 = anchors[0]['a'] + 2 * math.pi; v1 = anchors[0]['v'].toDouble();
        if (t < anchors[0]['a']) t += 2 * math.pi; // wrap around
      }

      // Smoothstep interpolation
      double f = (t - a0) / (a1 - a0);
      double smoothF = f * f * (3 - 2 * f);
      double val = v0 + smoothF * (v1 - v0);
      
      // Convert percentage (0-100) to radius. Min radius 15% so it doesn't collapse to 0.
      return maxR * (0.15 + 0.85 * (val / 100.0));
    }

    // 3. Draw Baseline (Prakriti) - Faint Dotted/Solid smooth polygon
    Path basePath = Path();
    int points = 120;
    for (int i = 0; i <= points; i++) {
      double t = (i / points) * 2 * math.pi;
      double r = getRadiusAtAngle(t, true);
      double x = c.dx + r * math.cos(t);
      double y = c.dy + r * math.sin(t);
      if (i == 0) basePath.moveTo(x, y);
      else basePath.lineTo(x, y);
    }
    basePath.close();
    
    canvas.drawPath(basePath, Paint()
      ..color = fgMuted.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true
    );

    // 4. Draw Current State (Vikriti) - The "One Wave"
    Path wavePath = Path();
    for (int i = 0; i <= points; i++) {
      double t = (i / points) * 2 * math.pi;
      double baseR = getRadiusAtAngle(t, false);
      
      // Add the "Wave" ripple effect
      double waveRipple = 2.5 * math.sin(t * 15); // 15 ripples around the perimeter
      double r = baseR + waveRipple;
      
      double x = c.dx + r * math.cos(t);
      double y = c.dy + r * math.sin(t);
      if (i == 0) wavePath.moveTo(x, y);
      else wavePath.lineTo(x, y);
    }
    wavePath.close();

    // Fill for the wave (gradient or semi-transparent white/glow)
    canvas.drawPath(wavePath, Paint()
      ..color = fgMain.withAlpha(10)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
    );
    
    // Thicker stroke for the wave
    canvas.drawPath(wavePath, Paint()
      ..color = fgMain
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true
    );

    // 5. Draw the 3 Axis Lines inside the shape & Colored Data Nodes
    void drawAxis(double angle, int curVal, Color col) {
      double rBase = maxR;
      double rCur = getRadiusAtAngle(angle, false);
      
      // Faint radial line
      canvas.drawLine(c, Offset(c.dx + rBase * math.cos(angle), c.dy + rBase * math.sin(angle)), gridPaint);
      
      // Data point glowing node
      Offset pt = Offset(c.dx + rCur * math.cos(angle), c.dy + rCur * math.sin(angle));
      canvas.drawCircle(pt, 5, Paint()..color = col..style=PaintingStyle.fill..isAntiAlias=true);
      canvas.drawCircle(pt, 8, Paint()..color = col.withAlpha(80)..style=PaintingStyle.stroke..strokeWidth=2..isAntiAlias=true);
    }

    drawAxis(aPitta, curPitta, colorPitta);
    drawAxis(aKapha, curKapha, colorKapha);
    drawAxis(aVata, curVata, colorVata);

    // 6. Draw Labels at the 3 corners
    void drawCornerLabel(String elem, String dosha, int curVal, double angle, Color col) {
      // Push label out past maxR
      double lr = maxR + 35;
      Offset pt = Offset(c.dx + lr * math.cos(angle), c.dy + lr * math.sin(angle));
      
      final titleSpan = TextSpan(
        children: [
          TextSpan(text: '$elem\\n', style: TextStyle(color: fgMain, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
          TextSpan(text: '$dosha  ', style: TextStyle(color: fgMuted, fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11)),
          TextSpan(text: '$curVal%', style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      );
      
      final tp = TextPainter(text: titleSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
      tp.layout();
      
      // Adjust origin so text is centered on the point
      tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - tp.height / 2));
    }

    drawCornerLabel('FIRE', 'Pitta', curPitta, aPitta, colorPitta);
    drawCornerLabel('EARTH', 'Kapha', curKapha, aKapha, colorKapha);
    drawCornerLabel('AIR', 'Vata', curVata, aVata, colorVata);
  }

  @override
  bool shouldRepaint(covariant _UnifiedTrifectaPainter old) => true;
}
"""

content = re.sub(pattern_painter, new_painter, content, flags=re.DOTALL)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
