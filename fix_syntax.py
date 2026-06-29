import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Fix braces and string literals
content = content.replace("if (i == 0) basePath.moveTo(x, y);\n      else basePath.lineTo(x, y);", "if (i == 0) { basePath.moveTo(x, y); }\n      else { basePath.lineTo(x, y); }")
content = content.replace("if (i == 0) wavePath.moveTo(x, y);\n      else wavePath.lineTo(x, y);", "if (i == 0) { wavePath.moveTo(x, y); }\n      else { wavePath.lineTo(x, y); }")

# Fix TextSpan newline escaping error
content = content.replace("TextSpan(text: '$elem\\\\n',", "TextSpan(text: '$elem\\n',")

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
