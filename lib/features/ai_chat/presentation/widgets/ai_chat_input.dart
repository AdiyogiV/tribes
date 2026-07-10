import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/services/media/audio_input_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/presentation/widgets/media/glass_container.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_provider.dart';

/// AI chat input that visually matches [SpaceChatInputArea].
///
/// Layout: `[cow icon] [text field] [send/mic]` inside a [GlassContainer].
/// Voice uses [AudioInputService] (speech-to-text → Gemini), not file upload.
class AiChatInput extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode focusNode;
  final VoidCallback onSendMessage;

  const AiChatInput({
    super.key,
    required this.messageController,
    required this.focusNode,
    required this.onSendMessage,
  });

  @override
  State<AiChatInput> createState() => AiChatInputState();
}

class AiChatInputState extends State<AiChatInput>
    with SingleTickerProviderStateMixin {
  bool _hasText = false;
  late AnimationController _micAnimationController;
  late Animation<double> _micPulseAnimation;

  @override
  void initState() {
    super.initState();
    widget.messageController.addListener(_onTextChanged);

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
    widget.messageController.removeListener(_onTextChanged);
    _micAnimationController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
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
          if (!widget.focusNode.hasFocus) widget.focusNode.requestFocus();
        },
        child: GlassContainer(
          height: 70,
          padding: EdgeInsets.zero,
          child: Consumer<AiChatProvider>(
            builder: (context, provider, _) {
              return Consumer<AudioInputService>(
                builder: (context, audioService, _) {
                  return _buildInputRow(provider, audioService);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow(AiChatProvider provider, AudioInputService audioService) {
    final isRecording = audioService.isRecording;
    final isProcessing = audioService.isProcessing || provider.isStreaming;

    // Animate mic pulse during recording
    if (isRecording && !_micAnimationController.isAnimating) {
      _micAnimationController.repeat(reverse: true);
    } else if (!isRecording) {
      _micAnimationController.stop();
      _micAnimationController.reset();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
      child: Row(
        children: [
          // Cow icon — brand identity (replaces DM's + attach button)
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Image.asset(
                'assets/images/aryabhatt.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSm),

          // Center: text field or recording/processing status
          Expanded(
            child: isRecording
                ? _buildRecordingStatus(audioService)
                : isProcessing
                    ? _buildProcessingStatus()
                    : _buildTextField(),
          ),

          const SizedBox(width: AppDimensions.spacingXs),

          // Right: send, mic, recording controls, or stop button
          _buildTrailingButton(provider, audioService, isRecording, isProcessing),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Text field — left-aligned, matches SpaceChatInputArea
  // ─────────────────────────────────────────────────────────────

  Widget _buildTextField() {
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: TextField(
        controller: widget.messageController,
        focusNode: widget.focusNode,
        decoration: InputDecoration(
          hintText: kIsWeb ? 'Ask Aryabhatt... (Shift+Enter for new line)' : 'Ask Aryabhatt...',
          hintStyle: TextStyle(
            color: AppTheme.primaryColor.withValues(alpha: 0.6),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          isDense: true,
        ),
        style: TextStyle(
          color: AppTheme.primaryColor.withValues(alpha: 0.85),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.left,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: kIsWeb ? TextInputAction.newline : TextInputAction.send,
        keyboardType: TextInputType.multiline,
        autofocus: false,
        enableInteractiveSelection: true,
        onSubmitted: kIsWeb ? null : (_) => widget.onSendMessage(),
      ),
    );
  }

  /// Web: Enter sends, Shift+Enter adds newline.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!kIsWeb) return KeyEventResult.ignored;
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      if (!HardwareKeyboard.instance.isShiftPressed) {
        if (widget.messageController.text.trim().isNotEmpty) {
          widget.onSendMessage();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ─────────────────────────────────────────────────────────────
  // Recording status — matches SpaceChatInputArea style
  // ─────────────────────────────────────────────────────────────

  Widget _buildRecordingStatus(AudioInputService audioService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildRecordingWaveAnimation(),
        const SizedBox(width: AppDimensions.spacingMd),
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

  // ─────────────────────────────────────────────────────────────
  // Processing status — AI streaming
  // ─────────────────────────────────────────────────────────────

  Widget _buildProcessingStatus() {
    return Row(
      children: [
        PulsingDots(
          size: 5,
          color: AppTheme.primaryColor.withValues(alpha: 0.6),
        ),
        const SizedBox(width: AppDimensions.spacingMdSm),
        Text(
          'Generating',
          style: TextStyle(
            color: AppTheme.primaryColor.withValues(alpha: 0.5),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Trailing button — send / mic / stop
  // ─────────────────────────────────────────────────────────────

  Widget _buildTrailingButton(
    AiChatProvider provider,
    AudioInputService audioService,
    bool isRecording,
    bool isProcessing,
  ) {
    if (isRecording) return _buildRecordingControls(audioService);
    if (isProcessing) return _buildStopButton(provider);

    // Normal: send or mic — same icons/sizes as SpaceChatInputArea
    return SizedBox(
      width: 44,
      height: 44,
      child: _hasText
          ? IconButton(
              onPressed: widget.onSendMessage,
              icon: Icon(
                CupertinoIcons.paperplane_fill,
                color: AppTheme.primaryColor,
                size: 22,
              ),
            )
          : IconButton(
              onPressed: () => _startVoiceRecording(audioService, provider),
              icon: Icon(
                CupertinoIcons.mic_fill,
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
                size: 22,
              ),
            ),
    );
  }

  Widget _buildRecordingControls(AudioInputService audioService) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            onPressed: () => _cancelVoiceRecording(audioService),
            icon: const Icon(Icons.close, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
              foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Cancel recording',
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: () => _stopVoiceRecording(audioService),
            icon: Icon(CupertinoIcons.paperplane_fill, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Send recording',
          ),
        ),
      ],
    );
  }

  Widget _buildStopButton(AiChatProvider provider) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: GestureDetector(
          onTap: () {
            provider.stopStreaming();
            HapticFeedback.lightImpact();
          },
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.red.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Voice recording — uses AudioInputService (speech-to-text → Gemini)
  // ─────────────────────────────────────────────────────────────

  Future<void> _startVoiceRecording(
      AudioInputService audioService, AiChatProvider provider) async {
    if (audioService.isRecording || audioService.isProcessing) return;

    if (audioService.hasError) {
      await audioService.resetService();
    }
    audioService.clearState();

    audioService.setOnAudioUrlUploaded((audioUrl) {
      provider.updateLastVoiceMessageUrl(audioUrl);
    });
    audioService.setOnAudioUploadSkipped(() {
      provider.markLastVoiceMessageAsLocalOnly();
    });

    await audioService.startRecording(
      onResult: (AudioInputResult result) {
        _sendVoiceMessage(result, provider);
      },
      onTranscriptUpdate: (String transcript) {
        AppLogger.d('Live transcript: "$transcript"', category: LogCategory.voice);
      },
    );
    HapticFeedback.lightImpact();
  }

  void _stopVoiceRecording(AudioInputService audioService) {
    audioService.stopRecording();
    HapticFeedback.mediumImpact();
  }

  void _cancelVoiceRecording(AudioInputService audioService) {
    widget.messageController.clear();
    audioService.cancelRecording();
    HapticFeedback.lightImpact();
  }

  void _sendVoiceMessage(AudioInputResult result, AiChatProvider provider) {
    widget.messageController.clear();
    provider.sendVoiceMessage(
      transcript: result.transcript,
      localAudioPath: result.localAudioPath,
      audioUrl: result.audioUrl,
      durationInSeconds: result.durationInSeconds,
    );
    HapticFeedback.lightImpact();
  }
}
