with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Reduce percentage font size from 24 to 18
old_font = """fontSize: 24,
            color: Colors.white,"""
new_font = """fontSize: 18,
            color: Colors.white,"""
content = content.replace(old_font, new_font)

# 2. Move circles inward by exactly 5 logical pixels
old_anchor = """    // Calculate anchors moved slightly INSIDE by multiplying radius by 0.65 (was 1.0)
    Offset anchor(double angle, int val) {
      final r = unitR(val) * 0.65;
      return map(Offset(r * math.cos(angle), r * math.sin(angle)));
    }"""

new_anchor = """    // Calculate anchors moved slightly INSIDE by multiplying radius by 0.65, plus an extra 5 points inward
    Offset anchor(double angle, int val) {
      final r = math.max(0.0, (unitR(val) * 0.65) - (5.0 / scale));
      return map(Offset(r * math.cos(angle), r * math.sin(angle)));
    }"""
content = content.replace(old_anchor, new_anchor)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
