with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

start_idx = content.find('  Widget _buildChicBar(')
end_idx = content.find('  void _showDoshaExplainer(')

minimal_chic_bar = """  Widget _buildChicBar(BuildContext context, String name, int val, Color col, Color fgMain, Color fgMuted, Color bg) {
    String element = '';
    String function = '';
    if (name.toLowerCase() == 'vata') {
      element = 'AIR / ETHER';
      function = 'Governs movement and communication.';
    } else if (name.toLowerCase() == 'pitta') {
      element = 'FIRE / WATER';
      function = 'Governs metabolism and transformation.';
    } else {
      element = 'EARTH / WATER';
      function = 'Governs structure and lubrication.';
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        _showDoshaExplainer(context, name.toLowerCase(), fgMain, fgMuted, bg);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    fontSize: 18,
                    color: fgMain.withValues(alpha: 0.9),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '$val%',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    color: col.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14, color: fgMuted.withValues(alpha: 0.4)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$element  ·  $function',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
                color: fgMuted.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
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
          ],
        ),
      ),
    );
  }

"""

new_content = content[:start_idx] + minimal_chic_bar + content[end_idx:]

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(new_content)
