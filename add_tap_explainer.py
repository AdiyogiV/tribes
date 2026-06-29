import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Add the Explainer bottom sheet function to TodaysBalanceCard
sheet_code = """
  void _showDoshaExplainer(BuildContext context, String dosha, Color fgMain, Color fgMuted, Color bg) {
    String title = '';
    String element = '';
    String function = '';
    String qualities = '';
    Color accent = _getDoshaColor(dosha);

    if (dosha == 'pitta') {
      title = 'Pitta';
      element = 'FIRE & WATER';
      function = 'METABOLISM & TRANSFORMATION';
      qualities = 'Hot, sharp, light, liquid, spreading. Governs digestion, absorption, assimilation, and body temperature. In balance, it brings intelligence and understanding. Out of balance, it brings anger and inflammation.';
    } else if (dosha == 'kapha') {
      title = 'Kapha';
      element = 'EARTH & WATER';
      function = 'STRUCTURE & LUBRICATION';
      qualities = 'Heavy, slow, cool, oily, smooth, dense. Governs structure, bones, joints, and fluid balance. In balance, it brings love, calmness, and forgiveness. Out of balance, it brings attachment, greed, and lethargy.';
    } else {
      title = 'Vata';
      element = 'AIR & ETHER';
      function = 'MOVEMENT & COMMUNICATION';
      qualities = 'Light, cold, dry, rough, subtle, mobile. Governs all movement in the mind and body, including blood flow, breathing, and nervous system. In balance, it promotes creativity and flexibility. Out of balance, it produces fear and anxiety.';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: fgMuted.withAlpha(50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 32,
                  fontStyle: FontStyle.italic,
                  color: accent,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                element,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                  color: fgMain.withAlpha(200),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                function,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                  color: fgMuted,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                qualities,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  height: 1.6,
                  color: fgMain.withAlpha(220),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
"""

content = re.sub(r"(Widget _buildTipSection)", sheet_code + r"\n  \1", content)

# 2. Wrap the AspectRatio with GestureDetector and Math logic
old_aspect_ratio = r"AspectRatio\(\n\s*aspectRatio: 1\.0,\n\s*child: CustomPaint\(\n\s*painter: _UnifiedTrifectaPainter\("
new_aspect_ratio = """GestureDetector(
          onTapUp: (details) {
            // Calculate angle from center to determine which dosha was tapped
            final RenderBox box = context.findRenderObject() as RenderBox;
            final center = Offset(box.size.width / 2, box.size.height / 2);
            final tap = details.localPosition;
            final dx = tap.dx - center.dx;
            final dy = tap.dy - center.dy;
            
            // Atan2 gives angle from -pi to pi (0 is right, pi/2 is bottom)
            double angle = math.atan2(dy, dx);
            if (angle < 0) angle += 2 * math.pi; // Normalize to 0 .. 2pi
            
            // Pitta is at top (-pi/2 or 1.5 pi)
            // Kapha is at bottom right (pi/6 or 0.52 rad)
            // Vata is at bottom left (5pi/6 or 2.61 rad)
            
            String tappedDosha = 'kapha';
            if (angle > 1.57 && angle < 3.66) {
              tappedDosha = 'vata';
            } else if (angle >= 3.66 || angle < 5.75) {
              // Wait, 1.5 pi = 4.71. So 3.66 to 5.75 is the top slice
              tappedDosha = 'pitta';
            }
            // Add haptic feedback
            HapticFeedback.lightImpact();
            _showDoshaExplainer(context, tappedDosha, fgMain, fgMuted, bg);
          },
          child: AspectRatio(
            aspectRatio: 1.0,
            child: CustomPaint(
              painter: _UnifiedTrifectaPainter("""

content = re.sub(old_aspect_ratio, new_aspect_ratio, content)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
