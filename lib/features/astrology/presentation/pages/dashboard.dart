import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard/cosmic_dashboard_data.dart';
import 'package:aurogram/features/astrology/presentation/pages/baba/baba_desktop_layout.dart';
import 'package:aurogram/features/astrology/presentation/pages/baba/baba_empty_states.dart';
import 'package:aurogram/features/astrology/presentation/pages/baba/baba_cosmic_content.dart';
import 'package:aurogram/features/astrology/presentation/widgets/nakshatra_ring_widget.dart';
import 'package:aurogram/features/baba/domain/baba_snapshot.dart';
import 'package:aurogram/shared/presentation/widgets/universal/dark_mode_toggle.dart';
import 'package:aurogram/shared/providers/theme_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    this.onScrollHidesBottomBar,
  });

  /// When non-null, called with true when user scrolls down past threshold
  /// (hide tab bar), false when scrolling up or near top (show tab bar).
  final void Function(bool hide)? onScrollHidesBottomBar;

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage>
    with
        AutomaticKeepAliveClientMixin,
        TickerProviderStateMixin,
        BabaScreenAware<DashboardPage> {
  @override
  bool get wantKeepAlive => true;

  // ── Baba page awareness ──────────────────────────────────────────────
  // The home dashboard tells Baba what the user is actually looking at right
  // now (real-time), so `whereAmI` returns live data, not just "Home".
  @override
  String get babaScreenKey => 'home';

  @override
  BabaSnapshot babaSnapshot() {
    final selected = _sliderDateNotifier.value;
    final today = DateTime.now();
    final isToday = selected.year == today.year &&
        selected.month == today.month &&
        selected.day == today.day;
    final skyDate =
        '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    final loaded = _loadingState.sky == DashboardLoadState.loaded &&
        _loadingState.events == DashboardLoadState.loaded &&
        _loadingState.muhurat == DashboardLoadState.loaded;
    return BabaSnapshot(
      status: loaded ? BabaScreenStatus.ready : BabaScreenStatus.loading,
      headline: isToday
          ? "The home dashboard, showing today's sky wheel, panchang and feed"
          : 'The home dashboard, scrubbed to $skyDate',
      facts: {
        'loggedIn': _user != null,
        'skyDate': skyDate,
        'viewingToday': isToday,
      },
    );
  }

  // Scroll-to-hide bottom nav bar — mirrors Feed's approach. Baba himself is a
  // separate app-wide overlay (see BabaOverlay); the dashboard only owns the
  // tab-bar hide-on-scroll behaviour.
  final ScrollController _scrollController = ScrollController();
  static const double _hideBarScrollThreshold = 50;
  static const Duration _scrollLogicThrottle = Duration(milliseconds: 100);
  double _lastScrollOffset = 0;
  DateTime _lastScrollLogicTime = DateTime(2000);
  bool _lastReportedHideBar = false;
  bool _wheelInteracting = false;

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
  final ValueNotifier<DateTime> _sliderDateNotifier =
      ValueNotifier(DateTime.now());

  /// Incremented whenever the user taps "Today" — the nakshatra wheel listens
  /// and snaps back to today in sync with the sky chart.
  final ValueNotifier<int> _wheelResetNotifier = ValueNotifier(0);

  /// Live wheel state — the controller is notified on every nakshatra boundary
  /// crossing during drag, enabling the sky chart to move in real time.
  final NakshatraWheelController _nakshatraController =
      NakshatraWheelController();

  DashboardLoadingState _loadingState = const DashboardLoadingState();

  // Key for desktop layout — allows parent to trigger inline chat
  final _desktopLayoutKey = GlobalKey<BabaDesktopLayoutState>();

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
      // Decode the Aurobhatt asset NOW, while the page is idle, so its first
      // paint doesn't pay a cold-decode cost. Baba's blob (app-wide overlay)
      // shows it immediately, so precaching keeps that initial paint smooth.
      precacheImage(const AssetImage('assets/images/aurobhatt.png'), context);
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
      _loadingState =
          _loadingState.copyWith(muhurat: DashboardLoadState.loaded);
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
    _sliderValueNotifier.dispose();
    _sliderDateNotifier.dispose();
    _wheelResetNotifier.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────
  // Data loading (same as before — services cache aggressively)
  // ─────────────────────────────────────────────────

  Future<void> _loadUpcomingEvents() async {
    if (_loadingState.events == DashboardLoadState.loading) return;
    setState(() => _loadingState =
        _loadingState.copyWith(events: DashboardLoadState.loading));
    final success = await _skyService.fetchUpcomingEvents();
    if (mounted) {
      setState(() => _loadingState = _loadingState.copyWith(
            events:
                success ? DashboardLoadState.loaded : DashboardLoadState.error,
          ));
    }
  }

  Future<void> _loadSkyPositions({bool isRetry = false}) async {
    if (_loadingState.isSkyLoading) return;
    setState(() => _loadingState =
        _loadingState.copyWith(sky: DashboardLoadState.loading));
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
        setState(() => _loadingState =
            _loadingState.copyWith(skyRetryCount: newRetryCount));
        Future.delayed(_retryBaseDelay * newRetryCount, () {
          if (mounted && !_loadingState.isSkyLoaded) {
            _loadSkyPositions(isRetry: true);
          }
        });
      }
    }
  }

  Future<void> _triggerSkyPositionsCachePopulation() async {
    try {
      final functions =
          FirebaseFunctions.instanceFor(region: 'asia-southeast2');
      await functions.httpsCallable('astroGateway').call({
        'method': 'prefetchSkyPositions',
        'daysBack': 30,
        'daysAhead': 30,
      });
      await Future.delayed(_cachePopulationDelay);
      if (mounted) _loadSkyPositions(isRetry: true);
    } catch (e) {
      AppLogger.e('Failed to populate sky cache',
          category: LogCategory.ui, error: e);
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
    setState(() => _loadingState =
        _loadingState.copyWith(muhurat: DashboardLoadState.loading));
    final success = await _skyService.fetchGlobalMuhurat();
    if (!mounted) return;
    setState(() => _loadingState = _loadingState.copyWith(
          muhurat:
              success ? DashboardLoadState.loaded : DashboardLoadState.error,
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
    final daysOffset =
        date.difference(DateTime(today.year, today.month, today.day)).inDays;
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
    _sliderDateNotifier.value =
        DateTime(now.year, now.month, now.day).add(Duration(days: daysOffset));
  }

  void _resetSliderToToday() {
    HapticFeedback.lightImpact();
    _sliderValueNotifier.value = 0.5;
    _sliderDateNotifier.value = DateTime.now();
    // Signal the nakshatra wheel to also snap back to today.
    _wheelResetNotifier.value++;
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
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onScrollHidesBottomBar?.call(true);
      });
    } else if (!shouldHideBar && _lastReportedHideBar) {
      _lastReportedHideBar = false;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onScrollHidesBottomBar?.call(false);
      });
    }
  }

  // ──────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final bool isWideLayout = Responsive.isWideLayout(context);

    if (isWideLayout) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: BabaDesktopLayout(
          key: _desktopLayoutKey,
          cosmicDashboardBuilder: _buildCosmicDashboardContent,
          // No inline input builder: Baba is now the one app-wide overlay
          // (voice blob + floating chat) and floats over desktop too.
        ),
      );
    }

    // Mobile layout — just the dashboard content. Baba (BabaOverlay) floats on
    // top app-wide, so there's no per-page input bar to manage here anymore.
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Listener(
        // Raw pointer events — not blocked by child GestureDetectors (e.g. the
        // nakshatra wheel) — so tapping anywhere dismisses the keyboard.
        onPointerDown: (_) => FocusScope.of(context).unfocus(),
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
                    // Fixed tail so the last card clears the bottom nav bar and
                    // Baba's floating blob.
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        onChanged: (_) => context.read<ThemeProvider>().temporaryToggle(),
      ),
      showSearchField: false,
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
      return BabaCosmicContent(
        profile: null,
        insight: null,
        ayurvedaProfile: null,
        loadingState: _loadingState,
        skyService: _skyService,
        calendarService: _calendarService,
        sliderRangeDays: _sliderRangeDays,
        sliderValueNotifier: _sliderValueNotifier,
        sliderDateNotifier: _sliderDateNotifier,
        onSliderChanged: _onSliderChanged,
        onResetToToday: _resetSliderToToday,
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
                final isLoading = profileSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    profile == null;

                if (isLoading) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return BabaCosmicSkeleton(
                      isDark: isDark, brown: AppTheme.primaryColor);
                }

                return BabaCosmicContent(
                  profile: profile,
                  insight: insight,
                  ayurvedaProfile: ayurvedaSnapshot.data,
                  loadingState: _loadingState,
                  skyService: _skyService,
                  calendarService: _calendarService,
                  sliderRangeDays: _sliderRangeDays,
                  sliderValueNotifier: _sliderValueNotifier,
                  sliderDateNotifier: _sliderDateNotifier,
                  onSliderChanged: _onSliderChanged,
                  onResetToToday: _resetSliderToToday,
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
