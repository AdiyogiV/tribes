import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/providers/ai_chat_provider.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/chat/chat_message_widgets.dart';
import 'package:aurogram/widgets/chat/chat_input_area.dart';
import 'package:aurogram/pages/ai/recent_conversations_page.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/chat/chat_dialogs.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/models/ayurveda_profile.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/services/astrology_service.dart';
import 'package:aurogram/services/ayurveda_service.dart';
import 'package:aurogram/services/sky_positions_service.dart';
import 'package:aurogram/widgets/astrology/timeline/muhurat_timeline_widget.dart';
import 'package:aurogram/widgets/astrology/cards/cosmic_date_time_card.dart';
import 'package:aurogram/widgets/astrology/cards/cosmic_insight_card.dart';
import 'package:aurogram/widgets/astrology/cards/cosmic_panchang_card.dart';
import 'package:aurogram/widgets/astrology/cards/upcoming_events_card.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/widgets/cosmic_dashboard/widgets/cosmic_sky_chart_card.dart';
import 'package:aurogram/widgets/cosmic_dashboard/cosmic_dashboard_data.dart';
import 'package:intl/intl.dart';

class HolyCowPage extends StatefulWidget {
  const HolyCowPage({super.key});

  @override
  HolyCowPageState createState() => HolyCowPageState();
}

class HolyCowPageState extends State<HolyCowPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController messageController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  /// Focus node for the scroll/content area. We give it focus when loading a
  /// conversation so the text field never receives focus (avoids keyboard opening).
  final FocusNode _contentFocusNode = FocusNode();
  final ScrollController scrollController = ScrollController();
  final bool _isSearchingChats = false;
  final Map<String, bool> _searchResultsExpansionState = {};
  final Map<String, bool> _thoughtExpansionState = {};

  // Track if we need to scroll to bottom after loading a conversation
  bool _shouldScrollAfterLoad = false;

  // Track streaming state for smooth auto-scroll
  bool _wasStreaming = false;
  DateTime _lastScrollTime = DateTime.now();
  bool _isScrollAnimating = false;
  int _lastMessageContentLength = 0; // Track content length for scroll triggers

  // Track keyboard visibility
  double _previousKeyboardHeight = 0;

  /// When keyboard opens, scroll up by this much (px) so input is visible.
  static const double _keyboardScrollAmount = 180;

  late AnimationController fadeController;
  late AnimationController typingController;
  late Animation<double> fadeAnimation;
  late Animation<double> typingAnimation;

  // Cosmic Dashboard state
  static const int _sliderRangeDays = 30;
  static const int _maxSkyLoadRetries = 2;
  static const Duration _retryBaseDelay = Duration(seconds: 2);
  static const Duration _cachePopulationDelay = Duration(seconds: 3);
  
  final _astrologyService = AstrologyService();
  final _ayurvedaService = AyurvedaService();
  final _skyService = SkyPositionsService();
  final _user = FirebaseAuth.instance.currentUser;
  
  // Sky slider state - using ValueNotifier to avoid full widget rebuilds
  final ValueNotifier<double> _sliderValueNotifier = ValueNotifier(0.5);
  final ValueNotifier<DateTime> _sliderDateNotifier = ValueNotifier(DateTime.now());
  
  // Consolidated loading state
  DashboardLoadingState _loadingState = const DashboardLoadingState();
  
  // Transit overlay state
  bool _showTransitOverlay = false;
  double _chartBlendValue = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen for focus changes to scroll when keyboard appears
    focusNode.addListener(_onFocusChange);

    fadeController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    typingController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: fadeController, curve: Curves.easeInOut));

    typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: typingController, curve: Curves.easeInOut),
    );

    fadeController.forward();
    typingController.repeat();

    // Load cosmic dashboard data
    if (_user != null) {
      _loadSkyPositions();
      _loadUpcomingEvents();
      _loadGlobalMuhurat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    focusNode.removeListener(_onFocusChange);
    fadeController.dispose();
    typingController.dispose();
    messageController.dispose();
    focusNode.dispose();
    _contentFocusNode.dispose();
    scrollController.dispose();
    _sliderValueNotifier.dispose();
    _sliderDateNotifier.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (focusNode.hasFocus) {
      // Input focused - keyboard will appear, nudge scroll up so input is visible
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && scrollController.hasClients) {
          final pos = scrollController.position;
          final target = (pos.pixels + _keyboardScrollAmount)
              .clamp(pos.minScrollExtent, pos.maxScrollExtent);
          scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Check if keyboard appeared
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0 && _previousKeyboardHeight == 0) {
      // Keyboard just appeared - nudge scroll up by ~400px (not full scroll to bottom)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scrollController.hasClients) {
          final pos = scrollController.position;
          final target = (pos.pixels + _keyboardScrollAmount)
              .clamp(pos.minScrollExtent, pos.maxScrollExtent);
          scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _previousKeyboardHeight = keyboardHeight;
  }

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToBottomInstant() {
    if (scrollController.hasClients) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }

  /// Smooth scroll during streaming - follows content smoothly to bottom
  /// Optimized for web: Uses shorter duration and lower throttle for smoother experience
  void _smoothScrollDuringStreaming() {
    if (!scrollController.hasClients) return;

    // Skip if already animating to prevent jerky overlapping animations
    if (_isScrollAnimating) return;

    final position = scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    // Only auto-scroll if user is within 500px of bottom (user hasn't scrolled up)
    final isNearBottom = maxScroll - currentScroll < 500;
    if (!isNearBottom) return;

    final scrollDistance = maxScroll - currentScroll;
    if (scrollDistance < 5) return; // Min scroll

    // Throttle - shorter on web for smoother streaming experience
    final now = DateTime.now();
    final throttleMs = kIsWeb ? 50 : 100;
    if (now.difference(_lastScrollTime).inMilliseconds < throttleMs) return;
    _lastScrollTime = now;

    // Smooth animation to bottom - faster on web
    _isScrollAnimating = true;
    final duration = kIsWeb
        ? const Duration(milliseconds: 80)
        : const Duration(milliseconds: 150);
    scrollController
        .animateTo(maxScroll, duration: duration, curve: Curves.easeOut)
        .then((_) {
      _isScrollAnimating = false;
    }).catchError((_) {
      _isScrollAnimating = false;
    });
  }

  void _sendMessage() {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final provider = Provider.of<AiChatProvider>(context, listen: false);
      provider.sendMessage(text);
      messageController.clear();

      // Scroll to bottom after sending
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      AppLogger.e('Error sending message', category: LogCategory.ui, error: e);
    }
  }

  void _startNewChat() {
    try {
      final provider = Provider.of<AiChatProvider>(context, listen: false);
      provider.startNewSession();

      setState(() {
        _shouldScrollAfterLoad = false;
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      AppLogger.e(
        'Error starting new chat',
        category: LogCategory.ui,
        error: e,
      );
    }
  }

  void _onMicPressed() {
    AppLogger.i('Microphone button pressed', category: LogCategory.ui);
    // Voice logic is now handled directly in ChatInputArea widget
  }

  // ─────────────────────────────────────────────────────────────
  // Cosmic Dashboard Data Loading Methods
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadUpcomingEvents() async {
    if (_loadingState.events == DashboardLoadState.loading) return;
    setState(() {
      _loadingState =
          _loadingState.copyWith(events: DashboardLoadState.loading);
    });

    final success = await _skyService.fetchUpcomingEvents();

    if (mounted) {
      setState(() {
        _loadingState = _loadingState.copyWith(
          events:
              success ? DashboardLoadState.loaded : DashboardLoadState.error,
        );
      });

      if (success) {
        AppLogger.i('HolyCow: Upcoming events loaded',
            category: LogCategory.ui,
            data: {
              'signIngresses': _skyService.signIngresses.length,
              'retrogrades': _skyService.retrogrades.length,
            });
      }
    }
  }

  Future<void> _loadSkyPositions({bool isRetry = false}) async {
    if (_loadingState.isSkyLoading) return;
    setState(() {
      _loadingState = _loadingState.copyWith(sky: DashboardLoadState.loading);
    });

    AppLogger.d('HolyCow: Loading sky positions for slider',
        category: LogCategory.ui,
        data: {'isRetry': isRetry, 'retryCount': _loadingState.skyRetryCount});

    final success = await _skyService.fetchPositions();

    if (mounted) {
      setState(() {
        _loadingState = _loadingState.copyWith(
          sky: success ? DashboardLoadState.loaded : DashboardLoadState.error,
          skyRetryCount: success ? 0 : _loadingState.skyRetryCount,
        );
      });

      if (success) {
        AppLogger.i('HolyCow: Sky positions loaded successfully',
            category: LogCategory.ui,
            data: {'availableDays': _skyService.availableDays});
      } else {
        AppLogger.w('HolyCow: Failed to load sky positions',
            category: LogCategory.ui,
            data: {
              'retryCount': _loadingState.skyRetryCount,
              'maxRetries': _maxSkyLoadRetries
            });

        // If this is the first attempt and cache is empty, try to populate cache
        if (_loadingState.skyRetryCount == 0 &&
            _skyService.availableDays == 0) {
          await _triggerSkyPositionsCachePopulation();
        }

        // Auto-retry with exponential backoff
        if (_loadingState.skyRetryCount < _maxSkyLoadRetries) {
          final newRetryCount = _loadingState.skyRetryCount + 1;
          setState(() {
            _loadingState =
                _loadingState.copyWith(skyRetryCount: newRetryCount);
          });

          final delay = _retryBaseDelay * newRetryCount;
          AppLogger.d('HolyCow: Scheduling retry after $delay',
              category: LogCategory.ui);
          Future.delayed(delay, () {
            if (mounted && !_loadingState.isSkyLoaded) {
              _loadSkyPositions(isRetry: true);
            }
          });
        }
      }
    }
  }

  Future<void> _triggerSkyPositionsCachePopulation() async {
    try {
      AppLogger.i('HolyCow: Attempting to populate sky positions cache',
          category: LogCategory.ui);

      final functions =
          FirebaseFunctions.instanceFor(region: 'asia-southeast2');
      final callable = functions.httpsCallable('prefetchSkyPositions');
      await callable.call({
        'daysBack': 30,
        'daysAhead': 30,
      });

      // Wait a moment then retry loading
      await Future.delayed(_cachePopulationDelay);
      if (mounted) {
        _loadSkyPositions(isRetry: true);
      }
    } catch (e) {
      AppLogger.e(
          'HolyCow: Failed to trigger sky positions cache population',
          category: LogCategory.ui,
          error: e);
    }
  }

  Future<void> _loadGlobalMuhurat() async {
    if (_loadingState.muhurat == DashboardLoadState.loading || !mounted) return;

    setState(() {
      _loadingState =
          _loadingState.copyWith(muhurat: DashboardLoadState.loading);
    });

    final success = await _skyService.fetchGlobalMuhurat();

    if (!mounted) return;
    setState(() {
      _loadingState = _loadingState.copyWith(
        muhurat: success ? DashboardLoadState.loaded : DashboardLoadState.error,
      );
    });

    if (success) {
      AppLogger.d('HolyCow: Muhurat loaded', category: LogCategory.ui);
    } else {
      AppLogger.w('HolyCow: Muhurat fetch failed',
          category: LogCategory.ui);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Cosmic Dashboard Slider Methods
  // ─────────────────────────────────────────────────────────────

  void _onSliderChanged(double value) {
    _sliderValueNotifier.value = value;
    final daysOffset =
        ((value - 0.5) * 2 * _sliderRangeDays).round();
    _sliderDateNotifier.value = DateTime.now().add(Duration(days: daysOffset));
  }

  void _resetSliderToToday() {
    HapticFeedback.lightImpact();
    _sliderValueNotifier.value = 0.5;
    _sliderDateNotifier.value = DateTime.now();
  }

  void _toggleTransitOverlay() {
    setState(() {
      _showTransitOverlay = !_showTransitOverlay;
      if (_showTransitOverlay) {
        _chartBlendValue = 0.0;
      }
    });
  }

  void _onBlendValueChanged(double value) {
    setState(() => _chartBlendValue = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideLayout = Responsive.isWideLayout(context);

    // In wide layout (desktop / iPad landscape), use master-detail layout
    if (isWideLayout) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: _buildDesktopLayout(),
      );
    }

    // Mobile layout
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Main scrollable content with sliver header
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Consumer<AiChatProvider>(
              builder: (context, provider, _) {
                // Calculate current content length for scroll detection
                final currentContentLength = provider.messages.isNotEmpty
                    ? provider.messages.last.content.length
                    : 0;

                // Auto-scroll during streaming - use post frame callback for reliable timing
                // This ensures layout is complete before scrolling
                if (provider.isStreaming) {
                  // Always scroll when content length changes during streaming
                  if (currentContentLength != _lastMessageContentLength) {
                    _lastMessageContentLength = currentContentLength;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _smoothScrollDuringStreaming();
                    });
                  }
                }

                // Track streaming state for scroll
                if (provider.isStreaming && !_wasStreaming) {
                  _wasStreaming = true;
                  _lastMessageContentLength = 0; // Reset on new stream
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _scrollToBottom();
                  });
                } else if (!provider.isStreaming && _wasStreaming) {
                  _wasStreaming = false;
                  _lastMessageContentLength = 0; // Reset when done
                  // Final scroll to bottom when streaming ends
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _scrollToBottom();
                  });
                }

                final isEmpty = provider.messages.isEmpty;

                return Focus(
                  focusNode: _contentFocusNode,
                  child: CustomScrollView(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // Scrollable header
                      _buildSliverHeader(provider),

                      // Content - use SliverToBoxAdapter to avoid intrinsic dimension issues on web
                      SliverToBoxAdapter(
                        child: isEmpty
                            ? Column(
                                children: [
                                  // Show cosmic dashboard content when no messages
                                  _buildCosmicDashboardContent(),
                                  // Space for input area overlay
                                  ListenableBuilder(
                                    listenable: focusNode,
                                    builder: (context, _) {
                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        height:
                                            focusNode.hasFocus ? 85.0 : 45.0,
                                      );
                                    },
                                  ),
                                ],
                              )
                            : Column(
                                // No outer padding - _buildChatContent() handles its own padding
                                children: [
                                  _buildChatContent(),
                                  // Space for input area + tab bar + extra padding below last message
                                  const SizedBox(height: 220),
                                ],
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Input area positioned as overlay at bottom
          if (!_isSearchingChats)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: ChatInputArea(
                  messageController: messageController,
                  focusNode: focusNode,
                  onSendMessage: _sendMessage,
                  onMicPressed: _onMicPressed,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build desktop master-detail layout with conversation history on left
  Widget _buildDesktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Row(
      children: [
        // Left panel - Conversation history (fixed width)
        SizedBox(
          width: 340,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkColor : Colors.white,
              border: Border(right: BorderSide(color: dividerColor, width: 1)),
            ),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                AppHeaderStyle.buildWideLayoutHeaderSliver(
                  context,
                  title: 'HolyCow',
                  trailing: IconButton(
                    onPressed: _startNewChat,
                    icon: Icon(
                      Icons.add_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                    tooltip: 'New Chat',
                  ),
                ),
              ],
              body: _buildConversationHistoryList(isDark),
            ),
          ),
        ),

        // Right panel - Chat area (fills remaining space)
        Expanded(child: _buildDesktopChatArea()),
      ],
    );
  }

  /// Build conversation history list for desktop sidebar
  Widget _buildConversationHistoryList(bool isDark) {
    return Consumer<AiChatProvider>(
      builder: (context, provider, _) {
        if (!provider.isUserAuthenticated) {
          return _buildSignInPrompt(isDark);
        }

        return StreamBuilder<List<DmConversation>>(
          stream: provider.getRecentAiConversations(limit: 20),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildHistorySkeleton();
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading conversations',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              );
            }

            final conversations = snapshot.data ?? [];

            if (conversations.isEmpty) {
              return _buildEmptyHistory(isDark);
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];

                      return _buildConversationHistoryItem(
                        conversation,
                        isDark,
                        provider,
                      );
                    },
                  ),
                ),
                // Clear all history button at bottom
                _buildClearAllHistoryButton(isDark),
              ],
            );
          },
        );
      },
    );
  }

  /// Build the "Clear All History" button for the desktop sidebar
  Widget _buildClearAllHistoryButton(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: TextButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          ChatDialogs.showClearAllConversationsDialog(context);
        },
        icon: Icon(
          Icons.delete_sweep_outlined,
          size: 18,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
        label: Text(
          'Clear All History',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildConversationHistoryItem(
    DmConversation conversation,
    bool isDark,
    AiChatProvider provider,
  ) {
    // Get a preview of the conversation - prefer firstUserMessage (user's question) over lastMessageContent (AI response)
    final title = conversation.firstUserMessage ??
        conversation.lastMessageContent ??
        'New conversation';
    final truncatedTitle =
        title.length > 40 ? '${title.substring(0, 40)}...' : title;
    final timeAgo = _formatTimeAgo(conversation.lastActivity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          provider.loadConversation(conversation.id);
          _scrollToBottom();
          // Give focus to content so the text field never gets it (avoids keyboard)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _contentFocusNode.requestFocus();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Chat icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      truncatedTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  Widget _buildSignInPrompt(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 48,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to see\nyour chat history',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 48,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start chatting to see\nyour history here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build the main chat area for desktop
  Widget _buildDesktopChatArea() {
    return Consumer<AiChatProvider>(
      builder: (context, provider, _) {
        // Calculate current content length for scroll detection
        final currentContentLength = provider.messages.isNotEmpty
            ? provider.messages.last.content.length
            : 0;

        // Auto-scroll during streaming - use post frame callback for reliable timing
        // This ensures layout is complete before scrolling
        if (provider.isStreaming) {
          // Always scroll when content length changes during streaming
          if (currentContentLength != _lastMessageContentLength) {
            _lastMessageContentLength = currentContentLength;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _smoothScrollDuringStreaming();
            });
          }
        }

        // Track streaming state for scroll
        if (provider.isStreaming && !_wasStreaming) {
          _wasStreaming = true;
          _lastMessageContentLength = 0; // Reset on new stream
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToBottom();
          });
        } else if (!provider.isStreaming && _wasStreaming) {
          _wasStreaming = false;
          _lastMessageContentLength = 0; // Reset when done
          // Final scroll to bottom when streaming ends
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToBottom();
          });
        }

        final isEmpty = provider.messages.isEmpty;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate padding once and use consistently for both content and input
              // Use larger max width (1000px) to better utilize horizontal space
              final horizontalPadding = Responsive.horizontalPaddingFor(
                constraints.maxWidth,
                1000,
              );

              return Stack(
                children: [
                  // Main content - cosmic dashboard when empty, chat when not empty
                  Focus(
                    focusNode: _contentFocusNode,
                    child: CustomScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (isEmpty)
                                  _buildCosmicDashboardContent()
                                else
                                  _buildChatContent(),
                                const SizedBox(height: 200),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Input area at bottom - same padding as content
                  if (!_isSearchingChats)
                    Positioned(
                      bottom: 0,
                      left: horizontalPadding,
                      right: horizontalPadding,
                      child: SafeArea(
                        top: false,
                        child: ChatInputArea(
                          messageController: messageController,
                          focusNode: focusNode,
                          onSendMessage: _sendMessage,
                          onMicPressed: _onMicPressed,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSliverHeader(AiChatProvider provider) {
    // Action button with conditional display
    final hasRealConversation = provider.messages.isNotEmpty;

    // Move buttons to left side (leadingWidget)
    final leadingButton = hasRealConversation
        ? AppHeaderStyle.buildCompactIconButton(
            icon: Icons.add,
            onPressed: _startNewChat,
            tooltip: 'New Chat',
          )
        : AppHeaderStyle.buildCompactIconButton(
            icon: Icons.history_rounded,
            onPressed: _showRecentConversations,
            tooltip: 'Recent Conversations',
          );

    return AppHeaderStyle.buildStandardHeader(
      context: context,
      title: "holycow.ai",
      actionButton: null,
      leadingWidget: leadingButton,
      showSearchField: false,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Cosmic Dashboard Content Builder
  // ─────────────────────────────────────────────────────────────

  Widget _buildCosmicDashboardContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brown = AppTheme.primaryColor;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    if (_user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<AstrologyProfile?>(
      stream: _astrologyService.streamProfile(_user!.uid),
      builder: (context, profileSnapshot) {
        return StreamBuilder<DailyInsight?>(
          stream: _astrologyService.streamTodayInsight(_user!.uid),
          builder: (context, insightSnapshot) {
            return StreamBuilder<AyurvedaProfile?>(
              stream: _ayurvedaService.streamProfile(_user!.uid),
              builder: (context, ayurvedaSnapshot) {
                final profile = profileSnapshot.data;
                final insight = insightSnapshot.data;
                final ayurvedaProfile = ayurvedaSnapshot.data;
                final isLoading = profileSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    profile == null;

                if (isLoading) {
                  return _buildCosmicSkeleton(isDark, brown);
                }

                return _buildCosmicContent(
                  context,
                  isDark,
                  brown,
                  bottomInset,
                  profile,
                  insight,
                  ayurvedaProfile,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCosmicContent(
    BuildContext context,
    bool isDark,
    Color brown,
    double bottomInset,
    AstrologyProfile? profile,
    DailyInsight? insight,
    AyurvedaProfile? ayurvedaProfile,
  ) {
    // Get current planetary positions
    final now = DateTime.now();
    final globalSkyPositions =
        _loadingState.isSkyLoaded ? _skyService.getPositionsForDate(now) : null;
    final insightTransits =
        insight?.astrologicalData?['transits'] as Map<String, dynamic>?;
    final currentPositions =
        globalSkyPositions != null && globalSkyPositions.isNotEmpty
            ? globalSkyPositions
            : insightTransits;

    // Global muhurat (same for all users, calculated at Ujjain)
    final globalMuhurat = _skyService.globalMuhurat;
    final cardColor = isDark ? const Color(0xFF1A1A1C) : Colors.white;

    // Responsive: use LayoutBuilder for width-aware padding
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        // On wider screens, add more horizontal padding to create a centered column effect
        final horizontalPadding = screenWidth > 700
            ? ((screenWidth - 600) / 2).clamp(16.0, 200.0)
            : 16.0;
        final spacing = screenWidth > 700 ? 16.0 : 12.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppHeaderStyle.contentTopPadding,
            horizontalPadding,
            16 + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date card
              Builder(builder: (context) {
                final globalPanchang = _skyService.getTodayPanchang();
                final hasGlobalPanchang =
                    globalPanchang != null && globalPanchang.isNotEmpty;
                final insightPanchangRaw =
                    insight?.astrologicalData?['panchang'];
                final insightPanchang = insightPanchangRaw is Map
                    ? Map<String, dynamic>.from(insightPanchangRaw)
                    : null;
                final samvatToUse =
                    hasGlobalPanchang ? globalPanchang : insightPanchang;
                return CosmicDateTimeCard(
                  samvat: samvatToUse,
                  brown: brown,
                );
              }),

              SizedBox(height: spacing),

              // Today's Insight
              if (insight != null &&
                  (insight.displayTheme.isNotEmpty ||
                      insight.displayMessage.isNotEmpty)) ...[
                CosmicInsightCard(insight: insight, brown: brown),
                SizedBox(height: spacing),
              ],

              // Muhurat section
              if (globalMuhurat != null && globalMuhurat.isNotEmpty) ...[
                MuhuratTimelineWidget(muhurat: globalMuhurat),
                SizedBox(height: spacing),
              ] else if (_loadingState.isMuhuratLoading) ...[
                _buildMuhuratPlaceholder(isDark, brown, cardColor),
                SizedBox(height: spacing),
              ],

              // Current Sky with optional Birth Chart overlay
              if (_loadingState.isSkyLoaded) ...[
                ValueListenableBuilder<double>(
                  valueListenable: _sliderValueNotifier,
                  builder: (context, sliderValue, _) {
                    return ValueListenableBuilder<DateTime>(
                      valueListenable: _sliderDateNotifier,
                      builder: (context, sliderDate, _) {
                        final skyPositions =
                            _skyService.getPositionsForDate(sliderDate);
                        final positions =
                            skyPositions != null && skyPositions.isNotEmpty
                                ? skyPositions
                                : currentPositions;

                        if (positions == null || positions.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return CosmicSkyChartCard(
                          todayPositions: positions,
                          birthChartData: profile?.birthChartData,
                          isDark: isDark,
                          sliderValue: sliderValue,
                          sliderDate: sliderDate,
                          skyDataLoaded: _loadingState.isSkyLoaded,
                          skyDataLoading: _loadingState.isSkyLoading,
                          showTransitOverlay: _showTransitOverlay,
                          chartBlendValue: _chartBlendValue,
                          onSliderChanged: _onSliderChanged,
                          onResetToToday: _resetSliderToToday,
                          onToggleTransitOverlay: _toggleTransitOverlay,
                          onBlendValueChanged: _onBlendValueChanged,
                          onLoadSkyPositions: _loadSkyPositions,
                          onTriggerCachePopulation:
                              _triggerSkyPositionsCachePopulation,
                          getPositionsForDate:
                              _skyService.getPositionsForDate,
                          getInterpolatedPositions:
                              _skyService.getInterpolatedPositions,
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: spacing),
              ],

              // Upcoming Planetary Events
              if (_loadingState.isEventsLoaded &&
                  _skyService.hasUpcomingEvents) ...[
                UpcomingEventsCard(
                  brown: brown,
                  events: _skyService.allUpcomingEvents,
                  maxEvents: 8,
                ),
                SizedBox(height: spacing),
              ],

              // Panchang (global only)
              Builder(builder: (context) {
                final todayPanchang = _skyService.getTodayPanchang();
                if (todayPanchang == null || todayPanchang.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    CosmicPanchangCard(
                      panchang: todayPanchang,
                      brown: brown,
                    ),
                    SizedBox(height: spacing),
                  ],
                );
              }),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMuhuratPlaceholder(bool isDark, Color brown, Color cardColor) {
    final c = AppTheme.primaryColor;
    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading time guidance...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCosmicSkeleton(bool isDark, Color brown) {
    return ShimmerBox(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppHeaderStyle.contentHorizontalPadding,
          AppHeaderStyle.contentTopPadding,
          AppHeaderStyle.contentHorizontalPadding,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 24,
              decoration: BoxDecoration(
                color: brown.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: brown.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: brown.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecentConversations() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecentConversationsPage(
          onConversationSelected: (conversationId) {
            _shouldScrollAfterLoad = true;
          },
        ),
      ),
    );
  }

  Widget _buildChatContent() {
    return Consumer<AiChatProvider>(
      builder: (context, provider, _) {
        // Scroll to bottom after loading a conversation (e.g. from Recent Conversations)
        if (_shouldScrollAfterLoad && provider.messages.isNotEmpty) {
          _shouldScrollAfterLoad = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Give focus to content so the text field never gets it (avoids keyboard after pop)
              _contentFocusNode.requestFocus();
            }
            for (int delay in [50, 150, 300, 500]) {
              Future.delayed(Duration(milliseconds: delay), () {
                if (mounted && scrollController.hasClients) {
                  _scrollToBottomInstant();
                }
              });
            }
          });
        }

        // Empty state - no content to show
        if (provider.messages.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          color: Colors.transparent,
          padding: EdgeInsets.fromLTRB(
            AppHeaderStyle.contentHorizontalPadding,
            AppHeaderStyle.contentTopPadding,
            AppHeaderStyle.contentHorizontalPadding,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Render messages with thoughts box below user messages
              // SIMPLIFIED: Thoughts are always on the message, widget decides visibility
              ...provider.messages.asMap().entries.map((entry) {
                final index = entry.key;
                final message = entry.value;
                final isUserMessage = message.role == 'user';

                // For user messages, check if there's a following assistant message
                final hasFollowingAssistant = isUserMessage &&
                    index + 1 < provider.messages.length &&
                    provider.messages[index + 1].role == 'assistant';

                // Check if this is a new conversation turn (user message after an AI message)
                final isNewTurn = isUserMessage &&
                    index > 0 &&
                    provider.messages[index - 1].role == 'assistant';

                return Column(
                  key: ValueKey('msg_column_${message.id}'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add subtle separator between conversation turns
                    if (isNewTurn)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
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
                      thoughtExpansionState: _thoughtExpansionState,
                      onThoughtExpansionChanged: (messageId, isExpanded) {
                        setState(() {
                          _thoughtExpansionState[messageId] = isExpanded;
                        });
                      },
                    ),
                    // Show thoughts box below user message if there's an assistant response
                    // The widget itself decides whether to render based on thoughtProcess
                    if (hasFollowingAssistant)
                      ChatMessageWidgets.buildThoughtsBoxBelowUserMessage(
                        provider,
                        context,
                        userMessageId: message.id,
                        thoughtExpansionState: _thoughtExpansionState,
                        onThoughtExpansionChanged: (messageId, isExpanded) {
                          setState(() {
                            _thoughtExpansionState[messageId] = isExpanded;
                          });
                        },
                      ),
                  ],
                );
              }),
              // Bottom spacing handled by parent Column
            ],
          ),
        );
      },
    );
  }
}
