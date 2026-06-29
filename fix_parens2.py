import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

target = r"""                  \),
                \),
              \),
            \),
          \),
        \);"""

replacement = r"""                  ),
                ),
              ),
            ),
          ),
        ),
      );"""

content = re.sub(target, replacement, content)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)
