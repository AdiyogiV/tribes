import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# --- 1. Update the Vibe Header to the "Moon in X" paradigm ---
vibe_target = """              Text(
                (_isAtToday ? "TODAY'S FORECAST" : "${_formatDate(_displayedDate).toUpperCase()} FORECAST"),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w700,
                  color: c.withValues(alpha: 0.8),
                ),
              ),"""

vibe_replacement = """              Text(
                "MOON IN ${NakshatraData.all[_activeIndex].name.toUpperCase()}",
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w700,
                  color: c.withValues(alpha: 0.8),
                ),
              ),"""
content = content.replace(vibe_target, vibe_replacement)

# --- 2. Implement the Horizon, the Moon, and the Conduit ---
stack_target = """                        // 1. Dimming Spotlight Gradient
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

                        // Markers — positioned in screen-space so icons stay upright
                        ..._buildMarkers(total, c, angle, isDark),

                        // Date Hub (Center)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isAtToday ? "TODAY" : "DATE",
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: c.withValues(alpha: 0.5),
                                ),
                              ),
                              Text(
                                _isAtToday ? _formatDate(DateTime.now()) : _formatDate(_displayedDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: c,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Drag Affordance
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

stack_replacement = """                        // 1. Horizon / Viewfinder Cover (Masks bottom half aggressively)
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

                        // Markers — positioned in screen-space so icons stay upright
                        ..._buildMarkers(total, c, angle, isDark),

                        // 3. Date Hub (Center)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isAtToday ? "TODAY" : "DATE",
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: c.withValues(alpha: 0.5),
                                ),
                              ),
                              Text(
                                _isAtToday ? _formatDate(DateTime.now()) : _formatDate(_displayedDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: c,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 4. The Moon (Fixed at 12 o'clock, the ultimate pointer)
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

                        // 5. Drag Affordance
                        Positioned(
                          bottom: 14,
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
                        ),"""

content = content.replace(stack_target, stack_replacement)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)

