import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/app/tabs/widgets/tab_bottom_nav.dart';
import 'package:aurogram/features/ai_chat/voice/voice_session_controller.dart';

/// The HolyCow cow icon, but alive.
///
/// Idle: a small cow parked above the profile tab (same spot as before).
/// Tap it: it grows, glows, and Aryabhatt starts talking — a live voice call
/// right here on the tab, no new page. Tap again to hang up.
/// Long-press: opens the text input bar (so typing still works).
class HolyCowVoiceCow extends StatefulWidget {
  const HolyCowVoiceCow({super.key, required this.onShowKeyboard});

  /// Long-press escape hatch back to the typed input bar.
  final VoidCallback onShowKeyboard;

  @override
  State<HolyCowVoiceCow> createState() => _HolyCowVoiceCowState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Wavy Clipper
// ─────────────────────────────────────────────────────────────────────────────
class WavyCircleClipper extends CustomClipper<Path> {
  final double pulse;

  WavyCircleClipper(this.pulse);

  @override
  Path getClip(Size size) {
    final Path path = Path();
    final double center = size.width / 2;
    final double radius = size.width / 2;
    
    // Idle state has a very subtle organic wobble. 
    // Active state amplifies the wobble based on the pulse.
    final double waveIntensity = 0.03 + (pulse * 0.05);

    const int samples = 120;
    for (int i = 0; i <= samples; i++) {
      final double t = (i / samples) * 2 * math.pi;
      
      // Organic sine/cosine math for a smooth blob shape
      final double wobble = math.sin(t * 4 + (pulse * math.pi * 2)) * (radius * waveIntensity) + 
                            math.cos(t * 7 - (pulse * math.pi)) * (radius * waveIntensity * 0.6);
                            
      final double r = radius + wobble;
      final double x = center + r * math.cos(t);
      final double y = center + r * math.sin(t);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WavyCircleClipper oldClipper) {
    return oldClipper.pulse != pulse;
  }
}


class _HolyCowVoiceCowState extends State<HolyCowVoiceCow>
    with SingleTickerProviderStateMixin {
  final VoiceSessionController _voice = VoiceSessionController();
  late final AnimationController _pulse;

  /// Last error surfaced via SnackBar, so we don't spam the same one.
  String? _shownError;

  static const double _idleSize = 70.0;
  static const double _activeSize = 110.0;

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoiceChanged);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoiceChanged);
    _pulse.dispose();
    _voice.dispose();
    super.dispose();
  }

  /// Surface call failures loudly instead of just shrinking the cow.
  void _onVoiceChanged() {
    if (_voice.state == VoiceCallState.error) {
      final msg = _voice.errorMessage ?? 'Could not reach Aryabhatt';
      if (msg != _shownError && mounted) {
        _shownError = msg;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.redAccent.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
      }
    } else {
      // Reset once we're out of the error state so the next failure shows.
      _shownError = null;
    }
  }

  /// True only while a call is genuinely live (connecting through speaking).
  /// idle / ended / error all count as "not in a call" so a single tap
  /// (re)starts, while a tap during a live call ends it.
  bool get _inCall =>
      _voice.state == VoiceCallState.connecting ||
      _voice.state == VoiceCallState.listening ||
      _voice.state == VoiceCallState.thinking ||
      _voice.state == VoiceCallState.speaking;

  Future<void> _toggle() async {
    HapticFeedback.mediumImpact();
    if (_inCall) {
      await _voice.hangUp(); // tap again -> end the call
    } else {
      await _voice.start();
    }
  }

  String _statusText(VoiceCallState s) {
    switch (s) {
      case VoiceCallState.connecting:
        return 'connecting...';
      case VoiceCallState.listening:
        return 'listening';
      case VoiceCallState.thinking:
        return 'thinking...';
      case VoiceCallState.speaking:
        return 'speaking';
      case VoiceCallState.error:
        return _voice.errorMessage ?? 'tap to retry';
      case VoiceCallState.idle:
      case VoiceCallState.ended:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tabCenterFromRight = TabBottomNav.itemCenterFromRight(screenWidth, 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([_voice, _pulse]),
      builder: (context, _) {
        final state = _voice.state;
        final active = _inCall;
        final pulse = active ? _pulse.value : 0.0;
        final size = active ? _activeSize : _idleSize;
        final reply = _voice.aryabhattReply;

        return Align(
          alignment: active ? Alignment.bottomCenter : Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              right: active ? 0 : tabCenterFromRight - _idleSize / 2,
              bottom: 10,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live caption of what Aryabhatt is saying.
                if (active && reply.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    constraints: BoxConstraints(maxWidth: screenWidth * 0.8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      reply,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                // The icon itself — chic, translucent glass.
                GestureDetector(
                  onTap: _toggle,
                  onLongPress: active ? null : widget.onShowKeyboard,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (active)
                        Transform.scale(
                          scale: 1.0 + (pulse * 0.4),
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (state == VoiceCallState.error ? Colors.redAccent : AppTheme.primaryColor)
                                    .withValues(alpha: (1.0 - pulse).clamp(0.0, 1.0) * 0.5),
                                width: 1.0,
                              ),
                            ),
                          ),
                        ),
                      // Wavy clipped glass container
                      ClipPath(
                        clipper: WavyCircleClipper(active ? pulse : 0.0),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.white.withValues(alpha: 0.03) 
                                  : Colors.black.withValues(alpha: 0.02),
                            ),
                            child: Transform.translate(
                              offset: const Offset(0, 6), // Move slightly down inside the circle
                              child: Transform.scale(
                                scale: 1.15, // Zoom slightly to kill any built-in PNG padding
                                child: Image.asset(
                                  'assets/images/cow1.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.auto_awesome,
                                    color: AppTheme.primaryColor,
                                    size: size * 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Status line while in a call (or to show why a call failed).
                if (active || state == VoiceCallState.error)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _statusText(state),
                      style: TextStyle(
                        color: (state == VoiceCallState.error
                                ? Colors.redAccent
                                : AppTheme.primaryColor)
                            .withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
