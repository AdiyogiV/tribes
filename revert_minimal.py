import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Remove the "CURRENT BALANCE" eyebrow
old_eyebrow = """        Text(
          'CURRENT BALANCE',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
            color: fgMuted.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        // Heading
        doshaDisplay.isEmpty"""

new_eyebrow = """        // Heading
        doshaDisplay.isEmpty"""

content = content.replace(old_eyebrow, new_eyebrow)

# 2. Remove the top divider
old_div_top = """        // Chic Editorial Tappable Bars
        Container(height: 1.0, width: double.infinity, color: fgMuted.withValues(alpha: 0.1)),
        const SizedBox(height: 8),
        _buildChicBar("""

new_div_top = """        // Chic Editorial Tappable Bars
        _buildChicBar("""

content = content.replace(old_div_top, new_div_top)

# 3. Remove the bottom divider
old_div_bot = """        Container(height: 1.0, width: double.infinity, color: fgMuted.withValues(alpha: 0.1)),
        const SizedBox(height: 32),
        // Utility: Tips"""

new_div_bot = """        const SizedBox(height: 32),
        // Utility: Tips"""

content = content.replace(old_div_bot, new_div_bot)

# 4. Replace _buildChicBar with a clean, single-line minimal version
start_idx = content.find('  Widget _buildChicBar(')
end_idx = content.find('  void _showDoshaExplainer(')

minimal_chic_bar = """  Widget _buildChicBar(BuildContext context, String name, int val, Color col, Color fgMain, Color fgMuted, Color bg) {
    String element = '';
    if (name.toLowerCase() == 'vata') {
      element = 'AIR / ETHER';
    } else if (name.toLowerCase() == 'pitta') {
      element = 'FIRE / WATER';
    } else {
      element = 'EARTH / WATER';
    }

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
              width: 140, // Enough room for name + element
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: name,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                        color: fgMain.withValues(alpha: 0.86),
                        letterSpacing: 0.5,
                      ),
                    ),
                    TextSpan(
                      text: '   $element',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: fgMuted.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
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
                        height: 1.0,
                        width: double.infinity,
                        color: fgMuted.withValues(alpha: 0.12),
                      ),
                      Container(
                        height: 1.0,
                        width: constraints.maxWidth * (val / 100.0).clamp(0.0, 1.0),
                        color: col.withValues(alpha: 0.8),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 32,
              child: Text(
                '$val%',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  color: fgMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: fgMuted.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

"""

new_content = content[:start_idx] + minimal_chic_bar + content[end_idx:]

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(new_content)
