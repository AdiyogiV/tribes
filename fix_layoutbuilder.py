import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

old_block = r"""        Builder\(
          builder: \(builderContext\) => GestureDetector\(
            behavior: HitTestBehavior\.opaque,
            onTapUp: \(details\) \{
              final RenderBox box = builderContext\.findRenderObject\(\) as RenderBox;
              final center = Offset\(box\.size\.width / 2, box\.size\.height / 2\);
              final dx = details\.localPosition\.dx - center\.dx;
              final dy = details\.localPosition\.dy - center\.dy;
            
              // Simpler, foolproof zone detection based on quadrants/halves
              String tappedDosha;
              if \(dy < -20\) \{
                // Upper half is Pitta
                tappedDosha = 'pitta';
              \} else \{
                // Lower half, split left/right
                if \(dx < 0\) \{
                  tappedDosha = 'vata'; // Bottom Left
                \} else \{
                  tappedDosha = 'kapha'; // Bottom Right
                \}
              \}
            
              HapticFeedback\.lightImpact\(\);
              _showDoshaExplainer\(context, tappedDosha, fgMain, fgMuted, bg\);
            \},"""

new_block = """        LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final x = details.localPosition.dx;
              final y = details.localPosition.dy;
              
              String tappedDosha;
              if (y < h * 0.45) { // Top 45% is Pitta
                tappedDosha = 'pitta';
              } else {
                if (x < w * 0.5) { // Bottom left is Vata
                  tappedDosha = 'vata';
                } else { // Bottom right is Kapha
                  tappedDosha = 'kapha';
                }
              }
              
              HapticFeedback.lightImpact();
              _showDoshaExplainer(context, tappedDosha, fgMain, fgMuted, bg);
            },"""

content = re.sub(old_block, new_block, content)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
