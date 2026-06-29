import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# There's likely an unreferenced _EditorialRulerPainter at the very end of the file.
# Let's remove any duplicates of _EditorialRulerPainter
parts = content.split('class _EditorialRulerPainter')
if len(parts) > 2:
    # Keep the first part and the second part (which is the first declaration)
    content = parts[0] + 'class _EditorialRulerPainter' + parts[1]

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
