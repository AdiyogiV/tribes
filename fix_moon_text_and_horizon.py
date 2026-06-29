import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# 1. ADD THE "MOON IN X" TEXT ABOVE VIBE LABEL
# Look for where vibe.label is displayed
vibe_target = """        children: [
          // Vibe label
          Text(
            vibe.label,
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 32,
              fontWeight: FontWeight.w400,
              color: c,
            ),
          ),"""

vibe_replacement = """        children: [
          // Dynamic Moon Header
          Text(
            "MOON IN ${activeInfo?.name.toUpperCase() ?? '...'}",
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w700,
              color: c.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          // Vibe label
          Text(
            vibe.label,
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 32,
              fontWeight: FontWeight.w400,
              color: c,
            ),
          ),"""
content = content.replace(vibe_target, vibe_replacement)

# 2. REMOVE THE HORIZON GLASS
# Find the exact block we added for the horizon cover
horizon_pattern = r'// 1\. Horizon / Viewfinder Cover \(Masks bottom half aggressively\).*?// 2\. The Energy Conduit'

# Replace it with just the energy conduit comment to strip out the horizon block entirely
horizon_replacement = r'// 2. The Energy Conduit'

content = re.sub(horizon_pattern, horizon_replacement, content, flags=re.DOTALL)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)

