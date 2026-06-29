with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

target = """                        // Date Hub (Center)
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
                          child: Row("""

replacement = """                        // Date Hub (Center)
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
                          bottom: 6,
                          child: Row("""

content = content.replace(target, replacement)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)
