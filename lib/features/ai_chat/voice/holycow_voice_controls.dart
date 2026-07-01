import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/ai_chat/voice/voice_session_controller.dart';

/// The floating "call console" shown beneath the cow while a voice call is
/// live. Pure presentational: it takes the current [state] plus a callback per
/// action and renders a row of frosted-glass circular buttons that match the
/// cow's glass aesthetic. All voice logic stays in the controller / cow.
///
/// Buttons (left → right):
///   * history   → open recent Aryabhatt chats
///   * my turn   → interrupt Aryabhatt + reopen the mic (only while speaking)
///   * keyboard  → drop the call and switch to the typed input bar
///   * end       → hang up (destructive, faint red tint)
class HolyCowVoiceControls extends StatefulWidget {
  const HolyCowVoiceControls({
    super.key,
    required this.state,
    required this.onEndCall,
    required this.onSwitchToText,
    required this.onShowRecent,
    required this.onInterrupt,
  });

  /// Current call state — drives which contextual buttons appear.
  final VoiceCallState state;

  /// Hang up the live call.
  final VoidCallback onEndCall;

  /// End the call and open the typed input bar.
  final VoidCallback onSwitchToText;

  /// Open the recent-conversations list.
  final VoidCallback onShowRecent;

  /// Cut Aryabhatt off and hand the mic back to the user.
  final VoidCallback onInterrupt;

  @override
  State<HolyCowVoiceControls> createState() => _HolyCowVoiceControlsState();
}

class _HolyCowVoiceControlsState extends State<HolyCowVoiceControls>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Plays once when the console appears (i.e. when a call starts).
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isSpeaking => widget.state == VoiceCallState.speaking;

  /// Wrap [child] in a staggered fade + pop-scale keyed off its [index] in the
  /// row, so the buttons spring in one after another, left to right.
  Widget _staggered(int index, int total, Widget child) {
    // Overlapping intervals: each button starts a little after the previous.
    final double start = total <= 1 ? 0.0 : (index / (total + 1));
    final double end = ((index + 2) / (total + 1)).clamp(0.0, 1.0);
    // Opacity uses a plain curve (easeOutBack would push it >1.0 and assert).
    final fade = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    // Scale uses easeOutBack for that satisfying little "pop" overshoot.
    final pop = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: pop, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Order matters — the stagger runs in this sequence.
    final buttons = <Widget>[
      _GlassIconButton(
        icon: Icons.history_rounded,
        semanticLabel: 'See past conversations',
        onTap: widget.onShowRecent,
      ),
      // "My turn" — only meaningful while he's actually talking.
      if (_isSpeaking)
        _GlassIconButton(
          icon: Icons.mic_rounded,
          semanticLabel: 'Stop Aryabhatt and speak',
          onTap: widget.onInterrupt,
        ),
      _GlassIconButton(
        icon: Icons.keyboard_rounded,
        semanticLabel: 'Switch to typing',
        onTap: widget.onSwitchToText,
      ),
      _GlassIconButton(
        icon: Icons.close_rounded,
        semanticLabel: 'End call',
        tint: Colors.redAccent,
        onTap: widget.onEndCall,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            _staggered(i, buttons.length, buttons[i]),
          ],
        ],
      ),
    );
  }
}

/// A single frosted-glass circular icon button. Blurred translucent fill
/// so a row of them reads as one pure glass console with the cow.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.tint,
  });

  static const double _size = 46.0;

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  /// Optional accent for destructive/highlighted actions (e.g. end call).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color iconColor = tint ?? AppTheme.primaryColor;
    final Color fill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                // Removed border for a pure borderless glass aesthetic
              ),
              child: Icon(
                icon,
                size: _size * 0.46,
                color: iconColor.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
