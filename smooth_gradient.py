import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

target = r"""// 1\. Strong Dimming Spotlight Gradient.*?stops: const \[0\.15, 0\.5, 0\.8, 1\.0\],\s*\),\s*\),\s*\),"""

replacement = r"""// 1. Smooth Dimming Spotlight Gradient (Clean, continuous fade)
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
                                (isDark ? Theme.of(context).colorScheme.surface : Colors.white).withValues(alpha: 0.75),
                                (isDark ? Theme.of(context).colorScheme.surface : Colors.white).withValues(alpha: 0.98),
                              ],
                              stops: const [0.2, 0.7, 1.0],
                            ),
                          ),
                        ),"""

content = re.sub(target, replacement, content, flags=re.DOTALL)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)
