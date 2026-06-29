import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

target = r'// 2\. The Energy Conduit'

replacement = r"""// 1. Dimming Spotlight Gradient (Darkens the bottom)
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
                                (isDark ? Theme.of(context).colorScheme.surface : Colors.white).withValues(alpha: 0.6),
                                (isDark ? Theme.of(context).colorScheme.surface : Colors.white).withValues(alpha: 0.95),
                              ],
                              stops: const [0.2, 0.6, 1.0],
                            ),
                          ),
                        ),

                        // 2. The Energy Conduit"""

content = re.sub(target, replacement, content, count=1)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)
