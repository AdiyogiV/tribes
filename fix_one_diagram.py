import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# First, clean up the build method to just have the unified diagram, removing the separate _buildVennDiagram calls
old_venn_call = """        // The Wavy Elemental Resonance Orbs (Baseline vs Current)
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

new_venn_call = """        // Single Unified Wavy Orb + Venn Diagram Graphic
        Center(
          child: SizedBox(
            width: 320,
            height: 320,
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
        ),"""

content = content.replace(old_venn_call, new_venn_call)

# Remove the old _buildVennDiagram and _vennCircle completely
import re
content = re.sub(r'  Widget _buildVennDiagram.*?Widget _buildTipSection', '  Widget _buildTipSection', content, flags=re.DOTALL)

# Now, update the _UnifiedTrifectaPainter to draw the Venn circles INSTEAD of the small markers
old_painter = """    void drawMarker(Offset pt, Color col) {
      canvas.drawCircle(pt, 16.0, Paint()..color = col.withValues(alpha: 0.12)..style = PaintingStyle.fill..isAntiAlias = true);
      canvas.drawCircle(pt, 16.0, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true);
      canvas.drawCircle(pt, 6.0, Paint()..color = col..style = PaintingStyle.fill..isAntiAlias = true);
    }

    drawMarker(anchor(_aPitta, curPitta), colorPitta);
    drawMarker(anchor(_aKapha, curKapha), colorKapha);
    drawMarker(anchor(_aVata, curVata), colorVata);"""

new_painter = """    void drawVennCircle(Offset pt, Color col, String label, int val) {
      // Large Venn Circle
      canvas.drawCircle(
        pt, 
        80.0, 
        Paint()
          ..color = col.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true
      );

      // Label Text (e.g., "Pitta")
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

      // Percentage Text (e.g., "42%")
      final valPainter = TextPainter(
        text: TextSpan(
          text: '${val}%',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final totalHeight = namePainter.height + 4 + valPainter.height;
      
      namePainter.paint(canvas, Offset(pt.dx - namePainter.width / 2, pt.dy - totalHeight / 2));
      valPainter.paint(canvas, Offset(pt.dx - valPainter.width / 2, pt.dy - totalHeight / 2 + namePainter.height + 4));
    }

    // Replace tiny dots with massive overlapping Venn circles at the anchor points!
    drawVennCircle(anchor(_aPitta, curPitta), colorPitta, 'Pitta', curPitta);
    drawVennCircle(anchor(_aVata, curVata), colorVata, 'Vata', curVata);
    drawVennCircle(anchor(_aKapha, curKapha), colorKapha, 'Kapha', curKapha);"""

content = content.replace(old_painter, new_painter)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
