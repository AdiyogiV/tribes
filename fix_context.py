import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Pass context to _buildChicContent
content = content.replace(
    "_buildChicContent(fgMain, fgMuted, fgFaint, lineCol),",
    "_buildChicContent(context, fgMain, fgMuted, fgFaint, lineCol),"
)

content = content.replace(
    "Widget _buildChicContent(Color fgMain, Color fgMuted, Color fgFaint, Color lineCol) {",
    "Widget _buildChicContent(BuildContext context, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol) {"
)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
