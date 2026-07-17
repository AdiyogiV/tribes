import re

with open('lib/features/baba/presentation/baba_overlay.dart', 'r') as f:
    content = f.read()

# Fix unused imports
content = content.replace("import 'package:aurogram/core/routing/app_router.dart';", "")
content = content.replace("import 'package:aurogram/core/routing/route_names.dart';", "")
content = content.replace("import 'package:aurogram/features/baba/presentation/baba_voice_controls.dart';", "")

new_build_call_presence = """
  /// The minimal floating bar UI for the active call.
  Widget _buildCallPresence(BuildContext context, bool isDark) {
    final state = _voice.state;
    final pulse = _pulse.value;
    
    String statusText = 'Processing...';
    if (state == VoiceCallState.listening) {
      statusText = 'Listening...';
    } else if (state == VoiceCallState.speaking) {
      statusText = 'Speaking...';
    } else if (state == VoiceCallState.thinking) {
      statusText = 'Thinking...';
    } else if (state == VoiceCallState.connecting) {
      statusText = 'Connecting...';
    }

    // Show the active transcript. If speaking, show his reply. Else show what user is saying.
    String activeText = '';
    if (state == VoiceCallState.speaking && _voice.aryabhattReply.isNotEmpty) {
      activeText = _voice.aryabhattReply;
    } else if (_voice.userTranscript.isNotEmpty) {
      activeText = _voice.userTranscript;
    }

    return AnimatedAlign(
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      child: AnimatedPadding(
        padding: EdgeInsets.only(bottom: 12 + _safeBottom + _barInset),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: Mini Avatar
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: BabaBlob(size: 52, active: true, pulse: pulse, isDark: isDark),
                    ),
                    const SizedBox(width: 12),
                    
                    // Center: Transcript / Status
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusText.toUpperCase(),
                            style: TextStyle(
                              color: isDark ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (activeText.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              activeText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 13,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Right: Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state == VoiceCallState.speaking)
                          _buildMiniActionButton(Icons.mic_rounded, _voice.interruptAndListen, isDark),
                        const SizedBox(width: 6),
                        _buildMiniActionButton(Icons.keyboard_rounded, _openChat, isDark),
                        const SizedBox(width: 6),
                        _buildMiniActionButton(Icons.close_rounded, _voice.hangUp, isDark, tint: Colors.redAccent),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniActionButton(IconData icon, VoidCallback onTap, bool isDark, {Color? tint}) {
    final color = tint ?? (isDark ? Colors.white70 : Colors.black54);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
"""

content = re.sub(r'  /// The centred, full call UI.*?Widget _buildCallPresence\(BuildContext context, bool isDark\) \{.*?Widget _buildIdlePresence', new_build_call_presence + '\n  /// The idle blob — draggable ANYWHERE.\n  Widget _buildIdlePresence', content, flags=re.DOTALL)

# Delete old _buildCaption
content = re.sub(r'  Widget _buildCaption\(String reply.*?\}\n', '', content, flags=re.DOTALL)

# Let's delete the `_activeSize` unused var as well
content = re.sub(r'  static const double _activeSize = 96\.0;\n', '', content)

with open('lib/features/baba/presentation/baba_overlay.dart', 'w') as f:
    f.write(content)
