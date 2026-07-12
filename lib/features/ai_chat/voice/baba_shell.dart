import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/ai_chat/voice/baba_presence.dart';
import 'package:aurogram/features/ai_chat/voice/voice_session_controller.dart';

/// The app-wide Baba presence.
///
/// Wraps the whole app (mounted in `app_root`'s MaterialApp builder) so Baba
/// floats OVER every route and survives navigation — the first rung of the
/// "app wrapped in Baba" shell. He shares the one [VoiceSessionController]
/// singleton, so a call started anywhere keeps going as you move around.
///
/// Rung 1 scope (deliberately small):
///   * a global, tappable orb (tap = start/stop a voice call),
///   * dismiss him (×) → collapses to a summon dot; tap the dot to bring back,
///   * hides itself while the dashboard cow is on-screen (no double-Baba).
/// Actions / guiding / tool-calls come in later rungs.
class BabaShell extends StatefulWidget {
  const BabaShell({super.key, required this.child});

  final Widget child;

  @override
  State<BabaShell> createState() => _BabaShellState();
}

class _BabaShellState extends State<BabaShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final VoiceSessionController _voice = VoiceSessionController();
  final BabaPresence _presence = BabaPresence.instance;
  late final AnimationController _pulse;
  String? _shownError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _voice.addListener(_onVoiceChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voice.removeListener(_onVoiceChanged);
    _pulse.dispose();
    // NOTE: never dispose _voice — it's the app-scoped singleton.
    super.dispose();
  }

  /// End the call if the app is backgrounded — never leave a live mic running.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    super.didChangeAppLifecycleState(lifecycle);
    if (lifecycle != AppLifecycleState.resumed && _inCall) {
      _voice.hangUp();
    }
  }

  bool get _inCall =>
      _voice.state == VoiceCallState.connecting ||
      _voice.state == VoiceCallState.listening ||
      _voice.state == VoiceCallState.thinking ||
      _voice.state == VoiceCallState.speaking;

  void _onVoiceChanged() {
    if (!mounted) return;
    if (_voice.state == VoiceCallState.error) {
      final msg = _voice.errorMessage ?? 'Could not reach Baba';
      if (msg != _shownError) {
        _shownError = msg;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ));
      }
    } else {
      _shownError = null;
    }
  }

  Future<void> _toggleCall() async {
    HapticFeedback.mediumImpact();
    if (_inCall) {
      await _voice.hangUp();
    } else {
      await _voice.start();
    }
  }

  Color _stateColor(VoiceCallState state) {
    switch (state) {
      case VoiceCallState.listening:
        return const Color(0xFFFF5722);
      case VoiceCallState.thinking:
        return const Color(0xFF5C6BC0);
      case VoiceCallState.speaking:
        return AppTheme.primaryColor;
      case VoiceCallState.connecting:
        return const Color(0xFFFFB300);
      case VoiceCallState.error:
        return const Color(0xFFE53935);
      case VoiceCallState.idle:
      case VoiceCallState.ended:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        widget.child,
        // Baba floats above every route. Bound to both the presence coordinator
        // and the voice session so he reflects live call state everywhere.
        AnimatedBuilder(
          animation: Listenable.merge([_presence, _voice, _pulse]),
          builder: (context, _) {
            if (_presence.dashboardActive) {
              return const SizedBox.shrink(); // dashboard cow is on stage
            }
            return Positioned(
              right: 16,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              child: _presence.dismissed
                  ? _buildSummonDot(isDark)
                  : _buildOrb(isDark),
            );
          },
        ),
      ],
    );
  }

  /// Collapsed state after the user crosses Baba off.
  Widget _buildSummonDot(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _presence.summon();
      },
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
            ),
            child: Opacity(
              opacity: 0.6,
              child: Image.asset(
                'assets/images/aryabhatt.png',
                width: 26,
                height: 26,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.auto_awesome, size: 18, color: AppTheme.primaryColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Full presence: live caption + orb + dismiss affordance.
  Widget _buildOrb(bool isDark) {
    final state = _voice.state;
    final pulse = _pulse.value;
    final ring = _stateColor(state);
    final reply = _voice.aryabhattReply;
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Live caption of what Baba is saying.
        if (_inCall && reply.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(maxWidth: screenWidth * 0.7),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    reply,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topLeft,
          children: [
            // The orb.
            GestureDetector(
              onTap: _toggleCall,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      border: _inCall
                          ? Border.all(
                              color: ring.withValues(
                                  alpha: 0.4 + 0.4 * math.sin(pulse * math.pi).abs()),
                              width: 2,
                            )
                          : null,
                    ),
                    child: Image.asset(
                      'assets/images/aryabhatt.png',
                      width: 46,
                      height: 46,
                      errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome,
                          size: 28, color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ),
            ),
            // Dismiss (cross him off) — only when idle, so we never nuke a live call by accident.
            if (!_inCall)
              Positioned(
                top: -4,
                left: -4,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _presence.dismiss();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.5),
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 13,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
