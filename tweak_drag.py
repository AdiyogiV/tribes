with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

target = """                        // Drag Affordance
                        Positioned(
                          bottom: 6,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chevron_left, size: 14, color: c.withValues(alpha: 0.5)),
                              const SizedBox(width: 8),
                              Text(
                                "DRAG TO EXPLORE TIME",
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 2.0,
                                  fontWeight: FontWeight.bold,
                                  color: c.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, size: 14, color: c.withValues(alpha: 0.5)),
                            ],
                          ),
                        ),"""

replacement = """                        // Drag Affordance
                        Positioned(
                          bottom: 14,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chevron_left, size: 12, color: c.withValues(alpha: 0.9)),
                              const SizedBox(width: 6),
                              Text(
                                "DRAG TO EXPLORE TIME",
                                style: TextStyle(
                                  fontSize: 8,
                                  letterSpacing: 2.0,
                                  fontWeight: FontWeight.bold,
                                  color: c.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.chevron_right, size: 12, color: c.withValues(alpha: 0.9)),
                            ],
                          ),
                        ),"""

content = content.replace(target, replacement)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)
