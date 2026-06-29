import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Fix the angle logic (from || to &&)
content = content.replace("else if (angle >= 3.66 || angle < 5.75) {", "else if (angle >= 3.66 && angle < 5.75) {")

# 2. Fix the background color of the bottom sheet
# The signature is: void _showDoshaExplainer(BuildContext context, String dosha, Color fgMain, Color fgMuted, Color bg)
# Let's change the container color logic inside the builder
content = content.replace("color: bg,", "color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF9F9F9),")

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
