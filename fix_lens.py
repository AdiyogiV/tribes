with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

target = """                        // 2. The 12 O'Clock Lens Bracket
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
                        ),"""

replacement = """                        // 2. The 12 O'Clock Pointer (Highly visible)
                        Positioned(
                          top: -8,
                          child: Column(
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: c, // Primary theme color
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [BoxShadow(color: c.withValues(alpha: 0.8), blurRadius: 8)],
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                color: c,
                                size: 36,
                                shadows: [Shadow(color: c.withValues(alpha: 0.8), blurRadius: 8)],
                              ),
                            ],
                          ),
                        ),"""

content = content.replace(target, replacement)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)
