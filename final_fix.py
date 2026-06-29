import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# remove unused _EditorialRulerPainter class entirely from the bottom
content = re.sub(r'class _EditorialRulerPainter extends CustomPainter \{.*', '', content, flags=re.DOTALL)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
