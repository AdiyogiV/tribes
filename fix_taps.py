import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Let's fix the angle logic completely.
old_gesture = r"""          onTapUp: \(details\) \{
            // Calculate angle from center to determine which dosha was tapped
            final RenderBox box = context\.findRenderObject\(\) as RenderBox;
            final center = Offset\(box\.size\.width / 2, box\.size\.height / 2\);
            final tap = details\.localPosition;
            final dx = tap\.dx - center\.dx;
            final dy = tap\.dy - center\.dy;
            
            // Atan2 gives angle from -pi to pi \(0 is right, pi/2 is bottom\)
            double angle = math\.atan2\(dy, dx\);
            if \(angle < 0\) angle \+= 2 \* math\.pi; // Normalize to 0 \.\. 2pi
            
            // Pitta is at top \(-pi/2 or 1\.5 pi\)
            // Kapha is at bottom right \(pi/6 or 0\.52 rad\)
            // Vata is at bottom left \(5pi/6 or 2\.61 rad\)
            
            String tappedDosha = 'kapha';
            if \(angle > 1\.57 && angle < 3\.66\) \{
              tappedDosha = 'vata';
            \} else if \(angle >= 3\.66 && angle < 5\.75\) \{
              tappedDosha = 'pitta';
            \}
            // Add haptic feedback
            HapticFeedback\.lightImpact\(\);
            _showDoshaExplainer\(context, tappedDosha, fgMain, fgMuted, bg\);
          \},"""

new_gesture = """          onTapUp: (details) {
            // Find center of the widget
            final RenderBox box = context.findRenderObject() as RenderBox;
            final center = Offset(box.size.width / 2, box.size.height / 2);
            final dx = details.localPosition.dx - center.dx;
            final dy = details.localPosition.dy - center.dy;
            
            // Simpler, foolproof zone detection based on quadrants/halves
            String tappedDosha;
            if (dy < -20) {
              // Upper half is Pitta
              tappedDosha = 'pitta';
            } else {
              // Lower half, split left/right
              if (dx < 0) {
                tappedDosha = 'vata'; // Bottom Left
              } else {
                tappedDosha = 'kapha'; // Bottom Right
              }
            }
            
            HapticFeedback.lightImpact();
            _showDoshaExplainer(context, tappedDosha, fgMain, fgMuted, bg);
          },"""

content = re.sub(old_gesture, new_gesture, content)

# 2. Make the bottom sheet noticeably grey/elevated.
content = content.replace("color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF9F9F9),",
                          "color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),")

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
