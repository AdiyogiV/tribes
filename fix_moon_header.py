import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# 1. REMOVE "MOON IN X" FROM THE BOTTOM (Daily Vibe block)
vibe_target = r"""        children: \[
          // Dynamic Moon Header
          Text\(
            "MOON IN \$\{activeInfo\?\.name\.toUpperCase\(\) \?\? '\.\.\.'\}",
            style: TextStyle\(
              fontSize: 10,
              letterSpacing: 2\.0,
              fontWeight: FontWeight\.w700,
              color: c\.withValues\(alpha: 0\.8\),
            \),
          \),
          const SizedBox\(height: 4\),
          // Vibe label"""

vibe_replacement = r"""        children: [
          // Vibe label"""
content = re.sub(vibe_target, vibe_replacement, content, flags=re.DOTALL)


# 2. ADD "MOON IN X" TO THE TOP OF THE WHEEL CONTENT
# Find the padding that wraps the wheel
wheel_target = r"""    final wheelContent = Padding\(
      padding: const EdgeInsets\.only\(
        left: AppDimensions\.paddingMd,
        right: AppDimensions\.paddingMd,
        top: 100, // Massive sky room reserved for the large moon
        bottom: 16,
      \),
      child: wheel,
    \);"""

wheel_replacement = r"""    final wheelContent = Padding(
      padding: const EdgeInsets.only(
        left: AppDimensions.paddingMd,
        right: AppDimensions.paddingMd,
        top: 32, // Padding for the header
        bottom: 16,
      ),
      child: Column(
        children: [
          // Dynamic Moon Header (Moved to the very top)
          Text(
            "MOON IN ${_isAtToday ? 'TODAY' : _formatDate(_displayedDate).toUpperCase()}",
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w800,
              color: c.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 60), // The massive sky room reserved for the large moon
          wheel,
        ],
      ),
    );"""
content = re.sub(wheel_target, wheel_replacement, content, flags=re.DOTALL)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)

