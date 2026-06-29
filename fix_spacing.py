import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Replace width: 45 with width: 60 to give more room for "CHANGE" and "TODAY"
content = content.replace("width: 45,", "width: 60,")

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
