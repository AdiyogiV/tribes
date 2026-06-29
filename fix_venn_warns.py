with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Remove accent unused var
content = content.replace("final accent = getDoshaColor(dominantDosha);", "")

# Remove dart:math import if it exists
import re
content = re.sub(r"import 'dart:math'.*?\n", "", content)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
