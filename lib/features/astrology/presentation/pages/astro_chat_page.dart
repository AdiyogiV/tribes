import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/features/chat/presentation/widgets/chat_message_widgets.dart';
import 'package:aurogram/features/astrology/presentation/widgets/astro_chat_input.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/services/media/audio_input_service.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_provider.dart';

/// Data class for passing voice message from entry pages
class InitialVoiceMessage {
  final String transcript;
  final String? localAudioPath;
  final String? audioUrl;
  final int durationInSeconds;

  const InitialVoiceMessage({
    required this.transcript,
    this.localAudioPath,
    this.audioUrl,
    required this.durationInSeconds,
  });
}

/// Pushable chat page for astrology conversations
/// Opens on top of astrology pages (profile, daily insight)
/// User can pop back to the originating page
class AstroChatPage extends StatefulWidget {
  final Map<String, dynamic> astrologyContext;
  final String? initialMessage;

  /// Voice message recorded from entry page - will be processed on load
  final InitialVoiceMessage? initialVoiceMessage;

  /// 'astrology' (default) or 'wellness' - backend uses this to choose persona and context
  final String chatSource;

  const AstroChatPage({
    super.key,
    required this.astrologyContext,
    this.initialMessage,
    this.initialVoiceMessage,
    this.chatSource = 'astrology',
  });

  @override
  State<AstroChatPage> createState() => _AstroChatPageState();
}

class _AstroChatPageState extends State<AstroChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Track expansion state for search results
  final Map<String, bool> _searchResultsExpansionState = {};

  // Track message count to only scroll when new messages arrive
  int _lastMessageCount = 0;

  // Store provider reference for safe disposal
  AiChatProvider? _providerRef;

  @override
  void initState() {
    super.initState();

    // Initialize chat with astrology context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store provider reference for use in dispose()
    _providerRef = Provider.of<AiChatProvider>(context, listen: false);
  }

  void _initializeChat() {
    final provider = Provider.of<AiChatProvider>(context, listen: false);

    // Set astrology context and chat source (wellness vs astrology)
    provider.setAstrologyContext(widget.astrologyContext);
    provider.setChatSource(widget.chatSource);

    // Start new session
    provider.startNewSession();

    // Send initial text message if provided
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      provider.sendMessage(widget.initialMessage!);
    }

    // Process initial voice message if provided (from entry page recording)
    if (widget.initialVoiceMessage != null) {
      final voice = widget.initialVoiceMessage!;
      AppLogger.i('🎤 Processing voice message from entry page',
          category: LogCategory.voice,
          data: {
            'hasTranscript': voice.transcript.isNotEmpty,
            'hasLocalAudio': voice.localAudioPath != null,
            'duration': voice.durationInSeconds,
          });

      // Set up callback for background audio upload (entry page didn't set this)
      // This ensures the audio URL is updated after upload completes
      final audioService =
          Provider.of<AudioInputService>(context, listen: false);
      audioService.setOnAudioUrlUploaded((audioUrl) {
        provider.updateLastVoiceMessageUrl(audioUrl);
        AppLogger.i('🔗 Audio URL updated after background upload',
            category: LogCategory.voice, data: {'audioUrl': audioUrl});
      });

      // Set up callback for when upload is skipped (logged out user or failure)
      audioService.setOnAudioUploadSkipped(() {
        provider.markLastVoiceMessageAsLocalOnly();
      });

      provider.sendVoiceMessage(
        transcript: voice.transcript,
        localAudioPath: voice.localAudioPath,
        audioUrl: voice.audioUrl,
        durationInSeconds: voice.durationInSeconds,
      );
    }

    AppLogger.i('Astro chat initialized', data: {
      'hasInitialMessage': widget.initialMessage != null,
      'hasInitialVoice': widget.initialVoiceMessage != null,
      'sunSign': widget.astrologyContext['sunSign'],
      'hasAscendant': widget.astrologyContext['ascendant'] != null,
      'hasPlanets': widget.astrologyContext['planets'] != null,
      'hasDasha': widget.astrologyContext['currentDasha'] != null,
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();

    // Clear astrology context AFTER the current frame completes
    // This avoids "setState() called when widget tree was locked" error
    final providerToClean = _providerRef;
    if (providerToClean != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        providerToClean.clearAstrologyContext();
        providerToClean.clearChatSource();
      });
    }

    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final provider = Provider.of<AiChatProvider>(context, listen: false);
    provider.sendMessage(text);

    _messageController.clear();
    _focusNode.unfocus();
    HapticFeedback.lightImpact();

    // Scroll to bottom
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = Theme.of(context).colorScheme.surface;

    // Brown astrology theme colors - use primary color
    final Color brownColor = AppTheme.astroBrown(isDark);

    return Scaffold(
      backgroundColor: surface,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  surface,
                  surface.withValues(alpha: isDark ? 0.98 : 0.96),
                  surface.withValues(alpha: isDark ? 0.96 : 0.92),
                ],
              ),
            ),
          ),
          // Main content
          Column(
            children: [
              // App bar
              _buildAppBar(brownColor, isDark),
              // Chat messages
              Expanded(
                child: GestureDetector(
                  onTap: () => _focusNode.unfocus(),
                  child: _buildChatContent(),
                ),
              ),
            ],
          ),
          // Chat input at bottom - with voice enabled
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: AstroChatInput(
                messageController: _messageController,
                focusNode: _focusNode,
                onSendMessage: _sendMessage,
                hintText: 'Ask anything',
                enableVoice: true,
                onMicPressed: () {
                  AppLogger.i('🎤 Astro chat mic pressed',
                      category: LogCategory.voice);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(Color brownColor, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: brownColor.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: brownColor,
              size: 22,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          // Title with icon (astrology or wellness)
          Icon(
            widget.chatSource == 'wellness' ? Icons.spa : Icons.auto_awesome,
            color: brownColor,
            size: 20,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatSource == 'wellness'
                      ? 'Wellness'
                      : 'Astro Guidance',
                  style: TextStyle(
                    color: brownColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getSubtitle(),
                  style: TextStyle(
                    color: brownColor.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSubtitle() {
    final signs = <String>[];
    if (widget.astrologyContext['sunSign'] != null) {
      signs.add('☉ ${widget.astrologyContext['sunSign']}');
    }
    if (widget.astrologyContext['moonSign'] != null) {
      signs.add('☽ ${widget.astrologyContext['moonSign']}');
    }
    if (widget.astrologyContext['ascendant'] != null) {
      signs.add('↑ ${widget.astrologyContext['ascendant']}');
    }
    return signs.take(3).join(' • ');
  }

  Widget _buildChatContent() {
    return Consumer<AiChatProvider>(
      builder: (context, provider, _) {
        // Only scroll to bottom when NEW messages arrive, not on every rebuild
        // This prevents scrolling when user expands/collapses thoughts
        final currentCount = provider.messages.length;
        if (currentCount > _lastMessageCount) {
          _lastMessageCount = currentCount;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }

        if (provider.messages.isEmpty) {
          _lastMessageCount = 0; // Reset counter when no messages
          return _buildWelcomeMessage();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          itemCount: provider.messages.length,
          itemBuilder: (context, index) {
            final message = provider.messages[index];

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChatMessageWidgets.buildMessage(
                  message,
                  provider,
                  _searchResultsExpansionState,
                  (messageId, isExpanded) {
                    setState(() {
                      _searchResultsExpansionState[messageId] = isExpanded;
                    });
                  },
                  context,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWelcomeMessage() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color brownColor = AppTheme.astroBrown(isDark);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: brownColor.withValues(alpha: 0.6),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              'Your Personal Astrologer',
              style: TextStyle(
                color: brownColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Ask questions about your birth chart,\nplanetary transits, and life guidance',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: brownColor.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
