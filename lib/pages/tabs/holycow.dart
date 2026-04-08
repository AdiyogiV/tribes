import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/models/ayurveda_profile.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/services/astrology_service.dart';
import 'package:aurogram/services/ayurveda_service.dart';
import 'package:aurogram/services/sky_positions_service.dart';
import 'package:aurogram/services/audio_input_service.dart';
import 'package:aurogram/providers/ai_chat_provider.dart';
import 'package:aurogram/widgets/cosmic_dashboard/cosmic_dashboard_data.dart';
import 'package:aurogram/widgets/cosmic_dashboard.dart';
import 'package:aurogram/widgets/ui/glass_container.dart';
import 'package:aurogram/pages/ai/ai_chat_page.dart';
import 'package:aurogram/pages/ai/recent_conversations_page.dart';
import 'package:aurogram/pages/tabs/holycow/holycow_desktop_layout.dart';
import 'package:aurogram/pages/tabs/holycow/holycow_empty_states.dart';
import 'package:aurogram/pages/tabs/holycow/holycow_cosmic_content.dart';

class HolyCowPage extends StatefulWidget {
  const HolyCowPage({super.key});

  @override
  HolyCowPageState createState() => HolyCowPageState();
}

class HolyCowPageState extends State<HolyCowPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  // Dashboard input — navigates to AiChatPage on send
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  // Voice recording animation
  late AnimationController _micAnimationController;
  late Animation<double> _micPulseAnimation;

  // Cosmic Dashboard services (singletons with caching)
  final _astrologyService = AstrologyService();
  final _ayurvedaService = AyurvedaService();
  final _skyService = SkyPositionsService();
  final _user = FirebaseAuth.instance.currentUser;

  // Streams cached once in initState — never recreated in build()
  Stream<AstrologyProfile?>? _profileStream;
  Stream<DailyInsight?>? _insightStream;
  Stream<AyurvedaProfile?>? _ayurvedaStream;

  // Sky slider state
  static const int _sliderRangeDays = 30;
  static const int _maxSkyLoadRetries = 2;
  static const Duration _retryBaseDelay = Duration(seconds: 2);
  static const Duration _cachePopulationDelay = Duration(seconds: 3);

  final ValueNotifier<double> _sliderValueNotifier = ValueNotifier(0.5);
  final ValueNotifier<DateTime> _sliderDateNotifier = ValueNotifier(DateTime.now());

  DashboardLoadingState _loadingState = const DashboardLoadingState();
  bool _showTransitOverlay = false;
  double _chartBlendValue = 0.0;

  @override
  void initState() {
    super.initState();

    _micAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _micPulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _micAnimationController, curve: Curves.easeInOut),
    );

    // Cache streams once — they persist for the widget's lifetime
    if (_user != null) {
      _profileStream = _astrologyService.streamProfile(_user!.uid);
      _insightStream = _astrologyService.streamTodayInsight(_user!.uid);
      _ayurvedaStream = _ayurvedaService.streamProfile(_user!.uid);

      // Skip loading→loaded flash if service already has cached data
      if (_skyService.availableDays > 0) {
        _loadingState = _loadingState.copyWith(sky: DashboardLoadState.loaded);
      } else {
        _loadSkyPositions();
      }
      if (_skyService.hasUpcomingEvents) {
        _loadingState = _loadingState.copyWith(events: DashboardLoadState.loaded);
      } else {
        _loadUpcomingEvents();
      }
      if (_skyService.globalMuhurat != null) {
        _loadingState = _loadingState.copyWith(muhurat: DashboardLoadState.loaded);
      } else {
        _loadGlobalMuhurat();
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _sliderValueNotifier.dispose();
    _sliderDateNotifier.dispose();
    _micAnimationController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────────────────────

  void _openChatWithMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    _inputFocusNode.unfocus();
    HapticFeedback.lightImpact();

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => AiChatPage(initialMessage: text),
      ),
    );
  }

  void _openNewChat() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const AiChatPage()),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Voice recording on dashboard — record here, navigate after
  // ─────────────────────────────────────────────────────────────

  Future<void> _startDashboardRecording() async {
    final audioService = Provider.of<AudioInputService>(context, listen: false);
    final provider = Provider.of<AiChatProvider>(context, listen: false);
    if (audioService.isRecording || audioService.isProcessing) return;

    if (audioService.hasError) await audioService.resetService();
    audioService.clearState();

    // Register upload callbacks so the provider gets notified when
    // background upload completes (stops the upload spinner on messages).
    audioService.setOnAudioUrlUploaded((audioUrl) {
      provider.updateLastVoiceMessageUrl(audioUrl);
    });
    audioService.setOnAudioUploadSkipped(() {
      provider.markLastVoiceMessageAsLocalOnly();
    });

    await audioService.startRecording(
      onResult: (AudioInputResult result) {
        // Recording finished — navigate to AiChatPage with the voice result
        if (!mounted) return;
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => AiChatPage(initialVoiceResult: result),
          ),
        );
      },
      onTranscriptUpdate: (String transcript) {
        AppLogger.d('Dashboard transcript: "$transcript"',
            category: LogCategory.voice);
      },
    );
    HapticFeedback.lightImpact();
  }

  void _stopDashboardRecording() {
    final audioService = Provider.of<AudioInputService>(context, listen: false);
    audioService.stopRecording();
    HapticFeedback.mediumImpact();
  }

  void _cancelDashboardRecording() {
    final audioService = Provider.of<AudioInputService>(context, listen: false);
    audioService.cancelRecording();
    HapticFeedback.lightImpact();
  }

  void _showRecentConversations() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecentConversationsPage(
          onConversationSelected: (conversationId) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => AiChatPage(conversationId: conversationId),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Data loading (same as before — services cache aggressively)
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadUpcomingEvents() async {
    if (_loadingState.events == DashboardLoadState.loading) return;
    setState(() => _loadingState = _loadingState.copyWith(events: DashboardLoadState.loading));
    final success = await _skyService.fetchUpcomingEvents();
    if (mounted) {
      setState(() => _loadingState = _loadingState.copyWith(
        events: success ? DashboardLoadState.loaded : DashboardLoadState.error,
      ));
    }
  }

  Future<void> _loadSkyPositions({bool isRetry = false}) async {
    if (_loadingState.isSkyLoading) return;
    setState(() => _loadingState = _loadingState.copyWith(sky: DashboardLoadState.loading));
    final success = await _skyService.fetchPositions();
    if (!mounted) return;
    setState(() => _loadingState = _loadingState.copyWith(
      sky: success ? DashboardLoadState.loaded : DashboardLoadState.error,
      skyRetryCount: success ? 0 : _loadingState.skyRetryCount,
    ));
    if (!success) {
      if (_loadingState.skyRetryCount == 0 && _skyService.availableDays == 0) {
        await _triggerSkyPositionsCachePopulation();
      }
      if (_loadingState.skyRetryCount < _maxSkyLoadRetries) {
        final newRetryCount = _loadingState.skyRetryCount + 1;
        setState(() => _loadingState = _loadingState.copyWith(skyRetryCount: newRetryCount));
        Future.delayed(_retryBaseDelay * newRetryCount, () {
          if (mounted && !_loadingState.isSkyLoaded) _loadSkyPositions(isRetry: true);
        });
      }
    }
  }

  Future<void> _triggerSkyPositionsCachePopulation() async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast2');
      await functions.httpsCallable('prefetchSkyPositions').call({
        'daysBack': 30, 'daysAhead': 30,
      });
      await Future.delayed(_cachePopulationDelay);
      if (mounted) _loadSkyPositions(isRetry: true);
    } catch (e) {
      AppLogger.e('Failed to populate sky cache', category: LogCategory.ui, error: e);
    }
  }

  Future<void> _loadGlobalMuhurat() async {
    if (_loadingState.muhurat == DashboardLoadState.loading || !mounted) return;
    setState(() => _loadingState = _loadingState.copyWith(muhurat: DashboardLoadState.loading));
    final success = await _skyService.fetchGlobalMuhurat();
    if (!mounted) return;
    setState(() => _loadingState = _loadingState.copyWith(
      muhurat: success ? DashboardLoadState.loaded : DashboardLoadState.error,
    ));
  }

  // ─────────────────────────────────────────────────────────────
  // Slider
  // ─────────────────────────────────────────────────────────────

  void _onSliderChanged(double value) {
    _sliderValueNotifier.value = value;
    final daysOffset = ((value - 0.5) * 2 * _sliderRangeDays).round();
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
      if (_showTransitOverlay) _chartBlendValue = 0.0;
    });
  }

  void _onBlendValueChanged(double value) {
    setState(() => _chartBlendValue = value);
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final bool isWideLayout = Responsive.isWideLayout(context);

    if (isWideLayout) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: HolyCowDesktopLayout(
          onStartNewChat: _openNewChat,
          cosmicDashboardBuilder: _buildCosmicDashboardContent,
        ),
      );
    }

    // Mobile layout — dashboard + input
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                _buildSliverHeader(),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildCosmicDashboardContent(),
                      // Space for input overlay
                      ListenableBuilder(
                        listenable: _inputFocusNode,
                        builder: (context, _) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: _inputFocusNode.hasFocus ? 85.0 : 45.0,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Input at bottom — sends to AiChatPage
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: _buildDashboardInput(),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Sliver header
  // ─────────────────────────────────────────────────────────────

  Widget _buildSliverHeader() {
    return AppHeaderStyle.buildStandardHeader(
      context: context,
      title: "aurogram",
      actionButton: IconButton(
        onPressed: () => CosmicDashboard.show(context),
        icon: Icon(
          Icons.notifications_outlined,
          color: AppTheme.primaryColor,
          size: AppHeaderStyle.headerIconSize,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      leadingWidget: AppHeaderStyle.buildCompactIconButton(
        icon: Icons.history_rounded,
        onPressed: _showRecentConversations,
        tooltip: 'Recent Conversations',
      ),
      showSearchField: false,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Dashboard input — navigates on send
  // ─────────────────────────────────────────────────────────────

  Widget _buildDashboardInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: () {
          if (!_inputFocusNode.hasFocus) _inputFocusNode.requestFocus();
        },
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

              // LayoutBuilder to calculate the same spaceEvenly gap as TabBottomNav.
              // Tab bar: 4 items × 64px, spaceEvenly → gap = (width - 256) / 5.
              // We match [gap] [64px cow] [Expanded input] [64px send/mic] [gap].
              return LayoutBuilder(
                builder: (context, constraints) {
                  final gap = (constraints.maxWidth - 4 * 64) / 5;

                  return Row(
                    children: [
                      // Left gap — aligns with tab bar leading space
                      SizedBox(width: gap),

                      // Cow icon — 64×70, aligned with first tab icon
                      SizedBox(
                        width: 64,
                        height: 70,
                        child: Center(
                          child: Image.asset(
                            'assets/images/cow1.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      // Center: text field or recording indicator
                      Expanded(
                        child: isRecording
                            ? _buildRecordingIndicator()
                            : _buildDashboardTextField(),
                      ),

                      // Right: send/mic or recording controls — 64×70, aligned with last tab icon
                      SizedBox(
                        width: 64,
                        height: 70,
                        child: Center(
                          child: isRecording
                              ? _buildRecordingControls()
                              : _buildSendOrMicButton(),
                        ),
                      ),

                      // Right gap — aligns with tab bar trailing space
                      SizedBox(width: gap),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTextField() {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed) {
          if (_inputController.text.trim().isNotEmpty) {
            _openChatWithMessage();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: _inputController,
        focusNode: _inputFocusNode,
        decoration: InputDecoration(
          hintText: 'namaste',
          hintStyle: TextStyle(
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
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
        textAlign: TextAlign.center,
        maxLines: 1,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _openChatWithMessage(),
      ),
    );
  }

  Widget _buildSendOrMicButton() {
    return ListenableBuilder(
      listenable: _inputController,
      builder: (context, _) {
        final hasText = _inputController.text.trim().isNotEmpty;
        return hasText
            ? IconButton(
                onPressed: _openChatWithMessage,
                icon: Icon(
                  CupertinoIcons.paperplane_fill,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              )
            : IconButton(
                onPressed: _startDashboardRecording,
                icon: Icon(
                  CupertinoIcons.mic_fill,
                  color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  size: 22,
                ),
              );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Recording UI on dashboard — same style as AiChatInput
  // ─────────────────────────────────────────────────────────────

  Widget _buildRecordingIndicator() {
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

  Widget _buildRecordingControls() {
    // During recording, show cancel + send in a compact layout within 64px
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cancel — small X
        GestureDetector(
          onTap: _cancelDashboardRecording,
          child: Icon(Icons.close, size: 18,
            color: AppTheme.primaryColor.withValues(alpha: 0.6)),
        ),
        const SizedBox(width: 6),
        // Send — filled send icon
        GestureDetector(
          onTap: _stopDashboardRecording,
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

  // ─────────────────────────────────────────────────────────────
  // Cosmic Dashboard
  // ─────────────────────────────────────────────────────────────

  Widget _buildCosmicDashboardContent() {
    if (_user == null) return const SizedBox.shrink();

    return StreamBuilder<AstrologyProfile?>(
      stream: _profileStream,
      builder: (context, profileSnapshot) {
        return StreamBuilder<DailyInsight?>(
          stream: _insightStream,
          builder: (context, insightSnapshot) {
            return StreamBuilder<AyurvedaProfile?>(
              stream: _ayurvedaStream,
              builder: (context, ayurvedaSnapshot) {
                final profile = profileSnapshot.data;
                final insight = insightSnapshot.data;
                final isLoading =
                    profileSnapshot.connectionState == ConnectionState.waiting &&
                    profile == null;

                if (isLoading) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return HolyCowCosmicSkeleton(isDark: isDark, brown: AppTheme.primaryColor);
                }

                return HolyCowCosmicContent(
                  profile: profile,
                  insight: insight,
                  loadingState: _loadingState,
                  skyService: _skyService,
                  sliderValueNotifier: _sliderValueNotifier,
                  sliderDateNotifier: _sliderDateNotifier,
                  showTransitOverlay: _showTransitOverlay,
                  chartBlendValue: _chartBlendValue,
                  onSliderChanged: _onSliderChanged,
                  onResetToToday: _resetSliderToToday,
                  onToggleTransitOverlay: _toggleTransitOverlay,
                  onBlendValueChanged: _onBlendValueChanged,
                  onLoadSkyPositions: _loadSkyPositions,
                  onTriggerCachePopulation: _triggerSkyPositionsCachePopulation,
                );
              },
            );
          },
        );
      },
    );
  }
}
