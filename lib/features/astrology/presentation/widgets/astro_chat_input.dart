import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/shared/services/media/audio_input_service.dart';
import 'package:aurogram/features/astrology/presentation/pages/astro_chat_page.dart';
import 'package:aurogram/features/baba/domain/baba_insets.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Chat input widget for astrology pages with voice support.
///
/// This widget supports two modes:
/// 1. **In-chat mode** (isEntryPage: false): Voice is processed in-place
/// 2. **Entry page mode** (isEntryPage: true): Tapping mic navigates to AstroChatPage
///
/// For entry pages (astrology_details, daily_insight), use [isEntryPage: true]
/// and provide [astrologyContextBuilder] for navigation.
class AstroChatInput extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode focusNode;
  final VoidCallback onSendMessage;
  final String hintText;

  /// Enable voice input functionality (mic button + recording)
  final bool enableVoice;

  /// Optional callback when mic is pressed (for logging/analytics)
  final VoidCallback? onMicPressed;

  /// If true, tapping mic will navigate to AstroChatPage after recording
  /// Set this to true for entry pages (astrology_details, daily_insight)
  final bool isEntryPage;

  /// Callback to build astrology context at the time of navigation
  /// Use this instead of static context to get the latest profile data
  final Map<String, dynamic> Function()? astrologyContextBuilder;

  /// When opening AstroChatPage from this input (e.g. mic), pass this to backend ('astrology' or 'wellness')
  final String chatSource;

  const AstroChatInput({
    super.key,
    required this.messageController,
    required this.focusNode,
    required this.onSendMessage,
    this.hintText = 'Ask anything',
    this.enableVoice = false,
    this.onMicPressed,
    this.isEntryPage = false,
    this.astrologyContextBuilder,
    this.chatSource = 'astrology',
  });

  @override
  State<AstroChatInput> createState() => _AstroChatInputState();
}

class _AstroChatInputState extends State<AstroChatInput> {
  bool _isRecordingForNavigation = false;

  // Tell Baba how tall this input bar is so his floating presence sits ABOVE
  // it instead of overlapping. Unique id so multiple bars never clobber.
  late final String _insetId = 'astroInput-${identityHashCode(this)}';

  void _reportHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final h = context.size?.height ?? 0;
      BabaInsets.instance.set(_insetId, h);
    });
  }

  @override
  void dispose() {
    BabaInsets.instance.clear(_insetId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-measure each build; BabaInsets.set no-ops when the height is unchanged.
    _reportHeight();
    // If this is an entry page with voice enabled, we need to handle recording ourselves
    // because we want to navigate after recording, not process in place
    if (widget.enableVoice &&
        widget.isEntryPage &&
        widget.astrologyContextBuilder != null) {
      return Consumer<AudioInputService>(
        builder: (context, audioService, _) {
          return _buildEntryPageInput(audioService);
        },
      );
    }

    // Normal mode - delegate to TransparentToolbox
    return TransparentToolbox.astroChat(
      messageController: widget.messageController,
      focusNode: widget.focusNode,
      onSend: widget.onSendMessage,
      hintText: widget.hintText,
      enableVoice: widget.enableVoice,
      onMicPressed: widget.onMicPressed,
    );
  }

  /// Build entry page input with mic that navigates after recording
  Widget _buildEntryPageInput(AudioInputService audioService) {
    final isRecording = audioService.isRecording || _isRecordingForNavigation;

    return TransparentToolbox(
      content: Row(
        children: [
          Expanded(
            child: isRecording ? _buildRecordingIndicator() : _buildTextField(),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          isRecording
              ? _buildRecordingControls(audioService)
              : _buildNormalControls(audioService),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: widget.messageController,
      focusNode: widget.focusNode,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TransparentToolbox.hintTextStyle,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: TransparentToolbox.inputContentPadding,
        isDense: true,
      ),
      style: TransparentToolbox.inputTextStyle,
      maxLines: 1,
      textInputAction: TextInputAction.send,
      textCapitalization: TextCapitalization.sentences,
      autofocus: false,
      onSubmitted: (_) {
        if (widget.messageController.text.trim().isNotEmpty) {
          widget.onSendMessage();
        }
      },
    );
  }

  Widget _buildRecordingIndicator() {
    return Row(
      children: [
        // Animated dots
        _AnimatedRecordingDots(),
        const SizedBox(width: AppDimensions.spacingMd),
        // Flexible so a tight width ellipsizes instead of overflowing the row.
        Flexible(
          child: Text(
            'Recording...',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.red[400],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalControls(AudioInputService audioService) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final hasText = widget.messageController.text.trim().isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mic button
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: () => _startRecordingForNavigation(audioService),
            icon: const Icon(Icons.mic, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: isDark ? Colors.brown[300] : Colors.brown[700],
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Voice message',
          ),
        ),
        // Cow send button
        SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: hasText
                  ? () {
                      HapticFeedback.lightImpact();
                      widget.onSendMessage();
                    }
                  : null,
              customBorder: const CircleBorder(),
              child: Center(
                child: Opacity(
                  opacity: hasText ? 1.0 : 0.4,
                  child: Image.asset(
                    'assets/images/aurobhatt.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (_, __, ___) => Icon(
                      CupertinoIcons.paperplane_fill,
                      color: Colors.brown,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

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
            onPressed: () => _cancelRecording(audioService),
            icon: const Icon(Icons.close, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
              foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Cancel',
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        // Send button
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: () => _stopAndNavigate(audioService),
            icon: const Icon(Icons.send, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.brown[300] : Colors.brown[700],
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Send',
          ),
        ),
      ],
    );
  }

  Future<void> _startRecordingForNavigation(
      AudioInputService audioService) async {
    if (audioService.isRecording || audioService.isProcessing) return;

    if (audioService.hasError) {
      await audioService.resetService();
    }

    audioService.clearState();

    setState(() {
      _isRecordingForNavigation = true;
    });

    // Start recording - we'll handle the result manually
    await audioService.startRecording(
      onResult: (result) {
        // Navigate to AstroChatPage with the audio
        _navigateWithAudio(result);
      },
      onTranscriptUpdate: (transcript) {
        AppLogger.d('🎤 Entry page transcript: "$transcript"',
            category: LogCategory.voice);
      },
    );

    HapticFeedback.lightImpact();
    widget.onMicPressed?.call();
  }

  void _stopAndNavigate(AudioInputService audioService) {
    audioService.stopRecording();
    HapticFeedback.mediumImpact();
  }

  void _cancelRecording(AudioInputService audioService) {
    audioService.cancelRecording();
    setState(() {
      _isRecordingForNavigation = false;
    });
    HapticFeedback.lightImpact();
  }

  void _navigateWithAudio(AudioInputResult result) {
    if (!mounted) return;

    setState(() {
      _isRecordingForNavigation = false;
    });

    // Build astrology context at the moment of navigation (gets latest profile data)
    final astroContext = widget.astrologyContextBuilder!();

    // Navigate to AstroChatPage and process voice there
    context.push('/astrology/chat', extra: {
      'astrologyContext': astroContext,
      'initialVoiceMessage': InitialVoiceMessage(
        transcript: result.transcript,
        localAudioPath: result.localAudioPath,
        audioUrl: result.audioUrl,
        durationInSeconds: result.durationInSeconds,
      ),
      'chatSource': widget.chatSource,
    });
  }
}

/// Simple animated recording dots
class _AnimatedRecordingDots extends StatefulWidget {
  @override
  State<_AnimatedRecordingDots> createState() => _AnimatedRecordingDotsState();
}

class _AnimatedRecordingDotsState extends State<_AnimatedRecordingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animValue = ((_controller.value + delay) % 1.0);
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
}
