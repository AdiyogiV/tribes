import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/services/media/audio_input_service.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/features/ai_chat/presentation/widgets/ai_chat_input.dart';
import 'package:aurogram/features/ai_chat/presentation/widgets/ai_chat_message_list.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_provider.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/ayurveda/domain/ayurveda_service.dart';
import 'package:aurogram/features/astrology/data/utils/astrology_context_builder.dart';

/// Dedicated AI chat screen — pushed from Baba dashboard or history.
///
/// Follows [SpaceChatScreen] patterns:
/// - Mobile: `Navigator.push(CupertinoPageRoute)`.
/// - Desktop: rendered inline via `embedded: true` (still gets its own Scaffold).
class AiChatPage extends StatefulWidget {
  /// Load an existing conversation from Firestore.
  final String? conversationId;

  /// Auto-send this text message on open (from dashboard text input).
  final String? initialMessage;

  /// Auto-send this voice result on open (from dashboard mic recording).
  final AudioInputResult? initialVoiceResult;

  /// Desktop inline mode — hides back button, adjusts top spacing.
  final bool embedded;

  const AiChatPage({
    super.key,
    this.conversationId,
    this.initialMessage,
    this.initialVoiceResult,
    this.embedded = false,
  });

  @override
  State<AiChatPage> createState() => AiChatPageState();
}

class AiChatPageState extends State<AiChatPage> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  AiChatProvider? _provider;

  // Streaming scroll state
  bool _wasStreaming = false;
  DateTime _lastScrollTime = DateTime.now();
  bool _isScrollAnimating = false;
  int _lastMessageContentLength = 0;

  // Scroll FAB state
  bool _isAtBottom = true;

  // Keyboard tracking
  double _previousKeyboardHeight = 0;
  static const double _keyboardScrollAmount = 180;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScrollChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider = Provider.of<AiChatProvider>(context, listen: false);
      _provider!.addListener(_onProviderChanged);
      _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
    final provider = _provider;
    if (provider == null) return;

    // Resolve the audio service BEFORE any await (context can't cross the async
    // gap below). Only needed for the initial-voice path.
    final audioService = widget.initialVoiceResult != null
        ? Provider.of<AudioInputService>(context, listen: false)
        : null;

    // Auto-load user's astrology + ayurveda context so the AI can give
    // personalized responses when the question warrants it.
    await _loadUserContext();

    if (widget.conversationId != null) {
      // Load existing conversation
      provider.loadConversation(widget.conversationId!);
      _scrollToBottomAfterLoad();
    } else if (widget.initialMessage != null) {
      // Start new session and send the text
      provider.startNewSession();
      provider.sendMessage(widget.initialMessage!);
    } else if (widget.initialVoiceResult != null) {
      // Start new session and send the voice result (recorded on dashboard).
      provider.startNewSession();
      final result = widget.initialVoiceResult!;

      // Wire the background-upload callbacks to THIS provider so a voice whose
      // audio is still uploading resumes/cancels correctly here — don't rely on
      // whoever navigated us having set them (keeps the path self-contained).
      audioService?.setOnAudioUrlUploaded(provider.updateLastVoiceMessageUrl);
      audioService?.setOnAudioUploadSkipped(provider.markLastVoiceMessageAsLocalOnly);

      provider.sendVoiceMessage(
        transcript: result.transcript,
        localAudioPath: result.localAudioPath,
        audioUrl: result.audioUrl,
        durationInSeconds: result.durationInSeconds,
      );
    } else {
      // Blank new chat
      provider.startNewSession();
    }
  }

  /// Load user's astrology + ayurveda profiles into chat context.
  /// Services cache aggressively so this is typically instant (<50ms).
  /// The AI uses this to give personalized answers only when relevant.
  Future<void> _loadUserContext() async {
    // Skip if context already set (e.g. from AstroChatPage)
    if (_provider?.astrologyContext != null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // Guest user — generic chat is fine

    try {
      final astroService = AstrologyService();
      final ayurvedaService = AyurvedaService();

      // Fetch cached profiles in parallel
      final results = await Future.wait([
        astroService.getProfile(uid),
        ayurvedaService.getProfile(uid),
      ]);

      final profile = results[0] as AstrologyProfile?;
      final ayurveda = results[1] as AyurvedaProfile?;

      if (!mounted) return;

      if (profile != null || (ayurveda != null && ayurveda.hasData)) {
        final context = AstrologyContextBuilder.buildContext(
          profile: profile,
          ayurveda: ayurveda,
        );
        _provider?.setAstrologyContext(context);

        AppLogger.i('Loaded user context for Baba chat', data: {
          'hasProfile': profile != null,
          'hasAyurveda': ayurveda?.hasData ?? false,
          'sunSign': profile?.sunSign,
          'prakriti': ayurveda?.prakritiType,
        });
      }
    } catch (e) {
      // Context loading is non-critical — chat works fine without it
      AppLogger.e('Failed to load user context for chat',
          category: LogCategory.ui, error: e);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider?.removeListener(_onProviderChanged);
    _scrollController.removeListener(_onScrollChanged);
    _messageController.dispose();
    _focusNode.dispose();
    _contentFocusNode.dispose();
    _scrollController.dispose();

    // Clean up auto-loaded context (same pattern as AstroChatPage)
    final providerToClean = _provider;
    if (providerToClean != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        providerToClean.clearAstrologyContext();
      });
    }

    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Provider listener — streaming scroll logic (side-effect only)
  // ─────────────────────────────────────────────────────────────

  void _onProviderChanged() {
    if (!mounted) return;
    final provider = _provider;
    if (provider == null) return;

    final currentContentLength = provider.messages.isNotEmpty
        ? provider.messages.last.content.length
        : 0;

    if (provider.isStreaming) {
      if (!_wasStreaming) {
        // Streaming just started — jump to bottom
        _wasStreaming = true;
        _lastMessageContentLength = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToBottom();
        });
      } else if (currentContentLength != _lastMessageContentLength) {
        // Content grew — smooth scroll
        _lastMessageContentLength = currentContentLength;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _smoothScrollDuringStreaming();
        });
      }
    } else if (_wasStreaming) {
      // Streaming just ended — final scroll
      _wasStreaming = false;
      _lastMessageContentLength = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Scroll listener — FAB visibility
  // ─────────────────────────────────────────────────────────────

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final nearBottom = pos.maxScrollExtent - pos.pixels < 100;
    if (nearBottom != _isAtBottom) {
      setState(() => _isAtBottom = nearBottom);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Keyboard observer
  // ─────────────────────────────────────────────────────────────

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0 && _previousKeyboardHeight == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          final pos = _scrollController.position;
          final target = (pos.pixels + _keyboardScrollAmount)
              .clamp(pos.minScrollExtent, pos.maxScrollExtent);
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _previousKeyboardHeight = keyboardHeight;
  }

  // ─────────────────────────────────────────────────────────────
  // Scroll helpers
  // ─────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToBottomInstant() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _scrollToBottomAfterLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _contentFocusNode.requestFocus();
      _scrollToBottomInstant();
    });
  }

  void _smoothScrollDuringStreaming() {
    if (!_scrollController.hasClients || _isScrollAnimating) return;

    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    // Don't chase if user scrolled far up
    if (maxScroll - currentScroll >= 500) return;
    // Already at bottom
    if (maxScroll - currentScroll < 5) return;

    final now = DateTime.now();
    final throttleMs = kIsWeb ? 50 : 100;
    if (now.difference(_lastScrollTime).inMilliseconds < throttleMs) return;
    _lastScrollTime = now;

    _isScrollAnimating = true;
    final duration = kIsWeb
        ? const Duration(milliseconds: 80)
        : const Duration(milliseconds: 150);
    _scrollController
        .animateTo(maxScroll, duration: duration, curve: Curves.easeOut)
        .then((_) => _isScrollAnimating = false)
        .catchError((_) => _isScrollAnimating = false);
  }

  // ─────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    try {
      _provider?.sendMessage(text);
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      HapticFeedback.lightImpact();
    } catch (e) {
      AppLogger.e('Error sending message', category: LogCategory.ui, error: e);
    }
  }

  void _startNewChat() {
    try {
      _provider?.startNewSession();
      HapticFeedback.lightImpact();
    } catch (e) {
      AppLogger.e('Error starting new chat', category: LogCategory.ui, error: e);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Build — ALWAYS a Scaffold (even embedded)
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldColor =
        isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: scaffoldColor,
      resizeToAvoidBottomInset: true,
      appBar: widget.embedded
          ? _buildEmbeddedAppBar(context, isDark)
          : _buildGlassAppBar(context, isDark),
      body: _buildBody(context),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Glass AppBar — matches SpaceChatAppBar (pushed route)
  // ─────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildGlassAppBar(BuildContext context, bool isDark) {
    final headerBase = isDark ? AppTheme.cardDarkColor : Colors.white;
    final isDesktop = Responsive.isDesktop(context);

    return PreferredSize(
      preferredSize: const Size.fromHeight(54),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 700 : double.infinity,
          ),
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        headerBase.withValues(alpha: isDark ? 0.85 : 0.90),
                        headerBase.withValues(alpha: isDark ? 0.80 : 0.85),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : headerBase.withValues(alpha: 0.32),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 54,
                      child: Row(
                        children: [
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Image.asset(
                            'assets/images/aryabhatt.png',
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Aryabhatt',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _startNewChat,
                            icon: Icon(
                              Icons.add_rounded,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
                            tooltip: 'New Chat',
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Embedded AppBar — no back button, glass style
  // ─────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildEmbeddedAppBar(BuildContext context, bool isDark) {
    final headerBase = isDark ? AppTheme.cardDarkColor : Colors.white;

    return PreferredSize(
      preferredSize: const Size.fromHeight(54),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    headerBase.withValues(alpha: isDark ? 0.85 : 0.90),
                    headerBase.withValues(alpha: isDark ? 0.80 : 0.85),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : headerBase.withValues(alpha: 0.32),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 54,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Image.asset(
                        'assets/images/aryabhatt.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Aryabhatt',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _startNewChat,
                        icon: Icon(
                          Icons.add_rounded,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                        tooltip: 'New Chat',
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Body — matches SpaceChatScreen structure (Stack with layers)
  // ─────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxContentWidth = widget.embedded ? 1000.0 : 700.0;
          final contentPadding =
              Responsive.horizontalPaddingFor(constraints.maxWidth, maxContentWidth);

          return Stack(
            children: [
              // Message list — fills entire area
              Positioned.fill(
                child: Focus(
                  focusNode: _contentFocusNode,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // Top spacing — accounts for AppBar + safe area
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.of(context).padding.top + 54 + 8,
                        ),
                      ),

                      // Messages (virtualized)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: contentPadding),
                        sliver: const AiChatMessageList(),
                      ),

                      // Bottom spacing for input overlay
                      const SliverToBoxAdapter(child: SizedBox(height: 170)),
                    ],
                  ),
                ),
              ),

              // Input area — fixed at bottom, centered
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? maxContentWidth : double.infinity,
                    ),
                    child: SafeArea(
                      top: false,
                      child: AiChatInput(
                        messageController: _messageController,
                        focusNode: _focusNode,
                        onSendMessage: _sendMessage,
                      ),
                    ),
                  ),
                ),
              ),

              // Scroll-to-bottom FAB
              if (!_isAtBottom)
                Positioned(
                  bottom: 140,
                  right: 16 + contentPadding,
                  child: _buildScrollToBottomFAB(),
                ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Scroll-to-bottom FAB — matches SpaceChatScrollFAB exactly
  // ─────────────────────────────────────────────────────────────

  Widget _buildScrollToBottomFAB() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBase = isDark ? AppTheme.cardDarkColor : Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (!kIsWeb) HapticFeedback.lightImpact();
              _scrollToBottom();
            },
            borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          barBase.withValues(alpha: 0.75),
                          barBase.withValues(alpha: 0.70),
                        ]
                      : [
                          barBase.withValues(alpha: 0.90),
                          barBase.withValues(alpha: 0.85),
                        ],
                ),
                border: isDark
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.0,
                      )
                    : null,
              ),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.primaryColor,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
