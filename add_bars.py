import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Remove the layout builder gesture detector
old_diagram = r"""        LayoutBuilder\(
          builder: \(context, constraints\) => GestureDetector\(
            behavior: HitTestBehavior\.opaque,
            onTapUp: \(details\) \{
              final w = constraints\.maxWidth;
              final h = constraints\.maxHeight;
              final x = details\.localPosition\.dx;
              final y = details\.localPosition\.dy;
              
              String tappedDosha;
              if \(y < h \* 0\.45\) \{ // Top 45% is Pitta
                tappedDosha = 'pitta';
              \} else \{
                if \(x < w \* 0\.5\) \{ // Bottom left is Vata
                  tappedDosha = 'vata';
                \} else \{ // Bottom right is Kapha
                  tappedDosha = 'kapha';
                \}
              \}
              
              HapticFeedback\.lightImpact\(\);
              _showDoshaExplainer\(context, tappedDosha, fgMain, fgMuted, bg\);
            \},
            child: AspectRatio\("""

new_diagram = """        AspectRatio("""

content = re.sub(old_diagram, new_diagram, content)

# 2. Fix the brackets closing CustomPaint and AspectRatio
content = content.replace("          ),\n        ),\n        ),\n        const SizedBox(height: 48),",
                          "          ),\n        ),\n        const SizedBox(height: 48),")

# 3. Add the chic bar widget
bar_widget = """
  Widget _buildChicBar(BuildContext context, String name, int val, Color col, Color fgMain, Color fgMuted, Color bg) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        _showDoshaExplainer(context, name.toLowerCase(), fgMain, fgMuted, bg);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                  color: fgMain.withAlpha(220),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$val%',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: fgMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 2,
                        width: double.infinity,
                        color: fgMuted.withAlpha(30),
                      ),
                      Container(
                        height: 2,
                        width: constraints.maxWidth * (val / 100.0).clamp(0.0, 1.0),
                        color: col.withAlpha(200),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
"""

content = re.sub(r"(Widget _buildTipSection)", bar_widget + r"\n  \1", content)

# 4. Inject the calls into _buildChicContent
injection = """        const SizedBox(height: 24),

        // Chic Editorial Tappable Bars
        _buildChicBar(context, 'Vata', vikriti!.vata, _getDoshaColor('vata'), fgMain, fgMuted, bg),
        _buildChicBar(context, 'Pitta', vikriti!.pitta, _getDoshaColor('pitta'), fgMain, fgMuted, bg),
        _buildChicBar(context, 'Kapha', vikriti!.kapha, _getDoshaColor('kapha'), fgMain, fgMuted, bg),

        const SizedBox(height: 48),

        // Utility: Tips"""

content = content.replace("const SizedBox(height: 48),\n\n        // Utility: Tips", injection)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
