import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# 1. Rewrite build() to fix layout structure completely
build_target = r"""  Widget build\(BuildContext context\) \{.*?    // Wheel \+ Daily Vibe share ONE Material card\..*?    \);
  \}"""

build_replacement = """  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF141416) : Colors.white;

    final vibeContent = _buildDailyVibeContent(c, isDark, cardColor);
    final wheel = _buildWheel(c, isDark);
    
    final activeInfo = NakshatraData.getInfo(_activeIndex);

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── HEADER: Context ──
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Text(
              "MOON IN ${activeInfo?.name.toUpperCase() ?? '...'}",
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 3.0,
                fontWeight: FontWeight.w800,
                color: c.withValues(alpha: 0.5),
              ),
            ),
          ),
          
          // ── WHEEL AREA: Padded properly so Moon fits ──
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMd,
            ),
            child: wheel,
          ),
          
          // ── VIBE CONTENT ──
          vibeContent,
        ],
      ),
    );
  }"""

content = re.sub(build_target, build_replacement, content, flags=re.DOTALL)


# 2. Rewrite _buildWheel layout
wheel_target = r"""        // 1\. Smooth Dimming Spotlight Gradient \(Clean, continuous fade\).*?// Drag Affordance.*?\]\s*\)\s*\]\s*\);"""

wheel_replacement = """        // 1. Smooth Dimming Spotlight Gradient (Clean, continuous fade)
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
                                (isDark ? Theme.of(context).colorScheme.surface : Colors.white).withValues(alpha: 1.0),
                              ],
                              stops: const [0.2, 0.7, 1.0],
                            ),
                          ),
                        ),

                        // 2. The Energy Conduit (Tether from Center to Moon)
                        Positioned(
                          top: -10, // Adjusted to match new moon space
                          child: Container(
                            width: 1.5,
                            height: (total / 2) - 20,
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
                        ..._buildMarkers(imgDia, total, isDark),

                        // Drag Affordance
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
                        
                        // 4. The Moon Phase (Fixed at 12 o'clock, showing dynamic phase)
                        Positioned(
                          top: -60, // Adjusted relative to new padded box
                          child: Text(
                            VedicTimeUtils.getMoonPhaseEmoji(_displayedDate),
                            style: const TextStyle(
                              fontSize: 52, // Large Chic Moon
                            ),
                          ),
                        ),
                        
                        // Date Hub
                        Positioned(
                          child: InkWell(
                            onTap: () {
                              _resetToToday();
                              widget.onResetToToday?.call();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0xFF141416) : Colors.white,
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _isAtToday ? 'TODAY' : _formatDate(_displayedDate).toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: _isAtToday ? (isDark ? Colors.white : Colors.black) : c.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]
                    );"""

content = re.sub(wheel_target, wheel_replacement, content, flags=re.DOTALL)

# 3. Increase padding on AnimatedScale so the Moon fits inside the wheel's allocated bounds
# In `_buildWheel`, find the `AnimatedScale` child which is `SizedBox(width: total, height: total...`
scale_target = r"""              child: SizedBox\(
                width: total,
                height: total,
                child: AnimatedBuilder\("""

scale_replacement = """              child: Padding(
                padding: const EdgeInsets.only(top: 60), // Space dedicated for Moon
                child: SizedBox(
                  width: total,
                  height: total,
                  child: AnimatedBuilder("""

content = re.sub(scale_target, scale_replacement, content)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)

