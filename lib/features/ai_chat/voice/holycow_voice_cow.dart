import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class _HolyCowVoiceCowState extends State<HolyCowVoiceCow>
    with SingleTickerProviderStateMixin {
  final VoiceSessionController _voice = VoiceSessionController();
  late final AnimationController _pulse;

  /// User's first name, fetched once and cached so the spoken greeting can say
  /// it the instant the cow is tapped (no Firestore read on the tap path).
  String? _greetingName;

  /// Last error surfaced via SnackBar, so we don't spam the same one.
  String? _shownError;

  static const double _idleSize = 100.0;
  static const double _activeSize = 150.0;

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoiceChanged);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _loadGreetingName();
  }

  /// Resolve the user's first name once, cheapest source first: the Firebase
  /// Auth display name, falling back to the Firestore user doc. Cached so the
  /// greeting is truly instant on tap.
  Future<void> _loadGreetingName() async {
    String? full = FirebaseAuth.instance.currentUser?.displayName;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if ((full == null || full.trim().isEmpty) && uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final data = doc.data();
        full = (data?['name'] ?? data?['nickname']) as String?;
      } catch (_) {/* offline / denied: greet generically */}
    }
    final first = full?.trim().split(RegExp(r'\s+')).first;
    if (mounted && first != null && first.isNotEmpty) {
      setState(() => _greetingName = first);
    }
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
      await _voice.start(greetingName: _greetingName);
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

    return AnimatedBuilder(
      animation: Listenable.merge([_voice, _pulse]),
      builder: (context, _) {
        final state = _voice.state;
        final active = _inCall;
        final pulse = active ? _pulse.value : 0.0;
        final size = (active ? _activeSize : _idleSize) + (pulse * 14);
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

                // The cow itself — grows + glows when talking.
                GestureDetector(
                  onTap: _toggle,
                  onLongPress: active ? null : widget.onShowKeyboard,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    width: size,
                    height: size,
                    decoration: active
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (state == VoiceCallState.error
                                        ? Colors.redAccent
                                        : AppTheme.primaryColor)
                                    .withValues(alpha: 0.45),
                                blurRadius: 28 + (pulse * 24),
                                spreadRadius: 4 + (pulse * 8),
                              ),
                            ],
                          )
                        : null,
                    child: Image.asset(
                      'assets/images/cow1.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.auto_awesome,
                        color: AppTheme.primaryColor,
                        size: size * 0.5,
                      ),
                    ),
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
