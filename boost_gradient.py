import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

target = r"""// 1\. Dimming Spotlight Gradient \(Darkens the bottom\)\s*Container\(\s*width: total,\s*height: total,\s*decoration: BoxDecoration\(\s*shape: BoxShape\.circle,\s*gradient: LinearGradient\(\s*begin: Alignment\.topCenter,\s*end: Alignment\.bottomCenter,\s*colors: \[\s*Colors\.transparent,\s*\(isDark \? Theme\.of\(context\)\.colorScheme\.surface : Colors\.white\)\.withValues\(alpha: 0\.6\),\s*\(isDark \? Theme\.of\(context\)\.colorScheme\.surface : Colors\.white\)\.withValues\(alpha: 0\.95\),\s*\],\s*stops: const \[0\.2, 0\.6, 1\.0\],\s*\),\s*\),\s*\),"""

replacement = r"""// 1. Strong Dimming Spotlight Gradient (Aggressively darkens the bottom half)
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
                                (isDark ? Theme.of(context).colorScheme.surface : Colors.white).withValues(alpha: 0.7),
                                (isDark ? Theme.of(context).colorScheme.surface : Colors.white).withValues(alpha: 1.0),
                                (isDark ? Theme.of(context).colorScheme.surface : Colors.white),
                              ],
                              stops: const [0.15, 0.5, 0.8, 1.0],
                            ),
                          ),
                        ),"""

content = re.sub(target, replacement, content, flags=re.DOTALL)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)
