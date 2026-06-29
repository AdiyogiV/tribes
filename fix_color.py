import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# Replace cardColor with the actual theme resolution that was in build()
content = content.replace('cardColor.withValues(alpha: 0.6)', '(isDark ? Theme.of(context).colorScheme.surface : Colors.white).withValues(alpha: 0.6)')
content = content.replace('cardColor.withValues(alpha: 0.95)', '(isDark ? Theme.of(context).colorScheme.surface : Colors.white).withValues(alpha: 0.95)')

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)
