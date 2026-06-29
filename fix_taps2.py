import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Fix the card background:
content = content.replace("color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),",
                          "color: bg,")

# The card's color in build is defined as:
#     final bg = isDark ? Colors.black : Colors.white;
# So using color: bg, will make it black/white. Let's make sure it replaces the right one.
# Wait, the bottom sheet also uses this string. Let me replace them carefully.

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Replace all occurrences of this grey background. The first one is the card container.
content = content.replace("color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),", "color: bg,", 1)

# Now fix the gesture detector:
old_gesture = r"""        GestureDetector\(
          onTapUp: \(details\) \{
            // Find center of the widget
            final RenderBox box = context\.findRenderObject\(\) as RenderBox;
            final center = Offset\(box\.size\.width / 2, box\.size\.height / 2\);
            final dx = details\.localPosition\.dx - center\.dx;
            final dy = details\.localPosition\.dy - center\.dy;"""

new_gesture = """        Builder(
          builder: (builderContext) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final RenderBox box = builderContext.findRenderObject() as RenderBox;
              final center = Offset(box.size.width / 2, box.size.height / 2);
              final dx = details.localPosition.dx - center.dx;
              final dy = details.localPosition.dy - center.dy;"""

content = re.sub(old_gesture, new_gesture, content)

# I also need to close the Builder at the bottom.
content = content.replace("          ),\n        ),\n        const SizedBox(height: 48),", "          ),\n        ),\n        ),\n        const SizedBox(height: 48),")

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
