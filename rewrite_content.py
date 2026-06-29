import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Let's extract the part from `Widget _buildChicContent` to `return Column(` inside it, down to `Row( crossAxisAlignment: CrossAxisAlignment.start,`

start_marker = "Widget _buildChicContent(BuildContext context, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol, Color bg) {"
end_marker = "        // Utility: Tips"

new_chic_content = """Widget _buildChicContent(BuildContext context, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol, Color bg) {
    final String dominantDosha = prakriti.type.split('-').first.toLowerCase();
    final Color accentColor = _getDoshaColor(dominantDosha);
    final String vikritiType = hasVikriti ? vikriti!.type : "Balancing";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top section: "Your Current State"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT STATE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    color: fgMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  vikritiType,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 32,
                    fontStyle: FontStyle.italic,
                    color: fgMain,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CustomPaint(
                    painter: _DoshaSigilPainter(dosha: dominantDosha, color: accentColor),
                  ),
                ),
                if (onInfo != null)
                  GestureDetector(
                    onTap: onInfo,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Icon(Icons.info_outline, size: 18, color: fgMuted),
                    ),
                  ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 40),

        // The "Unified Elemental Resonance" Diagram (Pure Art, not tappable)
        AspectRatio(
          aspectRatio: 1.0,
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

        const SizedBox(height: 32),

        // Chic Editorial Tappable Bars
        _buildChicBar(context, 'Vata', vikriti!.vata, _getDoshaColor('vata'), fgMain, fgMuted, bg),
        _buildChicBar(context, 'Pitta', vikriti!.pitta, _getDoshaColor('pitta'), fgMain, fgMuted, bg),
        _buildChicBar(context, 'Kapha', vikriti!.kapha, _getDoshaColor('kapha'), fgMain, fgMuted, bg),

        const SizedBox(height: 48),

        // Utility: Tips"""

content = content[:content.find(start_marker)] + new_chic_content + content[content.find(end_marker) + len("        // Utility: Tips"):]

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
