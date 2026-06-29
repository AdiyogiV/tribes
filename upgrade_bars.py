import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

start_idx = content.find('  Widget _buildChicBar(')
end_idx = content.find('  void _showDoshaExplainer(')

old_chic_bar = content[start_idx:end_idx]

new_chic_bar = """  Widget _buildChicBar(BuildContext context, String name, int val, Color col, Color fgMain, Color fgMuted, Color bg) {
    String element = '';
    String function = '';
    if (name.toLowerCase() == 'vata') {
      element = 'AIR & ETHER';
      function = 'Movement & Communication';
    } else if (name.toLowerCase() == 'pitta') {
      element = 'FIRE & WATER';
      function = 'Metabolism & Transformation';
    } else {
      element = 'EARTH & WATER';
      function = 'Structure & Lubrication';
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        _showDoshaExplainer(context, name.toLowerCase(), fgMain, fgMuted, bg);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    fontSize: 20,
                    color: fgMain.withValues(alpha: 0.95),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$val%',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    color: col,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, size: 12, color: fgMuted.withValues(alpha: 0.4)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  element,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: fgMuted.withValues(alpha: 0.7),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text('—', style: TextStyle(color: fgMuted.withValues(alpha: 0.3), fontSize: 10)),
                ),
                Text(
                  function,
                  style: TextStyle(
                    fontSize: 12,
                    color: fgMuted.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                    fontFamily: 'Georgia',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: 1.0, // Elegant hairline track
                      width: double.infinity,
                      color: fgMuted.withValues(alpha: 0.15),
                    ),
                    Container(
                      height: 1.0,
                      width: constraints.maxWidth * (val / 100.0).clamp(0.0, 1.0),
                      color: col,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

"""

new_content = content[:start_idx] + new_chic_bar + content[end_idx:]

# Let's also add an elegant "CURRENT BALANCE" label above the state title for maximum chicness.
old_ui = """        // Heading
        doshaDisplay.isEmpty 
          ? Text("""

new_ui = """        Text(
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
        doshaDisplay.isEmpty 
          ? Text("""

new_content = new_content.replace(old_ui, new_ui)

# Add a divider above the chic bars
old_chic_bars_section = """        // Chic Editorial Tappable Bars
        _buildChicBar(context, 'Vata', vikriti!.vata, getDoshaColor('vata'), fgMain, fgMuted, bg),"""

new_chic_bars_section = """        // Chic Editorial Tappable Bars
        Container(height: 1.0, width: double.infinity, color: fgMuted.withValues(alpha: 0.1)),
        const SizedBox(height: 8),
        _buildChicBar(context, 'Vata', vikriti!.vata, getDoshaColor('vata'), fgMain, fgMuted, bg),"""

new_content = new_content.replace(old_chic_bars_section, new_chic_bars_section)

# Add a divider above the tips
old_tips_section = """        // Utility: Tips (Two columns with ghosted serifs)
        Row("""

new_tips_section = """        Container(height: 1.0, width: double.infinity, color: fgMuted.withValues(alpha: 0.1)),
        const SizedBox(height: 32),
        // Utility: Tips (Two columns with ghosted serifs)
        Row("""

new_content = new_content.replace(old_tips_section, new_tips_section)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(new_content)
