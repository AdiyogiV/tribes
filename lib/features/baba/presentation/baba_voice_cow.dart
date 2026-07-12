import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:visibility_detector/visibility_detector.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/app/tabs/widgets/tab_bottom_nav.dart';
import 'package:aurogram/features/baba/voice/voice_session_controller.dart';
import 'package:aurogram/features/baba/domain/baba_presence.dart';
import 'package:aurogram/features/baba/presentation/baba_voice_controls.dart';

/// The Baba cow icon, but alive.
///
/// Idle: a small cow parked above the profile tab (same spot as before).
/// Tap it: it grows, glows, and Aryabhatt starts talking — a live voice call
/// right here on the tab, no new page. Tap again to hang up.
/// Long-press: opens the text input bar (so typing still works).
/// While a call is live a glass control bar appears below (history, my-turn,
/// keyboard, end call).
class BabaVoiceCow extends StatefulWidget {
  const BabaVoiceCow({
    super.key,
    required this.onShowKeyboard,
    required this.onShowRecent,
    required this.onActiveChanged,
  });

  /// Long-press escape hatch back to the typed input bar.
  final VoidCallback onShowKeyboard;

  /// Open the recent-conversations list (from the in-call control bar).
  final VoidCallback onShowRecent;

  /// Fired when a call goes live / ends — lets the dashboard hide the bottom
  /// tab bar for a distraction-free voice experience.
  final ValueChanged<bool> onActiveChanged;

  @override
  State<BabaVoiceCow> createState() => _BabaVoiceCowState();
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
    
    // We reduce the base radius by ~15% so that when the wave wobbles OUTWARD,
    // it never hits the hard square boundaries of the widget's bounding box.
    final double maxWobbleFactor = 0.15; 
    final double radius = center / (1.0 + maxWobbleFactor);
    
    // Active state amplifies the wobble based on the pulse.
    final double waveIntensity = 0.03 + (pulse * 0.05);

    const int samples = 120;
    for (int i = 0; i <= samples; i++) {
      final double t = (i / samples) * 2 * math.pi;
      
      // Smooth, slow, organic liquid shape. Fewer ripples, slower phase shift.
      final double wobble = math.sin(t * 3 + (pulse * math.pi)) * (radius * waveIntensity) + 
                            math.cos(t * 4 - (pulse * math.pi * 0.5)) * (radius * waveIntensity * 0.6);
                            
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

class _BabaVoiceCowState extends State<BabaVoiceCow>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final VoiceSessionController _voice = VoiceSessionController();
  late final AnimationController _pulse;

  /// Last error surfaced via SnackBar, so we don't spam the same one.
  String? _shownError;

  /// Tracks call-active transitions so we only notify the parent on change.
  bool _wasActive = false;

  static const double _idleSize = 70.0;
  static const double _activeSize = 140.0; // Made significantly larger to be prominent

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // This cow is Baba's on-dashboard presence — tell the shell to stand down
    // so we never render two Babas at once. Deferred to post-frame: this
    // initState runs mid-build of the shell's AnimatedBuilder, so notifying its
    // listeners synchronously here throws "setState() called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BabaPresence.instance.dashboardActive = true;
    });
    _voice.addListener(_onVoiceChanged);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voice.removeListener(_onVoiceChanged);
    _pulse.dispose();
    // Cow leaving the tree → hand the stage back to the shell orb. Do NOT
    // dispose _voice: it's the app-scoped singleton shared with the shell, and
    // a live call must survive this widget so it can hand off.
    BabaPresence.instance.dashboardActive = false;
    super.dispose();
  }

  /// End the call if the app is backgrounded — never leave a live mic running
  /// when the user isn't even looking at the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    super.didChangeAppLifecycleState(lifecycle);
    if (lifecycle != AppLifecycleState.resumed && _inCall) {
      _voice.hangUp();
    }
  }

  /// End the call the moment the cow leaves the screen — e.g. the user switches
  /// tabs (PageView keeps us alive but hidden) or pushes another route on top.
  /// Collapses Aryabhatt back to his idle corner instead of secretly listening.
  void _handleVisibility(VisibilityInfo info) {
    if (!mounted) return;
    // Off-screen (tab switch / route pushed on top) → the shell orb takes over
    // as Baba's presence. Keep any live call running so it hands off seamlessly
    // instead of hanging up. (Backgrounding still ends the call, above.)
    BabaPresence.instance.dashboardActive = info.visibleFraction >= 0.1;
  }

  /// Surface call failures loudly instead of just shrinking the cow.
  void _onVoiceChanged() {
    // Notify the dashboard when the call goes live / ends so it can hide the
    // bottom tab bar during a voice session.
    final active = _inCall;
    if (active != _wasActive) {
      _wasActive = active;
      widget.onActiveChanged(active);
    }

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

  /// Control-bar "switch to typing": end the live call first (no ghost session
  /// running in the background) then open the typed input bar.
  Future<void> _switchToText() async {
    await _voice.hangUp();
    if (mounted) widget.onShowKeyboard();
  }

  String _statusText(VoiceCallState s) {
    switch (s) {
      case VoiceCallState.connecting: return 'CONNECTING';
      case VoiceCallState.listening: return 'LISTENING';
      case VoiceCallState.thinking: return 'THINKING';
      case VoiceCallState.speaking: return 'SPEAKING';
      case VoiceCallState.error: return 'ERROR';
      case VoiceCallState.idle:
      case VoiceCallState.ended: return '';
    }
  }

  Color _getStateColor(VoiceCallState state) {
    switch (state) {
      // Matte, stark, flat colors fit minimalism better than bright neons
      case VoiceCallState.listening: return const Color(0xFFFF5722); // Stark orange
      case VoiceCallState.thinking: return const Color(0xFF5C6BC0);  // Soft matte indigo
      case VoiceCallState.speaking: return AppTheme.primaryColor;
      case VoiceCallState.error: return const Color(0xFFE53935);
      case VoiceCallState.connecting: return const Color(0xFFFFB300);
      case VoiceCallState.idle:
      case VoiceCallState.ended: return Colors.transparent;
    }
  }

  Widget _buildMicroMorphIndicator(VoiceCallState state, double pulse) {
    double w = 5.0;
    double h = 5.0;
    Color c = _getStateColor(state);
    BorderRadius r = BorderRadius.circular(5);
    Offset offset = Offset.zero;

    if (state == VoiceCallState.listening || state == VoiceCallState.connecting) {
      // Gentle breathing dot
      final breath = math.sin(pulse * math.pi) * 1.5;
      w = 5.0 + breath;
      h = 5.0 + breath;
    } else if (state == VoiceCallState.thinking) {
      // Cylon/scanning dot - moves laterally
      w = 4.0;
      h = 4.0;
      // Smooth sinusoidal pan back and forth
      offset = Offset(math.sin(pulse * math.pi * 2) * 4.5, 0); 
    } else if (state == VoiceCallState.speaking) {
      // Vibrating vertical dash
      w = 2.5;
      h = 5.0 + (math.sin(pulse * math.pi * 5).abs() * 7.0);
      r = BorderRadius.circular(1.5);
    }

    return SizedBox(
      width: 14, // Fixed bounds so text never jitters
      height: 14,
      child: Center(
        child: Transform.translate(
          offset: offset,
          child: AnimatedContainer(
            // Use easeOutCubic for morphing so it snaps elegantly between states
            duration: const Duration(milliseconds: 250), 
            curve: Curves.easeOutCubic,
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: c,
              borderRadius: r,
              // Removed BoxShadow entirely for that pure, flat minimal aesthetic
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tabCenterFromRight = TabBottomNav.itemCenterFromRight(screenWidth, 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return VisibilityDetector(
      key: const Key('baba_voice_cow_visibility'),
      onVisibilityChanged: _handleVisibility,
      child: AnimatedBuilder(
        animation: Listenable.merge([_voice, _pulse]),
        builder: (context, _) {
        final state = _voice.state;
        final active = _inCall;
        // ALWAYS pass full pulse to avoid snappy wave phase jumps.
        final pulse = _pulse.value;
        final size = active ? _activeSize : _idleSize;
        final reply = _voice.aryabhattReply;

        // Smooth Hero Transition: AnimatedAlign + AnimatedPadding + AnimatedSize
        return AnimatedAlign(
          alignment: active ? Alignment.bottomCenter : Alignment.bottomRight,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          child: AnimatedPadding(
            padding: EdgeInsets.only(
              right: active ? 0 : tabCenterFromRight - _idleSize / 2,
              bottom: 10,
            ),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Live caption of what Aryabhatt is saying (AnimatedSize prevents jumping)
                AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomCenter,
                  child: (active && reply.isNotEmpty)
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                constraints: BoxConstraints(
                                    maxWidth: screenWidth * 0.8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(18),
                                  // Removed border for a pure borderless glass aesthetic
                                ),
                                child: Text(
                                  reply,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 15,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // 2. The icon itself — chic, translucent glass.
                GestureDetector(
                  onTap: _toggle,
                  onLongPress: active ? null : widget.onShowKeyboard,
                  child: ClipPath(
                    clipper: WavyCircleClipper(active ? pulse : 0.0), // The wave is BACK! (and still when idle)
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
                          // NO BORDERS! Pure borderless glass wave.
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.bottomCenter,
                          children: [
                            Positioned(
                              bottom: -4.0, // Just a tiny nudge down inside the wave
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                // Scaled up prominently when active
                                width: active ? 105.0 : 58.0,
                                height: active ? 105.0 : 58.0,
                                alignment: Alignment.bottomCenter,
                                child: Image.asset(
                                  'assets/images/aryabhatt.png',
                                  fit: BoxFit.fitWidth,
                                  alignment: Alignment.bottomCenter,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.auto_awesome,
                                    color: AppTheme.primaryColor,
                                    size: 30.0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Status Pill & Glass control bar
                AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: active
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 14),
                            // Ultra-Minimal Glass Pill
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isDark 
                                        ? Colors.white.withValues(alpha: 0.03) 
                                        : Colors.black.withValues(alpha: 0.02),
                                    // Removed border for a pure glass look
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildMicroMorphIndicator(state, pulse),
                                      const SizedBox(width: 8),
                                      // Micro-typography
                                      Text(
                                        _statusText(state),
                                        style: TextStyle(
                                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                                          fontSize: 9, // Micro size
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2.0, // Wide chic tracking
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Voice Controls
                            BabaVoiceControls(
                              state: state,
                              onEndCall: _voice.hangUp,
                              onSwitchToText: _switchToText,
                              onShowRecent: widget.onShowRecent,
                              onInterrupt: _voice.interruptAndListen,
                            )
                          ],
                        )
                      : (state == VoiceCallState.error)
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                _statusText(state),
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }
}
