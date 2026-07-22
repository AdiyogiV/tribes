import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/services/media/audio_input_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/shared/presentation/widgets/media/glass_container.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_provider.dart';

class ChatInputArea extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode focusNode;
  final VoidCallback onSendMessage;
  final VoidCallback? onMicPressed;

  const ChatInputArea({
    super.key,
    required this.messageController,
    required this.focusNode,
    required this.onSendMessage,
    this.onMicPressed,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea>
    with TickerProviderStateMixin {
  bool _hasText = false;
  late AnimationController _micAnimationController;
  late Animation<double> _micPulseAnimation;

  @override
  void initState() {
    super.initState();
    widget.messageController.addListener(_onTextChanged);

    _micAnimationController = AnimationController(
      duration: Duration(milliseconds: 1000),
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
    // Styled exactly like the tabs bar - transparent with blur effect
    // Bottom padding matches TabBottomNav (10px) for consistent spacing
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: () {
          // Immediately request focus when tapping the container
          if (!widget.focusNode.hasFocus) {
            widget.focusNode.requestFocus();
          }
        },
        child: GlassContainer(
          height: 70,
          padding: EdgeInsets.zero,
          child: Consumer<AiChatProvider>(
            builder: (context, provider, _) {
              return Consumer<AudioInputService>(
                builder: (context, audioService, _) {
                  return _buildUnifiedToolbarContent(provider, audioService);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Unified toolbar content that handles all states professionally
  Widget _buildUnifiedToolbarContent(
      AiChatProvider provider, AudioInputService audioService) {
    final isRecording = audioService.isRecording;
    final isProcessing = audioService.isProcessing || provider.isStreaming;
    final hasTranscript = audioService.currentTranscript.trim().isNotEmpty;
    final hasSpeechError = audioService.hasSpeechRecognitionError;

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

    // Use faster animation for better responsiveness
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 150),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: LayoutBuilder(
        key: ValueKey(stateKey),
        builder: (context, constraints) {
          // Tab bar uses spaceEvenly with 4 items, each 64px wide.
          // spaceEvenly gap = (totalWidth - 4*64) / 5
          final totalWidth = constraints.maxWidth;
          final gap = (totalWidth - 4 * 64) / 5;

          return Row(
            children: [
              // Left gap — same as tab bar spaceEvenly leading gap
              SizedBox(width: gap),
              // Baba icon — aligned with first tab bar icon
              SizedBox(
                width: 64,
                height: 70,
                child: Center(
                  child: Image.asset(
                    'assets/images/aurobhatt.webp',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Center section - Input
              Expanded(
                child: _buildInputSection(audioService, isRecording,
                    hasTranscript, hasSpeechError, isProcessing),
              ),
              // Right section - Controls (mic/send) — aligned with last tab bar icon
              SizedBox(
                width: 64,
                height: 70,
                child: Center(
                  child: _buildControlsSection(
                      provider, audioService, isRecording, isProcessing),
                ),
              ),
              // Right gap — same as tab bar spaceEvenly trailing gap
              SizedBox(width: gap),
            ],
          );
        },
      ),
    );
  }

  /// Build the input section (left side of toolbar)
  Widget _buildInputSection(AudioInputService audioService, bool isRecording,
      bool hasTranscript, bool hasSpeechError, bool isProcessing) {
    if (isRecording) {
      return _buildVoiceStatusDisplay(
          audioService, hasTranscript, hasSpeechError);
    } else if (isProcessing) {
      return _buildProcessingStatus();
    } else {
      return _buildTextInput();
    }
  }

  /// Build processing status display when AI is generating
  Widget _buildProcessingStatus() {
    return Row(
      children: [
        PulsingDots(
          size: 5,
          color: AppTheme.primaryColor.withValues(alpha: 0.6),
        ),
        SizedBox(width: AppDimensions.spacingMdSm),
        Text(
          'Generating',
          style: TextStyle(
            color: AppTheme.primaryColor.withValues(alpha: 0.5),
            fontSize: AppTheme.babaTextSize,
          ),
        ),
      ],
    );
  }

  /// Handle keyboard events for web - Enter sends, Shift+Enter adds newline
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!kIsWeb) return KeyEventResult.ignored;

    // Only handle key down events for Enter key
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
      if (!isShiftPressed) {
        // Enter without Shift - send message if there's text
        if (widget.messageController.text.trim().isNotEmpty) {
          widget.onSendMessage();
        }
        return KeyEventResult.handled; // Consume event, prevent newline
      }
      // Shift+Enter - let it pass through to add newline
    }
    return KeyEventResult.ignored;
  }

  /// Build text input field for normal state
  Widget _buildTextInput() {
    return GestureDetector(
      onTap: () {
        if (!widget.focusNode.hasFocus) {
          widget.focusNode.requestFocus();
        }
      },
      child: Focus(
        onKeyEvent: _handleKeyEvent,
        child: TextField(
          controller: widget.messageController,
          focusNode: widget.focusNode,
          decoration: InputDecoration(
            hintText: 'namaste',
            hintStyle: TextStyle(
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
              fontSize: AppTheme.babaTextSize,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            isDense: true,
          ),
          style: TextStyle(
            color: AppTheme.primaryColor.withValues(alpha: 0.85),
            fontSize: AppTheme.babaTextSize,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: null,
          maxLength: null,
          textInputAction:
              kIsWeb ? TextInputAction.none : TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          autofocus: false,
          enableInteractiveSelection: true,
          onSubmitted: (_) => widget.onSendMessage(),
          onTap: () {
            if (!widget.focusNode.hasFocus) {
              widget.focusNode.requestFocus();
            }
          },
        ),
      ),
    );
  }

  /// Build voice status display for recording state - minimal professional animation
  Widget _buildVoiceStatusDisplay(
      AudioInputService audioService, bool hasTranscript, bool hasSpeechError) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated recording indicator - 3 pulsing bars
        _buildRecordingWaveAnimation(),
        SizedBox(width: AppDimensions.spacingMd),
        Text(
          'Recording...',
          style: TextStyle(
            color: Colors.red[400],
            fontSize: AppTheme.babaTextSize,
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
              margin: EdgeInsets.symmetric(horizontal: 2),
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

  /// Build the controls section (right side of toolbar)
  Widget _buildControlsSection(AiChatProvider provider,
      AudioInputService audioService, bool isRecording, bool isProcessing) {
    if (isRecording) {
      return _buildRecordingControls(audioService);
    } else {
      return _buildNormalControls(provider, audioService, isProcessing);
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
            icon: Icon(Icons.close, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
              foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
              shape: CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Cancel recording',
          ),
        ),

        SizedBox(width: AppDimensions.spacingSm),

        // Send button
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: () => _stopVoiceRecording(audioService),
            icon: Icon(Icons.send, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Send recording',
          ),
        ),
      ],
    );
  }

  /// Build controls for normal state
  /// Shows stop button when processing, otherwise shows mic + send
  Widget _buildNormalControls(AiChatProvider provider,
      AudioInputService audioService, bool isProcessing) {
    // When processing, show ONLY a stop button (cleaner UX)
    if (isProcessing) {
      return _buildStopButton(provider);
    }

    // Normal state: show mic when no text, send (paperplane) when text entered
    if (_hasText) {
      // Send button (paperplane) - visible only when text is entered
      return IconButton(
        onPressed: () {
          widget.onSendMessage();
        },
        icon: Icon(
          Icons.send,
          color: AppTheme.primaryColor,
          size: 24,
        ),
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.primaryColor,
          shape: CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        tooltip: 'Send message',
      );
    } else {
      // Microphone button - visible only when no text
      if (widget.onMicPressed != null) {
        return IconButton(
          onPressed: () => _startVoiceRecording(audioService, provider),
          icon: Icon(Icons.mic, size: 24),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: AppTheme.primaryColor,
            shape: CircleBorder(),
            padding: EdgeInsets.zero,
          ),
          tooltip: 'Voice message',
        );
      }
      return const SizedBox.shrink();
    }
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

  /// Start voice recording with enhanced UI
  Future<void> _startVoiceRecording(
      AudioInputService audioService, AiChatProvider provider) async {
    // Check if already recording or processing
    if (audioService.isRecording || audioService.isProcessing) {
      AppLogger.w('🎤 Already recording or processing',
          category: LogCategory.voice);
      return;
    }

    // Try to reset the service if there's an error from previous attempt
    if (audioService.hasError) {
      AppLogger.i('🎤 Resetting service due to previous error',
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

    // Start recording - the service will initialize itself if needed
    await audioService.startRecording(
      onResult: (AudioInputResult result) {
        // Send voice message with both audio and transcript
        _sendVoiceMessage(result, provider);
      },
      onTranscriptUpdate: (String transcript) {
        // Just log the transcript - it will be shown in the voice status display
        AppLogger.d('🎤 Live transcript update: "$transcript"',
            category: LogCategory.voice);
      },
    );
    HapticFeedback.lightImpact();
  }

  /// Stop voice recording and send
  void _stopVoiceRecording(AudioInputService audioService) {
    audioService.stopRecording();
    HapticFeedback.mediumImpact();
  }

  /// Cancel voice recording without sending
  void _cancelVoiceRecording(AudioInputService audioService) {
    // Clear the transcript from text field
    widget.messageController.clear();

    // Cancel the recording (this will clean up temp files and reset state)
    audioService.cancelRecording();

    AppLogger.i('🎤 Voice recording cancelled by user',
        category: LogCategory.voice);
    HapticFeedback.lightImpact();
  }

  /// Send voice message to AI chat
  void _sendVoiceMessage(AudioInputResult result, AiChatProvider provider) {
    // Clear the text field since we're sending a voice message
    widget.messageController.clear();

    // Send voice message to AI chat
    // localAudioPath is passed for direct Gemini processing (faster!)
    provider.sendVoiceMessage(
      transcript: result.transcript,
      localAudioPath: result.localAudioPath, // For Gemini direct processing
      audioUrl: result.audioUrl, // For playback (uploaded in background)
      durationInSeconds: result.durationInSeconds,
    );

    HapticFeedback.lightImpact();
  }
}
