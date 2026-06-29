import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Fix the method signature to accept bg
content = content.replace("Widget _buildChicContent(BuildContext context, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol) {",
                          "Widget _buildChicContent(BuildContext context, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol, Color bg) {")

content = content.replace("_buildChicContent(context, fgMain, fgMuted, fgFaint, lineCol),",
                          "_buildChicContent(context, fgMain, fgMuted, fgFaint, lineCol, bg),")

# Fix the missing parenthesis for GestureDetector
# The structure is currently:
#         ), // CustomPaint
#       ), // AspectRatio
#     const SizedBox(height: 48), // Uh oh, GestureDetector is not closed here.

content = content.replace("faintColor: fgFaint,\n            ),\n          ),\n        ),\n        const SizedBox(height: 48),",
                          "faintColor: fgFaint,\n            ),\n          ),\n        ),\n        ),\n        const SizedBox(height: 48),")


with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
