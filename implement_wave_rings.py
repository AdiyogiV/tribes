import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Update the Row calls in _buildChicContent
old_row = """        // Fresh 3-Column "Health Rings / Pillars" Layout
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVerticalDoshaCard(context, 'Air', 'Vata', 'Governs breathing, blinking, muscle movement, heartbeat, and all cellular mobility.', prakriti.vata, vikriti!.vata, _getDoshaColor('vata'), fgMain, fgMuted),
            _buildVerticalDoshaCard(context, 'Fire', 'Pitta', 'Governs digestion, absorption, assimilation, nutrition, metabolism, and body temperature.', prakriti.pitta, vikriti!.pitta, _getDoshaColor('pitta'), fgMain, fgMuted),
            _buildVerticalDoshaCard(context, 'Earth', 'Kapha', 'Governs bones, muscles, tendons, and provides the "glue" that holds the cells together.', prakriti.kapha, vikriti!.kapha, _getDoshaColor('kapha'), fgMain, fgMuted),
          ],
        ),"""

new_row = """        // The "Resonance Orbs" Layout (Concentric Waves)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWaveRingCard(context, 'Air', 'Vata', 'MOVEMENT', 'Governs breathing, blinking, and the nervous system.', prakriti.vata, vikriti!.vata, _getDoshaColor('vata'), fgMain, fgMuted, fgFaint),
            _buildWaveRingCard(context, 'Fire', 'Pitta', 'METABOLISM', 'Governs digestion, heat, and energy transformation.', prakriti.pitta, vikriti!.pitta, _getDoshaColor('pitta'), fgMain, fgMuted, fgFaint),
            _buildWaveRingCard(context, 'Earth', 'Kapha', 'STRUCTURE', 'Governs immunity, bones, and body lubrication.', prakriti.kapha, vikriti!.kapha, _getDoshaColor('kapha'), fgMain, fgMuted, fgFaint),
          ],
        ),"""

content = content.replace(old_row, new_row)

# 2. Replace _buildVerticalDoshaCard with _buildWaveRingCard entirely
pattern_card = r"  Widget _buildVerticalDoshaCard.*?  Widget _buildTipSection"
new_card = """  Widget _buildWaveRingCard(BuildContext context, String element, String dosha, String func, String desc, int base, int cur, Color color, Color fgMain, Color fgMuted, Color fgFaint) {
    final shift = cur - base;
    final isElevated = shift > 0;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111111) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$element ENERGY'.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                    const SizedBox(height: 8),
                    Text(dosha, style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: fgMain, fontSize: 24)),
                    const SizedBox(height: 24),
                    Text(desc, style: TextStyle(color: fgMuted, fontSize: 14, height: 1.6)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(
              element.toUpperCase(),
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2.0),
            ),
            const SizedBox(height: 4),
            Text(
              func,
              style: TextStyle(color: fgMuted, fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: 1.0),
            ),
            
            const SizedBox(height: 24),
            
            // The Resonant Wave Visualization
            SizedBox(
              height: 90,
              width: 90,
              child: CustomPaint(
                painter: _WaveRingPainter(
                  base: base,
                  cur: cur,
                  color: color,
                  faintColor: fgFaint,
                  dosha: dosha.toLowerCase(),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              '$cur%',
              style: TextStyle(color: fgMain, fontSize: 22, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 4),
            Text(
              shift > 0 ? '+$shift% shift' : (shift < 0 ? '$shift% shift' : 'Balanced'),
              style: TextStyle(
                color: isElevated ? color : fgMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipSection"""

content = re.sub(pattern_card, new_card, content, flags=re.DOTALL)


# 3. Replace _VerticalGaugePainter with _WaveRingPainter
pattern_painter = r"class _VerticalGaugePainter extends CustomPainter \{.*"
new_painter = """class _WaveRingPainter extends CustomPainter {
  final int base;
  final int cur;
  final Color color;
  final Color faintColor;
  final String dosha;

  _WaveRingPainter({
    required this.base,
    required this.cur,
    required this.color,
    required this.faintColor,
    required this.dosha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, size.height / 2);
    final maxR = w / 2 - 4;

    // 1. Draw the 3 Concentric "Grid" Circles (Faint)
    final gridPaint = Paint()
      ..color = faintColor.withAlpha(25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    canvas.drawCircle(c, maxR * 0.33, gridPaint);
    canvas.drawCircle(c, maxR * 0.66, gridPaint);
    canvas.drawCircle(c, maxR * 1.0, gridPaint);

    // 2. Draw Baseline Target (Perfect Circle)
    final baseR = maxR * (base / 100.0).clamp(0.15, 1.0);
    final basePaint = Paint()
      ..color = faintColor.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;
    canvas.drawCircle(c, baseR, basePaint);

    // 3. Draw Current State (Resonant Wave)
    final curR = maxR * (cur / 100.0).clamp(0.15, 1.0);
    final shift = cur - base;
    final isElevated = shift > 0;
    
    // Calculate turbulence (amplitude) based on imbalance
    final amplitude = isElevated ? (shift * 0.25).clamp(2.0, 6.0) : 0.0;
    
    int freq = 5;
    if (dosha == 'vata') freq = 8; // Air is fast/erratic
    if (dosha == 'kapha') freq = 3; // Earth is slow/rolling

    Path wavePath = Path();
    int points = 120;
    for (int i = 0; i <= points; i++) {
      double t = (i / points) * 2 * math.pi;
      // Add a smooth sine wave onto the radius
      double r = curR + amplitude * math.sin(t * freq);
      double x = c.dx + r * math.cos(t);
      double y = c.dy + r * math.sin(t);
      if (i == 0) wavePath.moveTo(x, y);
      else wavePath.lineTo(x, y);
    }
    wavePath.close();

    // Soft glow behind the wave if elevated
    if (isElevated) {
      final glowPaint = Paint()
        ..color = color.withAlpha(50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
        ..isAntiAlias = true;
      canvas.drawPath(wavePath, glowPaint);
    }

    final curPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;
    canvas.drawPath(wavePath, curPaint);
    
    // Center point (The "Seed")
    canvas.drawCircle(c, 2.0, Paint()..color = color..style=PaintingStyle.fill..isAntiAlias=true);
  }

  @override
  bool shouldRepaint(covariant _WaveRingPainter old) => true;
}
"""

content = re.sub(pattern_painter, new_painter, content, flags=re.DOTALL)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)

