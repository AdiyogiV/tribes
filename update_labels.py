import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Update Header Row width
content = content.replace("width: 50,\n              child: Text('DOSHA'", "width: 75,\n              child: Text('DOSHA'")

# 2. Update Data Row calls
old_rows = """_buildDataRow('Vata', prakriti.vata, vikriti!.vata, fgMain, fgMuted, lineCol, _getDoshaColor('vata')),
        const SizedBox(height: 24),
        _buildDataRow('Pitta', prakriti.pitta, vikriti!.pitta, fgMain, fgMuted, lineCol, _getDoshaColor('pitta')),
        const SizedBox(height: 24),
        _buildDataRow('Kapha', prakriti.kapha, vikriti!.kapha, fgMain, fgMuted, lineCol, _getDoshaColor('kapha')),"""

new_rows = """_buildDataRow(context, 'Vata', 'Air & Space', 'Governs movement, breathing, and the nervous system. It is the energy of action.', prakriti.vata, vikriti!.vata, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('vata')),
        const SizedBox(height: 24),
        _buildDataRow(context, 'Pitta', 'Fire & Water', 'Governs digestion, metabolism, and energy production. It is the energy of transformation.', prakriti.pitta, vikriti!.pitta, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('pitta')),
        const SizedBox(height: 24),
        _buildDataRow(context, 'Kapha', 'Earth & Water', 'Governs structure, immunity, and lubrication. It is the energy of stability.', prakriti.kapha, vikriti!.kapha, fgMain, fgMuted, fgFaint, lineCol, _getDoshaColor('kapha')),"""

content = content.replace(old_rows, new_rows)

# 3. Replace the _buildDataRow signature and the first Text block
old_func_start = """Widget _buildDataRow(String label, int base, int cur, Color fgMain, Color fgMuted, Color lineCol, Color rowColor) {
    final shift = cur - base;
    final shiftStr = shift > 0 ? '+$shift%' : (shift < 0 ? '$shift%' : '—');
    final shiftColor = shift > 0 ? rowColor : fgMuted;

    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              color: fgMuted,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
        ),"""

new_func_start = """Widget _buildDataRow(BuildContext context, String label, String elements, String desc, int base, int cur, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol, Color rowColor) {
    final shift = cur - base;
    final shiftStr = shift > 0 ? '+$shift%' : (shift < 0 ? '$shift%' : '—');
    final shiftColor = shift > 0 ? rowColor : fgMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 75,
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
                        Text(label.toUpperCase(), style: TextStyle(color: rowColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.0)),
                        const SizedBox(height: 8),
                        Text(elements, style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: fgMain, fontSize: 24)),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: fgMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: fgFaint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  elements,
                  style: TextStyle(
                    color: fgFaint,
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),"""

content = content.replace(old_func_start, new_func_start)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
