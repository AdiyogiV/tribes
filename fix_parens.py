import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

target = r"""                        // Drag Affordance
                        Positioned\(
                          bottom: 14,
                          child: IgnorePointer\(
                            child: AnimatedOpacity\(
                              duration: const Duration\(milliseconds: 200\),
                              opacity: _isMagnified \? 0\.0 : 1\.0,
                              child: Row\(
                                mainAxisSize: MainAxisSize\.min,
                                children: \[
                                  Icon\(Icons\.chevron_left, size: 12, color: c\.withValues\(alpha: 0\.9\)\),
                                  const SizedBox\(width: 6\),
                                  Text\(
                                    "DRAG TO MOVE THE SKY",
                                    style: TextStyle\(
                                      fontSize: 8,
                                      letterSpacing: 2\.0,
                                      fontWeight: FontWeight\.bold,
                                      color: c\.withValues\(alpha: 0\.9\),
                                    \),
                                  \),
                                  const SizedBox\(width: 6\),
                                  Icon\(Icons\.chevron_right, size: 12, color: c\.withValues\(alpha: 0\.9\)\),
                                \],
                              \),
                            \),
                          \),
                        \),
                      \],
                    \);"""

replacement = r"""                        // Drag Affordance
                        Positioned(
                          bottom: 14,
                          child: IgnorePointer(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isMagnified ? 0.0 : 1.0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chevron_left, size: 12, color: c.withValues(alpha: 0.9)),
                                  const SizedBox(width: 6),
                                  Text(
                                    "DRAG TO MOVE THE SKY",
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
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );"""

content = re.sub(target, replacement, content, flags=re.DOTALL)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)

