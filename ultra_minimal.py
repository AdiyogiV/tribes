import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Update the function calls
old_calls = """_buildDataRow(context, 'Vata', 'AIR & SPACE · MOVEMENT', 'Governs breathing, blinking, muscle movement, heartbeat, and all cellular mobility.', prakriti.vata, vikriti!.vata, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('vata')),
        _buildDataRow(context, 'Pitta', 'FIRE & WATER · METABOLISM', 'Governs digestion, absorption, assimilation, nutrition, metabolism, and body temperature.', prakriti.pitta, vikriti!.pitta, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('pitta')),
        _buildDataRow(context, 'Kapha', 'EARTH & WATER · STRUCTURE', 'Governs bones, muscles, tendons, and provides the "glue" that holds the cells together.', prakriti.kapha, vikriti!.kapha, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('kapha')),"""

new_calls = """_buildDataRow(context, 'Vata', 'AIR & SPACE', 'Governs breathing, blinking, muscle movement, heartbeat, and all cellular mobility.', prakriti.vata, vikriti!.vata, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('vata')),
        _buildDataRow(context, 'Pitta', 'FIRE & WATER', 'Governs digestion, absorption, assimilation, nutrition, metabolism, and body temperature.', prakriti.pitta, vikriti!.pitta, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('pitta')),
        _buildDataRow(context, 'Kapha', 'EARTH & WATER', 'Governs bones, muscles, tendons, and provides the "glue" that holds the cells together.', prakriti.kapha, vikriti!.kapha, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('kapha')),"""

content = content.replace(old_calls, new_calls)


# 2. Rewrite _buildDataRow completely for ultra-minimalism
pattern = r"  Widget _buildDataRow\(BuildContext context.*?return Padding\(.*?child: Column\([\s\S]*?\]\),\n      \),\n    \);\n  \}"

new_row = """  Widget _buildDataRow(BuildContext context, String label, String subline, String desc, int base, int cur, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol, Color rowColor) {
    final shift = cur - base;
    final isShifted = shift.abs() > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // Single-line Minimal Editorial Text
              GestureDetector(
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
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: label,
                        style: TextStyle(
                          color: rowColor,
                          fontFamily: 'Georgia',
                          fontStyle: FontStyle.italic,
                          fontSize: 18,
                        ),
                      ),
                      TextSpan(
                        text: '    $subline',
                        style: TextStyle(
                          color: fgFaint,
                          fontSize: 9,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Only the current percentage
              Text(
                '$cur%',
                style: TextStyle(
                  color: fgMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Ultra-thin 1px Minimal Graph
          LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final bX = w * (base / 100).clamp(0.0, 1.0);
            final cX = w * (cur / 100).clamp(0.0, 1.0);
            
            return SizedBox(
              height: 8,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Faint Track
                  Container(height: 1, width: w, color: lineCol.withAlpha(50)),
                  
                  // Connecting Bar
                  if (isShifted)
                    Positioned(
                      left: math.min(bX, cX),
                      child: Container(
                        width: (cX - bX).abs(),
                        height: 1,
                        color: rowColor.withAlpha(100),
                      ),
                    ),
                    
                  // Baseline Pip (Tiny, muted)
                  Positioned(
                    left: bX,
                    child: Container(width: 1, height: 4, color: fgMuted.withAlpha(100)),
                  ),
                    
                  // Today's Pip (Colored, slightly taller)
                  Positioned(
                    left: cX - 0.5,
                    child: Container(
                      width: 1.5, 
                      height: 8, 
                      color: isShifted ? rowColor : fgMuted,
                    ),
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }"""

content = re.sub(pattern, new_row, content, flags=re.DOTALL)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)

