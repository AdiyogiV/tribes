import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/services/audio_input_service.dart';
import 'package:aurogram/providers/ai_chat_provider.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';

/// Internal astrology chat content widget with cow icon and optional voice support
/// Used by TransparentToolbox.astroChat()
class AstroChatContent extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final String hintText;
  final bool enableVoice;
  final VoidCallback? onMicPressed;

  const AstroChatContent({
    super.key,
    required this.messageController,
    required this.focusNode,
    required this.onSend,
    required this.hintText,
    this.enableVoice = false,
    this.onMicPressed,
  });

  @override
  State<AstroChatContent> createState() => AstroChatContentState();
}

class AstroChatContentState extends State<AstroChatContent>
    with TickerProviderStateMixin {
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
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If voice is not enabled, use the simple layout
    if (!widget.enableVoice) {
      return _buildSimpleLayout();
    }

    // Voice-enabled layout with AudioInputService and AiChatProvider
    return Consumer<AiChatProvider>(
      builder: (context, provider, _) {
        return Consumer<AudioInputService>(
          builder: (context, audioService, _) {
            return _buildVoiceEnabledLayout(provider, audioService);
          },
        );
      },
    );
  }

  /// Simple layout without voice (original behavior)
  Widget _buildSimpleLayout() {
    return Row(
      children: [
        // Text input - expanded to fill available space
        Expanded(child: _buildTextField()),
        const SizedBox(width: AppDimensions.spacingSm),
        // Send button - HolyCow icon
        _buildCowSendButton(),
      ],
    );
  }

  /// Voice-enabled layout with recording states
  Widget _buildVoiceEnabledLayout(
      AiChatProvider provider, AudioInputService audioService) {
    final isRecording = audioService.isRecording;
    final isProcessing = audioService.isProcessing || provider.isStreaming;

    // Control animation based on recording state
    if (isRecording) {
      if (!_micAnimationController.isAnimating) {
        _micAnimationController.repeat(reverse: true);
      }
    } else {
      _micAnimationController.stop();
      _micAnimationController.reset();
    }

    // Determine unique key for animation state
    final stateKey = isRecording
        ? 'recording'
        : isProcessing
            ? 'processing'
            : 'normal';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Row(
        key: ValueKey(stateKey),
        children: [
          // Left section - Input, voice status, or processing status
          Expanded(
            child: _buildInputSection(audioService, isRecording, isProcessing),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          // Right section - Controls
          _buildControlsSection(
              provider, audioService, isRecording, isProcessing),
        ],
      ),
    );
  }

  /// Build the input section (left side)
  Widget _buildInputSection(
      AudioInputService audioService, bool isRecording, bool isProcessing) {
    if (isRecording) {
      return _buildVoiceStatusDisplay();
    } else if (isProcessing) {
      return _buildProcessingStatus();
    } else {
      return _buildTextField();
    }
  }

  /// Build processing status display when AI is generating
  Widget _buildProcessingStatus() {
    return Row(
      children: [
        PulsingDots(
          size: 5,
          color: AppTheme.astroBrown(
                  Theme.of(context).brightness == Brightness.dark)
              .withValues(alpha: 0.6),
        ),
        const SizedBox(width: AppDimensions.spacingMdSm),
        Text(
          'Generating',
          style: TextStyle(
            color: AppTheme.astroBrown(
                    Theme.of(context).brightness == Brightness.dark)
                .withValues(alpha: 0.5),
            fontSize: AppTheme.holyCowTextSize,
          ),
        ),
      ],
    );
  }

  /// Build voice status display for recording state
  Widget _buildVoiceStatusDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated recording indicator - 3 pulsing bars
        _buildRecordingWaveAnimation(),
        const SizedBox(width: AppDimensions.spacingMd),
        Text(
          'Recording...',
          style: TextStyle(
            color: Colors.red[400],
            fontSize: AppTheme.holyCowTextSize,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// Build minimal wave animation for recording indicator
  Widget _buildRecordingWaveAnimation() {
    return AnimatedBuilder(
      animation: _micPulseAnimation,
      builder: (context, child) {
        final progress = _micPulseAnimation.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Stagger the animation for each bar
            final delay = index * 0.2;
            final animValue = ((progress - 0.9) / 0.2 + delay) % 1.0;
            final height = 8 + (animValue * 8); // 8-16px height

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

  /// Build text input field
  Widget _buildTextField() {
    return TextField(
      controller: widget.messageController,
      focusNode: widget.focusNode,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(
          color: AppTheme.primaryColor.withValues(alpha: 0.6),
          fontSize: AppTheme.holyCowTextSize,
          fontWeight: FontWeight.w500,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 0,
        ),
        isDense: true,
      ),
      style: TextStyle(
        color: AppTheme.primaryColor.withValues(alpha: 0.85),
        fontSize: AppTheme.holyCowTextSize,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      textInputAction: TextInputAction.send,
      textCapitalization: TextCapitalization.sentences,
      autofocus: false,
      enableInteractiveSelection: true,
      onSubmitted: (_) {
        if (_hasText) {
          widget.onSend();
        }
      },
      onTap: () {
        if (!widget.focusNode.hasFocus) {
          widget.focusNode.requestFocus();
        }
      },
    );
  }

  /// Build the controls section (right side)
  Widget _buildControlsSection(AiChatProvider provider,
      AudioInputService audioService, bool isRecording, bool isProcessing) {
    if (isRecording) {
      return _buildRecordingControls(audioService);
    } else if (isProcessing) {
      return _buildStopButton(provider);
    } else {
      return _buildNormalControls(provider, audioService);
    }
  }

  /// Build controls for recording state
  Widget _buildRecordingControls(AudioInputService audioService) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cancel button
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
        // Send button
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: () => _stopVoiceRecording(audioService),
            icon: const Icon(Icons.send, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.astroBrown(
                  Theme.of(context).brightness == Brightness.dark),
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

  /// Build normal controls (mic + cow send)
  Widget _buildNormalControls(
      AiChatProvider provider, AudioInputService audioService) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Microphone button
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: () => _startVoiceRecording(audioService, provider),
            icon: const Icon(Icons.mic, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppTheme.astroBrown(
                  Theme.of(context).brightness == Brightness.dark),
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Voice message',
          ),
        ),
        // Cow send button
        _buildCowSendButton(),
      ],
    );
  }

  /// Build a subtle stop button for when AI is processing
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

  /// Build cow send button (used in both simple and voice-enabled layouts)
  Widget _buildCowSendButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: _hasText
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onSend();
                }
              : null,
          customBorder: const CircleBorder(),
          child: Center(
            child: Opacity(
              opacity: _hasText ? 1.0 : 0.4,
              child: Image.asset(
                'assets/images/cow1.png',
                width: 32,
                height: 32,
                errorBuilder: (_, __, ___) => Icon(
                  CupertinoIcons.paperplane_fill,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Start voice recording
  Future<void> _startVoiceRecording(
      AudioInputService audioService, AiChatProvider provider) async {
    // Check if already recording or processing
    if (audioService.isRecording || audioService.isProcessing) {
      AppLogger.w('Already recording or processing',
          category: LogCategory.voice);
      return;
    }

    // Try to reset the service if there's an error from previous attempt
    if (audioService.hasError) {
      AppLogger.i('Resetting service due to previous error',
          category: LogCategory.voice);
      await audioService.resetService();
    }

    // Clear previous state and start fresh
    audioService.clearState();

    // Set up callback to update message when audio URL is uploaded
    audioService.setOnAudioUrlUploaded((audioUrl) {
      provider.updateLastVoiceMessageUrl(audioUrl);
    });

    // Set up callback for when upload is skipped (logged out user or failure)
    audioService.setOnAudioUploadSkipped(() {
      provider.markLastVoiceMessageAsLocalOnly();
    });

    // Start recording
    await audioService.startRecording(
      onResult: (AudioInputResult result) {
        // Send voice message
        _sendVoiceMessage(result, provider);
      },
      onTranscriptUpdate: (String transcript) {
        AppLogger.d('Live transcript update: "$transcript"',
            category: LogCategory.voice);
      },
    );
    HapticFeedback.lightImpact();
    widget.onMicPressed?.call();
  }

  /// Stop voice recording and send
  void _stopVoiceRecording(AudioInputService audioService) {
    audioService.stopRecording();
    HapticFeedback.mediumImpact();
  }

  /// Cancel voice recording without sending
  void _cancelVoiceRecording(AudioInputService audioService) {
    widget.messageController.clear();
    audioService.cancelRecording();
    AppLogger.i('Voice recording cancelled by user',
        category: LogCategory.voice);
    HapticFeedback.lightImpact();
  }

  /// Send voice message to AI chat
  void _sendVoiceMessage(AudioInputResult result, AiChatProvider provider) {
    widget.messageController.clear();

    // Send voice message to AI chat
    provider.sendVoiceMessage(
      transcript: result.transcript,
      localAudioPath: result.localAudioPath,
      audioUrl: result.audioUrl,
      durationInSeconds: result.durationInSeconds,
    );

    HapticFeedback.lightImpact();
  }
}
