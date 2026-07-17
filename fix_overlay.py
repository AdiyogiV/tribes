import re

with open('lib/features/baba/presentation/baba_overlay.dart', 'r') as f:
    content = f.read()

# Fix unused import
content = content.replace("import 'package:aurogram/features/baba/presentation/baba_voice_controls.dart';", "")

# Fix unused method _showRecent
content = re.sub(r'  void _showRecent\(\) \{.*?\n  \}\n', '', content, flags=re.DOTALL)

with open('lib/features/baba/presentation/baba_overlay.dart', 'w') as f:
    f.write(content)
