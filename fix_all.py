import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Fix the card background. Let's find the build method container.
# It currently has: color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
content = content.replace(
    "return Container(\n      width: double.infinity,\n      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),",
    "return Container(\n      width: double.infinity,\n      color: isDark ? Colors.black : Colors.white,"
)

# 2. Fix the bottom sheet background.
# The bottom sheet container has: color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
# Oh wait, wait. The first replacement will only replace the one in build if it matches exactly. Let's be careful.
