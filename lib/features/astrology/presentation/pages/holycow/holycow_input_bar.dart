import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/presentation/widgets/media/glass_container.dart';
import 'package:aurogram/shared/services/media/audio_input_service.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_provider.dart';
import 'package:aurogram/features/astrology/presentation/pages/holycow/holycow_input_bar_controller.dart';

/// The expanded HolyCow AI input toolbar: history button, center text field
/// (with cycling typewriter hint), and a send/mic button that flips to
/// cancel/send while recording.
///
/// This is the *view* half of [HolyCowInputBarController] — the page owns the
/// controller (so it can collapse the bar on scroll) while this widget owns
/// the purely-presentational bits: hint cycling, mic pulse animation, and the
/// voice-recording lifecycle. Navigation is delegated to the page via the
/// [onSendText] / [onVoiceResult] / [onShowRecent] callbacks so this widget
/// stays unaware of routing vs. inline-desktop concerns.
class HolyCowInputBar extends StatefulWidget {
  const HolyCowInputBar({
    super.key,
    required this.controller,
    required this.onSendText,
    required this.onVoiceResult,
    required this.onShowRecent,
  });

  final HolyCowInputBarController controller;

  /// Called with the trimmed message after the field is cleared & unfocused.
  final ValueChanged<String> onSendText;

  /// Called when a voice recording finishes with a transcribed result.
  final ValueChanged<AudioInputResult> onVoiceResult;

  /// Called when the history button is tapped.
  final VoidCallback onShowRecent;

  // Typewriter hint text — cycles through phrases every 2s.
  static const List<String> _hintPhrases = [
    'ask aryabhatt',
    'ask anything',
    'namaste',
    "what's up today?",
    'vata pitta kapha?',
  ];

  @override
  State<HolyCowInputBar> createState() => _HolyCowInputBarState();
}

class _HolyCowInputBarState extends State<HolyCowInputBar>
    with SingleTickerProviderStateMixin {
  Timer? _hintTimer;
  final ValueNotifier<int> _hintIndexNotifier = ValueNotifier<int>(0);

  late final AnimationController _micAnimationController;
  late final Animation<double> _micPulseAnimation;

  TextEditingController get _text => widget.controller.text;
  FocusNode get _focusNode => widget.controller.focusNode;

  @override
  void initState() {
    super.initState();

    _hintTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      _hintIndexNotifier.value =
          (_hintIndexNotifier.value + 1) % HolyCowInputBar._hintPhrases.length;
    });

    _micAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _micPulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _micAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _hintIndexNotifier.dispose();
    _micAnimationController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Intents
  // ─────────────────────────────────────────────────────────────

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    _focusNode.unfocus();
    HapticFeedback.lightImpact();
    widget.onSendText(text);
  }

  Future<void> _startRecording() async {
    final audioService = Provider.of<AudioInputService>(context, listen: false);
    final provider = Provider.of<AiChatProvider>(context, listen: false);
    if (audioService.isRecording || audioService.isProcessing) return;

    if (audioService.hasError) await audioService.resetService();
    audioService.clearState();

    // Register upload callbacks so the provider gets notified when the
    // background upload completes (stops the upload spinner on messages).
    audioService.setOnAudioUrlUploaded(provider.updateLastVoiceMessageUrl);
    audioService.setOnAudioUploadSkipped(provider.markLastVoiceMessageAsLocalOnly);

    await audioService.startRecording(
      onResult: (AudioInputResult result) {
        if (!mounted) return;
        widget.onVoiceResult(result);
      },
      onTranscriptUpdate: (String transcript) {
        AppLogger.d('Dashboard transcript: "$transcript"',
            category: LogCategory.voice);
      },
    );
    HapticFeedback.lightImpact();
  }

  void _stopRecording() {
    Provider.of<AudioInputService>(context, listen: false).stopRecording();
    HapticFeedback.mediumImpact();
  }

  void _cancelRecording() {
    Provider.of<AudioInputService>(context, listen: false).cancelRecording();
    HapticFeedback.lightImpact();
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: () {
          if (!_focusNode.hasFocus) _focusNode.requestFocus();
        },
        // Same transparent glass surface as the tab bar (shared widget).
        child: GlassContainer(
          height: 70,
          padding: EdgeInsets.zero,
          child: Consumer<AudioInputService>(
            builder: (context, audioService, _) {
              final isRecording = audioService.isRecording;

              // Animate mic pulse during recording
              if (isRecording && !_micAnimationController.isAnimating) {
                _micAnimationController.repeat(reverse: true);
              } else if (!isRecording) {
                _micAnimationController.stop();
                _micAnimationController.reset();
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Past chats icon
                    SizedBox(
                      width: 36,
                      height: 44,
                      child: Center(
                        child: IconButton(
                          onPressed: widget.onShowRecent,
                          icon: Icon(
                            Icons.history_rounded,
                            color: AppTheme.primaryColor.withValues(alpha: 0.7),
                            size: 22,
                          ),
                          tooltip: 'Recent Conversations',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Center: text field or recording indicator
                    Expanded(
                      child: isRecording
                          ? _buildRecordingIndicator()
                          : _buildTextField(),
                    ),

                    // Right: send/mic or recording controls
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: isRecording
                            ? _buildRecordingControls()
                            : _buildSendOrMicButton(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Animated hint overlay — slides in on change
        ListenableBuilder(
          listenable: _text,
          builder: (context, _) {
            if (_text.text.isNotEmpty) return const SizedBox.shrink();
            return IgnorePointer(
              child: ValueListenableBuilder<int>(
                valueListenable: _hintIndexNotifier,
                builder: (context, hintIndex, _) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      final isIncoming = child.key == ValueKey<int>(hintIndex);
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(0, isIncoming ? 0.6 : -0.6),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Text(
                      HolyCowInputBar._hintPhrases[hintIndex],
                      key: ValueKey<int>(hintIndex),
                      style: TextStyle(
                        color: AppTheme.primaryColor.withValues(alpha: 0.4),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        // Actual text field — no hintText, overlay handles it
        Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter &&
                !HardwareKeyboard.instance.isShiftPressed) {
              _send();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: _text,
            focusNode: _focusNode,
            decoration: const InputDecoration(
              hintText: null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              isDense: true,
            ),
            style: TextStyle(
              color: AppTheme.primaryColor.withValues(alpha: 0.85),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
          ),
        ),
      ],
    );
  }

  Widget _buildSendOrMicButton() {
    return ListenableBuilder(
      listenable: _text,
      builder: (context, _) {
        final hasText = _text.text.trim().isNotEmpty;
        return hasText
            ? IconButton(
                onPressed: _send,
                icon: Icon(
                  CupertinoIcons.paperplane_fill,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              )
            : IconButton(
                onPressed: _startRecording,
                icon: Icon(
                  CupertinoIcons.mic_fill,
                  color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  size: 22,
                ),
              );
      },
    );
  }

  Widget _buildRecordingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildRecordingWaveAnimation(),
        const SizedBox(width: 12),
        Text(
          'Recording...',
          style: TextStyle(
            color: Colors.red[400],
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingWaveAnimation() {
    return AnimatedBuilder(
      animation: _micPulseAnimation,
      builder: (context, child) {
        final progress = _micPulseAnimation.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animValue = ((progress - 0.9) / 0.2 + delay) % 1.0;
            final height = 8 + (animValue * 8);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: Colors.red[400],
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildRecordingControls() {
    // During recording, show cancel + send in a compact layout within 64px
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _cancelRecording,
          child: Icon(Icons.close,
              size: 18, color: AppTheme.primaryColor.withValues(alpha: 0.6)),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _stopRecording,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.paperplane_fill,
                size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
