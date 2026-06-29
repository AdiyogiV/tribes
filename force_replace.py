import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Find the exact start of _buildDataRow and the start of _buildTipSection
start_idx = content.find("  Widget _buildDataRow(BuildContext context")
end_idx = content.find("  Widget _buildTipSection(")

if start_idx != -1 and end_idx != -1:
    new_row = """  Widget _buildDataRow(BuildContext context, String label, String subline, String desc, int base, int cur, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol, Color rowColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 36.0),
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
                    Text(label.toUpperCase(), style: TextStyle(color: rowColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                    const SizedBox(height: 8),
                    Text(subline, style: TextStyle(color: fgMain, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 1.0)),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: rowColor,
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subline.split('·')[0].trim(),
                      style: TextStyle(
                        color: fgMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${cur}%',
                  style: TextStyle(
                    color: fgMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // The "Classic Thread" Graph
            LayoutBuilder(builder: (context, constraints) {
              final w = constraints.maxWidth;
              final bX = w * (base / 100).clamp(0.0, 1.0);
              final cX = w * (cur / 100).clamp(0.0, 1.0);
              
              return SizedBox(
                height: 4,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Faint background track
                    Container(
                      width: w,
                      height: 1,
                      margin: const EdgeInsets.only(top: 1.5),
                      color: lineCol.withAlpha(50),
                    ),
                    // The colored data thread
                    Container(
                      width: cX,
                      height: 1.5,
                      margin: const EdgeInsets.only(top: 1.25),
                      color: rowColor,
                    ),
                    // Tiny baseline marker
                    Positioned(
                      left: bX,
                      top: 0,
                      child: Container(
                        width: 1,
                        height: 4,
                        color: fgMuted.withAlpha(150),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

"""
    
    content = content[:start_idx] + new_row + content[end_idx:]

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)

