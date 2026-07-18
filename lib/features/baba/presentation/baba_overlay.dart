import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_theme.dart';



import 'package:aurogram/features/baba/domain/baba_auth_identity.dart';
import 'package:aurogram/features/baba/domain/baba_chat_controller.dart';
import 'package:aurogram/features/baba/domain/baba_context.dart';
import 'package:aurogram/features/baba/domain/baba_insets.dart';
import 'package:aurogram/features/baba/domain/baba_position.dart';
import 'package:aurogram/features/baba/domain/baba_lead.dart';
import 'package:aurogram/features/baba/presentation/baba_blob.dart';
import 'package:aurogram/features/baba/presentation/baba_chat_panel.dart';

import 'package:aurogram/features/baba/voice/baba_greet_on_open_pref.dart';
import 'package:aurogram/features/baba/voice/voice_session_controller.dart';

/// The ONE Baba — an app-wrapping agent that floats over every route and
/// survives navigation.
///
/// Mounted once in `app_root`'s MaterialApp builder, above every screen. Baba
/// looks and behaves identically everywhere: an idle liquid glass blob that,
/// on tap, grows into a live voice call (status pill + control bar), and on
/// "keyboard" opens an in-place floating chat sheet (see [BabaChatPanel]) —
/// never navigating away, so the "I wrap your whole app" feeling holds.
///
/// He shares the one [VoiceSessionController] singleton, so a call started
/// anywhere keeps going as you move around. Tools are registered at app start
/// (see BabaToolCatalog); this widget is purely the presence UI.
class BabaOverlay extends StatefulWidget {
  const BabaOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<BabaOverlay> createState() => _BabaOverlayState();
}

class _BabaOverlayState extends State<BabaOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final VoiceSessionController _voice = VoiceSessionController();
  final BabaChatController _chat = BabaChatController.instance;
  final BabaContext _context = BabaContext.instance;
  final BabaInsets _insets = BabaInsets.instance;
  final BabaPosition _position = BabaPosition.instance;
  late final AnimationController _pulse;
  String? _shownError;
  late BabaAuthIdentity _authIdentity;
  StreamSubscription<User?>? _authSubscription;

  // Auto-activation (opt-in "greet me on open"). We fire it at most ONCE per
  // app launch and only on the home screen. On web a browser gesture is
  // mandatory, so instead of starting audio directly we ARM a one-shot listener
  // that goes live on the user's first tap. [_autoStartEvaluating] guards the
  // async pref read against the many context notifications that arrive at once.
  bool _autoStartDone = false;
  bool _autoStartEvaluating = false;
  bool _armWebAutoStart = false;
  static const String _homeScreenKey = 'home';

  // Drag state. Screen metrics are cached each build so the pan gesture
  // callbacks can clamp Baba within the visible area without a MediaQuery.
  bool _dragging = false;
  Size _screen = Size.zero;
  double _safeTop = 0;
  double _safeBottom = 0;
  double _barInset = 0;

  static const double _idleSize = 70.0;
  static const double _edgePad = 8.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _voice.addListener(_onVoiceChanged);
    _authIdentity = BabaAuthIdentity.fromUser(FirebaseAuth.instance.currentUser);
    _authSubscription =
        FirebaseAuth.instance.userChanges().listen(_onAuthChanged);
    // Auto-activation is HOME-scoped, and the app rarely opens straight onto
    // home (splash/onboarding come first), so we re-evaluate on every route
    // change until it fires once. Cheap: guarded by [_autoStartDone].
    _context.addListener(_maybeAutoStart);
    // Pre-warm the call in the background so the FIRST tap is instant (no
    // "connecting…" wait). Best-effort; re-warmed on resume below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmUp();
      _maybeAutoStart();
    });
  }

  void _onAuthChanged(User? user) {
    final next = BabaAuthIdentity.fromUser(user);
    if (!_authIdentity.requiresSessionRefresh(next)) return;
    _authIdentity = next;
    unawaited(_refreshForAuthChange());
  }

  Future<void> _refreshForAuthChange() async {
    // Warm greetings embed account=guest/secured. Never adopt one after that
    // fact changes, even when Firebase linked the same uid in place.
    await _voice.invalidateForAuthChange();
    if (!mounted) return;
    _context.markStateChanged();
    await _warmUp();
  }

  /// Build Baba's opening cue and pre-warm a call so the next tap is instant.
  /// Cheap-guarded first (via [canWarmUp]) so we never do the directive's
  /// Firestore read when warming would just no-op (not signed in, already warm,
  /// mid-call, or inside the warm-resume window).
  Future<void> _warmUp() async {
    if (!_voice.canWarmUp) return;
    _voice.directiveOverride = await BabaLead.directive();
    await _voice.warmUp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voice.removeListener(_onVoiceChanged);
    _authSubscription?.cancel();
    _context.removeListener(_maybeAutoStart);
    _pulse.dispose();
    // NOTE: never dispose _voice — it's the app-scoped singleton.
    super.dispose();
  }

  /// End the call if the app is backgrounded WHILE AUDIO IS LIVE — never leave
  /// a live mic running. We deliberately do NOT tear down during `connecting`:
  /// the first-ever call raises the OS mic-permission dialog, which backgrounds
  /// the app mid-connect; hanging up there left a zombie socket that fired a
  /// second kickoff (double greeting + double navigate).
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    super.didChangeAppLifecycleState(lifecycle);
    if (lifecycle == AppLifecycleState.resumed) {
      // Back in the foreground and idle: pre-warm so the next tap is instant.
      _warmUp();
      return;
    }
    // Backgrounding is INVOLUNTARY — mark it so a quick return still resumes the
    // conversation (not a fresh greeting).
    if (_voice.state.isLiveAudio) _voice.hangUp(byUser: false);
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
      // Explicit close: pre-warm a fresh greeting so the NEXT tap opens warmly
      // and instantly, just like the first one.
      unawaited(_warmUp());
      return;
    }
    await _beginCall();
  }

  /// Go live. The ONE path that both the tap and the opt-in auto-activation use
  /// (so they can never drift): adopt a pre-warmed session instantly if one is
  /// ready, otherwise cold-build the opening directive first so Baba still
  /// greets and leads.
  Future<void> _beginCall() async {
    if (_inCall) return;
    if (_voice.hasWarmSession) {
      // A pre-warmed session is ready: adopt it instantly. The opening directive
      // was already built during warmUp, so DON'T rebuild it here (that read can
      // take up to ~3s and would defeat the whole point).
      await _voice.start();
    } else {
      // Cold path: Baba LEADS — build the directive so he greets + takes the
      // initiative instead of waiting (see BabaLead), then connect.
      _voice.directiveOverride = await BabaLead.directive();
      await _voice.start();
    }
  }

  /// Opt-in "greet me on open": go live automatically when the app lands on the
  /// HOME screen, at most once per launch. On web, browsers forbid starting
  /// audio/mic without a user gesture, so we cannot start here — instead we ARM
  /// a one-shot listener that begins the call on the user's first tap.
  Future<void> _maybeAutoStart() async {
    if (_autoStartDone || _autoStartEvaluating || _armWebAutoStart) return;
    if (_inCall) return;
    if (_context.screen?.key != _homeScreenKey) return; // HOME scope only
    // The relay needs a Firebase identity; skip silently until one exists.
    if (FirebaseAuth.instance.currentUser == null) return;
    _autoStartEvaluating = true;
    try {
      if (!await BabaGreetOnOpenPref.read()) return; // opt-in, default off
      // Re-check after the async gap: state may have moved under us.
      if (!mounted || _autoStartDone || _inCall) return;
      if (_context.screen?.key != _homeScreenKey) return;
      if (kIsWeb) {
        // Arm the first-tap path (see [_onFirstWebGesture]).
        setState(() => _armWebAutoStart = true);
      } else {
        _autoStartDone = true;
        await _beginCall();
      }
    } finally {
      _autoStartEvaluating = false;
    }
  }

  /// Web only: the user's first tap satisfies the browser's gesture gate, so
  /// disarm and go live. Wired via a translucent [Listener] so this tap still
  /// passes through to whatever the user actually touched.
  void _onFirstWebGesture(PointerDownEvent _) {
    if (!_armWebAutoStart || _autoStartDone) return;
    _autoStartDone = true;
    setState(() => _armWebAutoStart = false);
    unawaited(_beginCall());
  }

  /// Switch from voice to typing: end any live call, then slide up the chat
  /// sheet in place. Shared by the control-bar keyboard button and long-press.
  Future<void> _openChat() async {
    if (_inCall) await _voice.hangUp();
    _chat.open();
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stack = Stack(
      children: [
        widget.child,
        // The floating presence — bound to the voice session + pulse so it
        // reflects live call state everywhere. Also listens to [BabaInsets] so
        // it floats ABOVE whatever bottom bar the current screen shows.
        AnimatedBuilder(
          animation: Listenable.merge([_voice, _pulse, _insets, _position]),
          builder: (context, _) => _buildPresence(context, isDark),
        ),
        // The in-place chat sheet — mounted only while open.
        AnimatedBuilder(
          animation: _chat,
          builder: (context, _) => _chat.isOpen
              ? Positioned.fill(child: BabaChatPanel(onClose: _chat.close))
              : const SizedBox.shrink(),
        ),
      ],
    );
    // Web-only auto-activation: capture the FIRST tap anywhere to satisfy the
    // browser's audio/mic gesture gate, WITHOUT consuming it (translucent) so
    // the underlying UI still reacts to that same tap.
    if (!_armWebAutoStart) return stack;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onFirstWebGesture,
      child: stack,
    );
  }

  Widget _buildPresence(BuildContext context, bool isDark) {
    // Cache screen metrics so the pan-gesture callbacks can clamp Baba within
    // the visible area without re-reading MediaQuery.
    final mq = MediaQuery.of(context);
    _screen = mq.size;
    _safeTop = mq.padding.top;
    _safeBottom = mq.padding.bottom;
    _barInset = _insets.bottomObstruction;

    // A live call takes over the full presence (caption + centred blob +
    // controls) and ignores the parked spot — you can't sensibly drag a call
    // UI with a control bar. The IDLE blob is the draggable one.
    if (_inCall) return _buildCallPresence(context, isDark);
    return _buildIdlePresence(context, isDark);
  }


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
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 34),
                              child: SingleChildScrollView(
                                reverse: true,
                                physics: const BouncingScrollPhysics(),
                                child: Text(
                                  activeText,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 13,
                                    height: 1.25,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
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

  /// The idle blob — draggable ANYWHERE.
  Widget _buildIdlePresence(BuildContext context, bool isDark) {
    final pulse = _pulse.value;
    final offset = _clamp(_position.offset ?? _defaultOffset());

    return Positioned.fill(
      child: Stack(
        children: [
          AnimatedPositioned(
            left: offset.dx,
            top: offset.dy,
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: GestureDetector(
              onTap: _toggleCall,
              onLongPress: _openChat,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: BabaBlob(
                size: _idleSize,
                active: false,
                pulse: pulse,
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dragging ────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails d) {
    HapticFeedback.selectionClick();
    // Seed from the current on-screen spot so the first move never jumps.
    _position.update(_clamp(_position.offset ?? _defaultOffset()));
    setState(() => _dragging = true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final current = _position.offset ?? _defaultOffset();
    _position.update(_clamp(current + d.delta));
  }

  void _onPanEnd(DragEndDetails d) {
    _position.commit(_clamp(_position.offset ?? _defaultOffset()));
    setState(() => _dragging = false);
  }

  /// Default anchored spot: bottom-right, above the safe area + current bar.
  Offset _defaultOffset() => Offset(
        _screen.width - _idleSize - 16,
        _screen.height - _idleSize - 16 - _safeBottom - _barInset,
      );

  /// Keep the whole blob on-screen (below the status bar, above the safe area).
  Offset _clamp(Offset o) {
    if (_screen == Size.zero) return o;
    final maxX = _screen.width - _idleSize - _edgePad;
    final maxY = _screen.height - _idleSize - _edgePad - _safeBottom;
    final minY = _safeTop + _edgePad;
    final dx = o.dx.clamp(_edgePad, maxX < _edgePad ? _edgePad : maxX);
    final dy = o.dy.clamp(minY, maxY < minY ? minY : maxY);
    return Offset(dx.toDouble(), dy.toDouble());
  }


}
