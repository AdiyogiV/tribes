import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Update the function calls
old_calls = """_buildDataRow(context, 'Vata', 'Air & Space', 'Movement', 'Governs breathing, blinking, muscle movement, heartbeat, and all cellular mobility.', prakriti.vata, vikriti!.vata, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('vata')),
        _buildDataRow(context, 'Pitta', 'Fire & Water', 'Metabolism', 'Governs digestion, absorption, assimilation, nutrition, metabolism, and body temperature.', prakriti.pitta, vikriti!.pitta, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('pitta')),
        _buildDataRow(context, 'Kapha', 'Earth & Water', 'Structure', 'Governs bones, muscles, tendons, and provides the "glue" that holds the cells together.', prakriti.kapha, vikriti!.kapha, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('kapha')),"""

new_calls = """_buildDataRow(context, 'V A T A', 'The Energy of Movement', 'Air & Space · Governs the nervous system', 'Governs breathing, blinking, muscle movement, heartbeat, and all cellular mobility.', prakriti.vata, vikriti!.vata, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('vata')),
        _buildDataRow(context, 'P I T T A', 'The Energy of Metabolism', 'Fire & Water · Governs digestion & heat', 'Governs digestion, absorption, assimilation, nutrition, metabolism, and body temperature.', prakriti.pitta, vikriti!.pitta, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('pitta')),
        _buildDataRow(context, 'K A P H A', 'The Energy of Structure', 'Earth & Water · Governs immunity & stability', 'Governs bones, muscles, tendons, and provides the "glue" that holds the cells together.', prakriti.kapha, vikriti!.kapha, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('kapha')),"""

content = content.replace(old_calls, new_calls)


# 2. Update _buildDataRow top half
old_row_start = """  Widget _buildDataRow(BuildContext context, String label, String elements, String function, String desc, int base, int cur, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol, Color rowColor) {
    final shift = cur - base;
    final shiftStr = shift > 0 ? '+$shift%' : (shift < 0 ? '$shift%' : '—');
    final shiftColor = shift > 0 ? rowColor : fgMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Tier: Text and Numbers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left: Label, Elements, Function
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
                            Text(label.toUpperCase(), style: TextStyle(color: rowColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.0)),
                            const SizedBox(height: 8),
                            Text('$elements · $function', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: fgMain, fontSize: 24)),
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
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: fgMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                        decorationColor: fgFaint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$elements · $function',
                      style: TextStyle(
                        color: fgFaint,
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),"""

new_row_start = """  Widget _buildDataRow(BuildContext context, String label, String editorialSub, String smallLine, String desc, int base, int cur, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol, Color rowColor) {
    final shift = cur - base;
    final shiftStr = shift > 0 ? '+$shift%' : (shift < 0 ? '$shift%' : '—');
    final shiftColor = shift > 0 ? rowColor : fgMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Tier: Text and Numbers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left: Editorial Text Stack
              Expanded(
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
                              Text(label, style: TextStyle(color: rowColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                              const SizedBox(height: 8),
                              Text(editorialSub, style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: fgMain, fontSize: 24)),
                              const SizedBox(height: 6),
                              Text(smallLine, style: TextStyle(color: fgMuted, fontSize: 13)),
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
                      Text(
                        label,
                        style: TextStyle(
                          color: rowColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        editorialSub,
                        style: TextStyle(
                          color: fgMain,
                          fontFamily: 'Georgia',
                          fontStyle: FontStyle.italic,
                          fontSize: 17,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        smallLine,
                        style: TextStyle(
                          color: fgMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),"""

content = content.replace(old_row_start, new_row_start)

# Finally replace the right side data column so the numbers look larger and more elegant
old_right_data = """              // Right: Stacked Data (Today / Change)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$cur%',
                    style: TextStyle(
                      color: fgMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shiftStr == '—' ? 'Baseline' : '$shiftStr shift',
                    style: TextStyle(
                      color: shiftColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),"""

new_right_data = """              // Right: Stacked Data (Today / Change)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$cur%',
                    style: TextStyle(
                      color: fgMain,
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shiftStr == '—' ? 'Baseline' : '$shiftStr shift',
                    style: TextStyle(
                      color: shiftColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),"""

content = content.replace(old_right_data, new_right_data)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)

