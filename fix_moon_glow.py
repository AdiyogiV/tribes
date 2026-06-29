import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# Replace the moon widget to remove the shadow and move it up
moon_pattern = r'// 4\. The Moon Phase \(Fixed at 12 o\'clock, showing dynamic phase\)\s*Positioned\(\s*top: -16, // Moved up to float nicely at the apex\s*child: Text\(\s*VedicTimeUtils\.getMoonPhaseEmoji\(_displayedDate\),\s*style: TextStyle\(\s*fontSize: 28,\s*shadows: \[\s*Shadow\(color: Colors\.white\.withValues\(alpha: 0\.6\), blurRadius: 16\),\s*Shadow\(color: c\.withValues\(alpha: 0\.4\), blurRadius: 24\),\s*\],\s*\),\s*\),\s*\),'

moon_replacement = r"""// 4. The Moon Phase (Fixed at 12 o'clock, showing dynamic phase)
                        Positioned(
                          top: -32, // Moved further up
                          child: Text(
                            VedicTimeUtils.getMoonPhaseEmoji(_displayedDate),
                            style: const TextStyle(
                              fontSize: 28,
                              // Shadows removed to eliminate the glow
                            ),
                          ),
                        ),"""

content = re.sub(moon_pattern, moon_replacement, content, flags=re.DOTALL)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)

