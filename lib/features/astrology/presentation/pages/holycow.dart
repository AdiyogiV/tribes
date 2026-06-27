import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/ayurveda/domain/ayurveda_service.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/features/astrology/domain/astro_calendar_service.dart';
import 'package:aurogram/shared/services/media/audio_input_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard/cosmic_dashboard_data.dart';
import 'package:aurogram/features/astrology/presentation/pages/holycow/holycow_desktop_layout.dart';
import 'package:aurogram/features/astrology/presentation/pages/holycow/holycow_empty_states.dart';
import 'package:aurogram/features/astrology/presentation/pages/holycow/holycow_cosmic_content.dart';
import 'package:aurogram/features/astrology/presentation/pages/holycow/holycow_input_bar_controller.dart';
import 'package:aurogram/features/astrology/presentation/pages/holycow/holycow_input_bar.dart';
import 'package:aurogram/features/ai_chat/voice/holycow_voice_cow.dart';
import 'package:aurogram/features/astrology/presentation/widgets/nakshatra_ring_widget.dart';
import 'package:aurogram/shared/presentation/widgets/universal/dark_mode_toggle.dart';
import 'package:aurogram/shared/providers/theme_provider.dart';

class HolyCowPage extends StatefulWidget {
  const HolyCowPage({
    super.key,
    this.onScrollHidesBottomBar,
  });

  /// When non-null, called with true when user scrolls down past threshold
  /// (hide tab bar), false when scrolling up or near top (show tab bar).
  final void Function(bool hide)? onScrollHidesBottomBar;

  @override
  HolyCowPageState createState() => HolyCowPageState();
}

class HolyCowPageState extends State<HolyCowPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  // Scroll-to-hide bottom bar + input — mirrors Feed's approach
  final ScrollController _scrollController = ScrollController();
  static const double _hideBarScrollThreshold = 50;
  static const Duration _scrollLogicThrottle = Duration(milliseconds: 100);
  double _lastScrollOffset = 0;
  DateTime _lastScrollLogicTime = DateTime(2000);
  bool _lastReportedHideBar = false;
  bool _wheelInteracting = false;

  // Collapsible AI input — expanded on first load so the bar greets the user,
  // then auto-collapses as soon as they scroll/tap around. All of its state
  // (expanded flag + text + focus) lives in this controller so toggling the
  // bar rebuilds ONLY the bar + spacer, never the whole dashboard.
  final HolyCowInputBarController _inputBar =
      HolyCowInputBarController(expanded: true);

  // ── Input-bar layout + motion constants (single source of truth) ──
  // Tail spacer reserved at the bottom of the scroll content so the floating
  // bar never covers the last card. NOTE: these intentionally do NOT include a
  // "collapsed" variant — see the spacer in build() for why.
  static const double _spacerExpandedFocused = 85.0;
  static const double _spacerExpanded = 45.0;
  // One coordinated duration/curve for every part of the collapse/expand
  // transition (slide + fade + spacer) so the motion reads as a single gesture.
  static const Duration _inputMotion = Duration(milliseconds: 260);
  static const Curve _inputCurve = Curves.easeOutCubic;

  // Cosmic Dashboard services (singletons with caching)
  final _astrologyService = AstrologyService();
  final _ayurvedaService = AyurvedaService();
  final _skyService = SkyPositionsService();
  final _calendarService = AstroCalendarService();
  final _user = FirebaseAuth.instance.currentUser;

  // Streams cached once in initState — never recreated in build()
  Stream<AstrologyProfile?>? _profileStream;
  Stream<DailyInsight?>? _insightStream;
  Stream<AyurvedaProfile?>? _ayurvedaStream;

  // Sky slider state — extended range backed by AstroCalendarService.
  static const int _sliderRangeDays = 180;
  static const int _maxSkyLoadRetries = 2;
  static const Duration _retryBaseDelay = Duration(seconds: 5);
  static const Duration _cachePopulationDelay = Duration(seconds: 8);

  final ValueNotifier<double> _sliderValueNotifier = ValueNotifier(0.5);
  final ValueNotifier<DateTime> _sliderDateNotifier = ValueNotifier(DateTime.now());
  /// Incremented whenever the user taps "Today" — the nakshatra wheel listens
  /// and snaps back to today in sync with the sky chart.
  final ValueNotifier<int> _wheelResetNotifier = ValueNotifier(0);

  /// Live wheel state — the controller is notified on every nakshatra boundary
  /// crossing during drag, enabling the sky chart to move in real time.
  final NakshatraWheelController _nakshatraController = NakshatraWheelController();

  DashboardLoadingState _loadingState = const DashboardLoadingState();
  bool _showTransitOverlay = false;
  double _chartBlendValue = 0.0;

  // Key for desktop layout — allows parent to trigger inline chat
  final _desktopLayoutKey = GlobalKey<HolyCowDesktopLayoutState>();

  bool _didPrecache = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
if (!_didPrecache) {
      _didPrecache = true;
      precacheImage(
        const AssetImage('assets/images/nakshatra_wheel.jpeg'),
        context,
      );
      // Decode the collapsed-cow asset NOW, while the page is idle. Otherwise
      // its first paint happens on the first scroll (the bar is expanded by
      // default, so the cow starts at opacity 0 and is never painted until the
      // collapse) — and that cold decode lands right on the first scroll frame,
      // causing a one-time hitch. Precaching moves the cost off the gesture.
      precacheImage(const AssetImage('assets/images/cow1.png'), context);
    }
  }

  @override
  void initState() {
    super.initState();

    // Scroll-to-hide bottom bar listener
    _scrollController.addListener(_onScroll);

    // Live wheel → sky chart bridge: whenever the wheel crosses a nakshatra
    // boundary during drag the controller notifies and we update the sky slider.
    _nakshatraController.addListener(_onWheelControllerChanged);

    // User-specific streams (only for logged-in users)
    if (_user != null) {
      _profileStream = _astrologyService.streamProfile(_user!.uid);
      _insightStream = _astrologyService.streamTodayInsight(_user!.uid);
      _ayurvedaStream = _ayurvedaService.streamProfile(_user!.uid);
    }

    // Global data — load for everyone (sky positions, events, muhurat are
    // not user-specific and make the page useful even for logged-out visitors)
    //
    // Load the lightweight astro calendar (365-day snapshot) in parallel.
    // This powers the infinite wheel + extended sky chart slider.
    _loadAstroCalendar();

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

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _nakshatraController.removeListener(_onWheelControllerChanged);
    _nakshatraController.dispose();
    _inputBar.dispose();
    _sliderValueNotifier.dispose();
    _sliderDateNotifier.dispose();
    _wheelResetNotifier.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────
  // Input bar → chat navigation (callbacks for HolyCowInputBar).
  // Desktop shows chat inline; mobile pushes the chat route.
  // ─────────────────────────────────────────────────

  void _handleSendText(String text) {
    if (Responsive.isWideLayout(context)) {
      _desktopLayoutKey.currentState?.startChatWithMessage(text);
      return;
    }
    context.push('/ai/chat', extra: {'initialMessage': text});
  }

  void _handleVoiceResult(AudioInputResult result) {
    if (Responsive.isWideLayout(context)) {
      _desktopLayoutKey.currentState?.startChatWithVoice(result);
      return;
    }
    context.push('/ai/chat', extra: {'initialVoiceResult': result});
  }

  void _showRecentConversations() {
    HapticFeedback.lightImpact();
    context.push('/ai/conversations', extra: {
      'onConversationSelected': (String conversationId) {
        context.push('/ai/chat', extra: {'conversationId': conversationId});
      },
    });
  }

  // ───────────────────────────────────────────────────────────────
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
      await functions.httpsCallable('astroGateway').call({
        'method': 'prefetchSkyPositions', 'daysBack': 30, 'daysAhead': 30,
      });
      await Future.delayed(_cachePopulationDelay);
      if (mounted) _loadSkyPositions(isRetry: true);
    } catch (e) {
      AppLogger.e('Failed to populate sky cache', category: LogCategory.ui, error: e);
    }
  }

  /// Load the astro calendar (365-day lightweight snapshot).
  /// Runs in the background — does not block the UI.  The calendar service
  /// caches for 7 days, so this is nearly free on repeat visits.
  Future<void> _loadAstroCalendar() async {
    await _calendarService.fetchCalendar();
    // No setState needed — the calendar is consumed on-demand by the wheel
    // controller sync and sky chart position lookups.
    if (_calendarService.isLoaded) {
      AppLogger.i('Astro calendar ready',
          category: LogCategory.ui,
          data: {'days': _calendarService.availableDays});
    }
  }

  /// Pull-to-refresh: clears caches and reloads all sky data from backend.
  Future<void> _onRefresh() async {
    AppLogger.i('Pull-to-refresh triggered',
        category: LogCategory.ui, data: {'action': 'refreshAllSkyData'});
    await Future.wait([
      _skyService.fetchPositions(forceRefresh: true),
      _calendarService.fetchCalendar(forceRefresh: true),
      _skyService.fetchGlobalMuhurat(forceRefresh: true),
      _skyService.fetchUpcomingEvents(forceRefresh: true),
    ]);
    if (!mounted) return;
    setState(() => _loadingState = _loadingState.copyWith(
      sky: _skyService.availableDays > 0
          ? DashboardLoadState.loaded
          : DashboardLoadState.error,
      muhurat: _skyService.globalMuhurat != null
          ? DashboardLoadState.loaded
          : DashboardLoadState.error,
    ));
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
  // Wheel controller bridge
  // ─────────────────────────────────────────────────────────────

  /// Called live on every nakshatra boundary crossing during wheel drag.
  /// Updates the sky-chart slider in real time so the sky moves with the wheel.
  void _onWheelControllerChanged() {
    // Lock page scroll while user is interacting with the wheel.
    final interacting = _nakshatraController.isInteracting;
    if (interacting != _wheelInteracting) {
      setState(() => _wheelInteracting = interacting);
    }

    final date = _nakshatraController.displayedDate;
    final today = DateTime.now();
    final daysOffset = date
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    // Map days to slider range: 0.5 = today, 0.0 = −N days, 1.0 = +N days
    _sliderValueNotifier.value =
        (0.5 + daysOffset / (2 * _sliderRangeDays)).clamp(0.0, 1.0);
    _sliderDateNotifier.value = date;
  }

  // ─────────────────────────────────────────────────────────────
  // Slider
  // ─────────────────────────────────────────────────────────────

  void _onSliderChanged(double value) {
    _sliderValueNotifier.value = value;
    final daysOffset = ((value - 0.5) * 2 * _sliderRangeDays).round();
    final now = DateTime.now();
    _sliderDateNotifier.value = DateTime(now.year, now.month, now.day)
        .add(Duration(days: daysOffset));
  }

  void _resetSliderToToday() {
    HapticFeedback.lightImpact();
    _sliderValueNotifier.value = 0.5;
    _sliderDateNotifier.value = DateTime.now();
    // Signal the nakshatra wheel to also snap back to today.
    _wheelResetNotifier.value++;
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
  // Scroll-to-hide bottom bar (mirrors Feed's approach)
  // ─────────────────────────────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.position.pixels;
    final previousOffset = _lastScrollOffset;
    _lastScrollOffset = offset;

    // Throttle: run hide-bar logic at most every 100ms
    final now = DateTime.now();
    if (now.difference(_lastScrollLogicTime) < _scrollLogicThrottle) return;
    _lastScrollLogicTime = now;

    // Hide tab bar when scrolling down past threshold
    final isScrollingDown = offset > previousOffset;
    final pastThreshold = offset > _hideBarScrollThreshold;
    final shouldHideBar = isScrollingDown && pastThreshold;

    if (shouldHideBar && !_lastReportedHideBar) {
      _lastReportedHideBar = true;
      // Slide the bar off-screen + collapse it (both local rebuilds only).
      _inputBar.setHidden(true);
      _inputBar.collapseIfUnfocused();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onScrollHidesBottomBar?.call(true);
      });
    } else if (!shouldHideBar && _lastReportedHideBar) {
      _lastReportedHideBar = false;
      _inputBar.setHidden(false);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onScrollHidesBottomBar?.call(false);
      });
    }
  }

  // ─────────────────────────────────────────────────
  // Collapsible input — all state lives in _inputBar; these just add haptics.
  // ─────────────────────────────────────────────────

  void _toggleInputBar() {
    HapticFeedback.lightImpact();
    _inputBar.toggle();
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
          key: _desktopLayoutKey,
          cosmicDashboardBuilder: _buildCosmicDashboardContent,
dashboardInputBuilder: _buildInputBar,
        ),
      );
    }

    // Mobile layout — dashboard + input
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Listener uses raw pointer events — not blocked by child GestureDetectors
          // (e.g. the nakshatra wheel), so tapping anywhere collapses the input.
          Listener(
            onPointerDown: (_) {
              _inputBar.collapseIfUnfocused();
              FocusScope.of(context).unfocus();
            },
            behavior: HitTestBehavior.translucent,
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              displacement: 50,
              edgeOffset: MediaQuery.of(context).padding.top + 5,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: CustomScrollView(
                controller: _scrollController,
                physics: _wheelInteracting
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                slivers: [
                  _buildSliverHeader(),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _LocalOverlayScope(
                          child: _buildCosmicDashboardContent(),
                        ),
                        // Fixed tail so the floating bar never covers the last
                        // card. CRITICAL: height must NOT depend on
                        // expanded/collapsed. The bar floats in a Positioned
                        // overlay (sibling of this scroll view), so resizing
                        // this mid-scroll would relayout the scrollable and
                        // fight the gesture — that was the "collapse first,
                        // then scroll" hitch. It only grows for the keyboard,
                        // which never appears during a scroll.
                        ListenableBuilder(
                          listenable: _inputBar,
                          builder: (context, _) => AnimatedContainer(
                            duration: _inputMotion,
                            curve: _inputCurve,
                            height: _inputBar.hasFocus
                                ? _spacerExpandedFocused
                                : _spacerExpanded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating AI input. We show EITHER the expanded glass bar OR the
          // collapsed cow — never both stacked. The glass surface is
          // translucent, so painting the cow behind it would ghost through;
          // swapping instead means there is literally nothing behind the glass.
          // Hide-on-scroll is the outer 80px slide (timed with the tab bar),
          // which also masks the bar→cow swap while you're scrolling.
          // No opacity anywhere → no offscreen saveLayer → no first-scroll hitch.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: ListenableBuilder(
                listenable: _inputBar,
                builder: (context, _) => TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: _inputBar.hidden ? 80.0 : 0.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  builder: (context, dy, child) => Transform.translate(
                    offset: Offset(0, dy),
                    child: child,
                  ),
                  child: _inputBar.expanded
                      ? _buildInputBar()
                      : HolyCowVoiceCow(onShowKeyboard: _toggleInputBar),
                ),
              ),
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
      actionButton: DarkModeToggle(
        isDark: Theme.of(context).brightness == Brightness.dark,
        size: 110,
        onChanged: (_) =>
            context.read<ThemeProvider>().temporaryToggle(),
      ),
      showSearchField: false,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Dashboard input — the bar's UI lives in HolyCowInputBar; the page just
  // wires its controller + navigation callbacks. Shared by mobile (overlay)
  // and desktop (floating) layouts.
  // ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return HolyCowInputBar(
      controller: _inputBar,
      onSendText: _handleSendText,
      onVoiceResult: _handleVoiceResult,
      onShowRecent: _showRecentConversations,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Cosmic Dashboard
  // ─────────────────────────────────────────────────────────────

  Widget _buildCosmicDashboardContent() {
    // Logged-out users: show global content (sky chart, muhurat, panchang,
    // events) with null profile/insight/ayurveda — the content widget's
    // existing `if` guards naturally hide personal sections.
    if (_user == null) {
      return HolyCowCosmicContent(
        profile: null,
        insight: null,
        ayurvedaProfile: null,
        loadingState: _loadingState,
        skyService: _skyService,
        calendarService: _calendarService,
        sliderRangeDays: _sliderRangeDays,
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
        wheelResetSignal: _wheelResetNotifier,
        nakshatraController: _nakshatraController,
      );
    }

    // Logged-in users: wait for user streams before rendering
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
                  ayurvedaProfile: ayurvedaSnapshot.data,
                  loadingState: _loadingState,
                  skyService: _skyService,
                  calendarService: _calendarService,
                  sliderRangeDays: _sliderRangeDays,
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
                  wheelResetSignal: _wheelResetNotifier,
                  nakshatraController: _nakshatraController,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local overlay scope
// ─────────────────────────────────────────────────────────────────────────────
//
// Wraps content in a local Overlay so any OverlayPortal inside (e.g. the
// NakshatraRingWidget zoom overlay) resolves to this scoped overlay rather
// than the root navigator overlay.  That keeps the magnified wheel above
// sibling cards without ever rising above the bottom nav bar or FAB.

class _LocalOverlayScope extends StatefulWidget {
  final Widget child;
  const _LocalOverlayScope({required this.child});

  @override
  State<_LocalOverlayScope> createState() => _LocalOverlayScopeState();
}

class _LocalOverlayScopeState extends State<_LocalOverlayScope> {
  late final OverlayEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = OverlayEntry(
      opaque: true,
      maintainState: true,
      canSizeOverlay: true,
      builder: (_) => widget.child,
    );
  }

  @override
  void didUpdateWidget(_LocalOverlayScope old) {
    super.didUpdateWidget(old);
    // Propagate parent rebuilds into the overlay entry.
    _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
