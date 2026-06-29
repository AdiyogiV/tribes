import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# 1. Update the Vibe Header to explicitly mention the date
vibe_target = """        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
          child: Text(
            vibe.label,
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 32,
              fontWeight: FontWeight.w400,
              color: c,
            ),
          ),
        ),"""

vibe_replacement = """        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
          child: Column(
            children: [
              Text(
                (_isAtToday ? "TODAY'S FORECAST" : "${_formatDate(_displayedDate).toUpperCase()} FORECAST"),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w700,
                  color: c.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                vibe.label,
                style: TextStyle(
                  fontFamily: 'InstrumentSerif',
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                  color: c,
                ),
              ),
            ],
          ),
        ),"""
content = content.replace(vibe_target, vibe_replacement)

# 2. Add Date Hub to center of the wheel and DRAG instruction
stack_target = """                        // Markers — positioned in screen-space so icons stay upright
                        ..._buildMarkers(total, c, angle, isDark),
                      ],
                    );"""

stack_replacement = """                        // Markers — positioned in screen-space so icons stay upright
                        ..._buildMarkers(total, c, angle, isDark),

                        // Date Hub (Center)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isAtToday ? "TODAY" : "DATE",
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: c.withValues(alpha: 0.5),
                                ),
                              ),
                              Text(
                                _isAtToday ? _formatDate(DateTime.now()) : _formatDate(_displayedDate),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: c,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Drag Affordance
                        Positioned(
                          bottom: 24,
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
                        ),
                      ],
                    );"""

content = content.replace(stack_target, stack_replacement)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)
