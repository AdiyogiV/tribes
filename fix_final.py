import re
with open('lib/features/baba/presentation/baba_overlay.dart', 'r') as f:
    c = f.read()
c = c.replace("import 'package:flutter/services.dart';", "import 'package:flutter/services.dart';\nimport 'package:aurogram/core/theme/app_theme.dart';")
c = re.sub(r'  static const double _activeSize = 140\.0;\n', '', c)
c = re.sub(r'  static const double _activeSize = 96\.0;\n', '', c)
with open('lib/features/baba/presentation/baba_overlay.dart', 'w') as f:
    f.write(c)
