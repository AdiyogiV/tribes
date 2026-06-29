import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# Add import for VedicTimeUtils
if 'import \'package:aurogram/features/astrology/presentation/widgets/cards/vedic_time_utils.dart\';' not in content:
    content = content.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:aurogram/features/astrology/presentation/widgets/cards/vedic_time_utils.dart';"
    )

# Replace the moon container with the emoji moon and adjust position
moon_pattern = r'// 4\. The Moon \(Fixed at 12 o\'clock.*?Positioned\(\s*top: -6,\s*child: Container\(\s*width: 24,\s*height: 24,\s*decoration: BoxDecoration\(\s*shape: BoxShape\.circle.*?border: Border\.all\(color: Colors\.white\.withValues\(alpha: 0\.5\), width: 1\),\s*\),\s*\),\s*\),'
moon_replacement = r"""// 4. The Moon Phase (Fixed at 12 o'clock, showing dynamic phase)
                        Positioned(
                          top: -16, // Moved up to float nicely at the apex
                          child: Text(
                            VedicTimeUtils.getMoonPhaseEmoji(_displayedDate),
                            style: TextStyle(
                              fontSize: 28,
                              shadows: [
                                Shadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 16),
                                Shadow(color: c.withValues(alpha: 0.4), blurRadius: 24),
                              ],
                            ),
                          ),
                        ),"""

content = re.sub(moon_pattern, moon_replacement, content, flags=re.DOTALL)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)

