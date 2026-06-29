import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Fix literal physical newlines
content = content.replace("'$elem · $dosha\n'", "'$elem · $dosha\\n'")

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
