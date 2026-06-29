import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# 1. Update Vibe Header
content = re.sub(
    r'\(\s*_isAtToday\s*\?\s*"TODAY\'S FORECAST"\s*:\s*"\$\{\s*_formatDate\(_displayedDate\)\.toUpperCase\(\)\s*\}\s*FORECAST"\s*\)',
    r'"MOON IN ${NakshatraData.all[_activeIndex].name.toUpperCase()}"',
    content
)

# 2. Replace the Stack content more robustly
# Let's find the children of the Stack that returns the wheel visual
stack_pattern = r'(// 1\. Dimming Spotlight Gradient.*?)(// Markers — positioned in screen-space so icons stay upright)'
stack_replacement = r"""// 1. Horizon / Viewfinder Cover (Masks bottom half aggressively)
                        Positioned(
                          bottom: -total * 0.05,
                          child: Container(
                            width: total * 1.1,
                            height: total * 0.65,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  (isDark ? Theme.of(context).colorScheme.surface : Colors.white).withValues(alpha: 0.0),
                                  (isDark ? Theme.of(context).colorScheme.surface : Colors.white).withValues(alpha: 0.9),
                                  (isDark ? Theme.of(context).colorScheme.surface : Colors.white),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // 2. The Energy Conduit (Tether from Center to Moon)
                        Positioned(
                          top: 24,
                          child: Container(
                            width: 1.5,
                            height: (total / 2) - 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                        \2"""
content = re.sub(stack_pattern, stack_replacement, content, flags=re.DOTALL)

# Add Moon and change Drag text
# Find the end of Date Hub
hub_pattern = r'(// Drag Affordance\s*Positioned\(\s*bottom:\s*14,.*?"DRAG TO )EXPLORE TIME(".*?\),)'
hub_replacement = r"""// 4. The Moon (Fixed at 12 o'clock, the ultimate pointer)
                        Positioned(
                          top: -6,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [Colors.white, Color(0xFFE0E0E0), Color(0xFF909090)],
                                stops: [0.2, 0.8, 1.0],
                                center: Alignment(-0.3, -0.3),
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 12, spreadRadius: 2),
                                BoxShadow(color: c.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 8),
                              ],
                              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                            ),
                          ),
                        ),

                        \1MOVE THE SKY\2"""
content = re.sub(hub_pattern, hub_replacement, content, flags=re.DOTALL)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)

