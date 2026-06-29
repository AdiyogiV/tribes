import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# 1. Update Vibe Label
content = re.sub(
    r'Text\(\s*vibe\.label,\s*style:\s*TextStyle\(\s*fontSize:\s*AppTheme\.holyCowTextSize\s*\+\s*4,\s*fontWeight:\s*FontWeight\.w700,\s*color:\s*c,\s*\),\s*\),',
    r'''Text(
            vibe.label,
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 32,
              fontWeight: FontWeight.w400,
              color: c,
            ),
          ),''',
    content
)

# 2. Update Subtitle
content = re.sub(
    r'Text\(\s*subtitle,\s*style:\s*TextStyle\(\s*fontSize:\s*AppTheme\.holyCowTextSize\s*-\s*1,\s*fontWeight:\s*FontWeight\.w500,\s*color:\s*c\.withValues\(alpha:\s*0\.5\),\s*\),\s*\),',
    r'''Text(
            subtitle.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
              color: c.withValues(alpha: 0.5),
            ),
          ),''',
    content
)

# 3. Add Spotlight and Lens
old_stack = '''                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Rotating layer (image + tara ring)
                        Transform.rotate(angle: angle, child: child),
                        // Markers — positioned in screen-space so icons stay upright
                        ..._buildMarkers(total, c, angle, isDark),
                      ],
                    );'''

new_stack = '''                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Rotating layer (image + tara ring)
                        Transform.rotate(angle: angle, child: child),
                        
                        // 1. Dimming Spotlight Gradient
                        Container(
                          width: total,
                          height: total,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                cardColor.withValues(alpha: 0.6),
                                cardColor.withValues(alpha: 0.95),
                              ],
                              stops: const [0.2, 0.6, 1.0],
                            ),
                          ),
                        ),

                        // 2. The 12 O'Clock Lens Bracket
                        Positioned(
                          top: 2,
                          child: Container(
                            width: 60,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                              boxShadow: [
                                BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 10),
                              ],
                            ),
                          ),
                        ),

                        // Markers — positioned in screen-space so icons stay upright
                        ..._buildMarkers(total, c, angle, isDark),
                      ],
                    );'''

content = content.replace(old_stack, new_stack)

# 4. Thin the Tara Ring
# Look for strokeWidth assignment in _TaraRingPainter
content = re.sub(
    r'paint\.strokeWidth\s*=\s*.*?_selectedRingWidth.*?;|paint\.strokeWidth\s*=\s*\d+\.\d+;',
    r'paint.strokeWidth = 3.0; // Thin glowing arc',
    content
)

# Optional: if strokeWidth wasn't matched explicitly, let's find the class _TaraRingPainter and just replace the paint setup
content = re.sub(
    r'(final\s+paint\s*=\s*Paint\(\)\s*\.\.\s*style\s*=\s*PaintingStyle\.stroke)\s*\.\.\s*strokeWidth\s*=\s*[^;]+;',
    r'\1..strokeWidth = 3.0;',
    content
)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)

