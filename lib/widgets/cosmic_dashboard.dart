import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/ayurveda/domain/ayurveda_service.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/shared/services/share/share_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/widgets/mandala/daily_mandala_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/timeline/muhurat_timeline_widget.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_date_time_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_insight_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_panchang_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_quick_actions.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/upcoming_events_card.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/widgets/cosmic_dashboard/widgets/cosmic_sky_chart_card.dart';
import 'package:aurogram/widgets/cosmic_dashboard/cosmic_dashboard_data.dart';
import 'package:aurogram/features/astrology/presentation/pages/astrology_details_page.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/ayurveda_details_page.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/vikriti_checkin_page.dart';
import 'package:aurogram/tabs.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

/// Feature flag to enable/disable mandala
const bool _kShowMandala = false;

/// Dashboard constants
class _DashboardConstants {
  static const int sliderRangeDays = 30;
  static const int maxSkyLoadRetries = 2;
  static const Duration retryBaseDelay = Duration(seconds: 2);
  static const Duration cachePopulationDelay = Duration(seconds: 3);
}

/// Cosmic Dashboard - Today's cosmic snapshot
/// Shows birth chart, current planetary positions, and daily insights
class CosmicDashboard extends StatefulWidget {
  const CosmicDashboard({super.key});

  static Future<void> show(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showUnauthenticatedPrompt(context);
      return;
    }

    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CosmicDashboard()),
    );
  }

  static void _showUnauthenticatedPrompt(BuildContext context) {
    final brown = AppTheme.primaryColor;

    AppBottomSheet.show(
      context,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Unlock Your Cosmic View',
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w700,
                color: brown,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              'Sign in to see your birth chart, current planetary positions, and personalized insights.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                height: 1.5,
                color: brown.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXxl),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Got it',
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    fontWeight: FontWeight.w600,
                    color: brown,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  State<CosmicDashboard> createState() => _CosmicDashboardState();
}

class _CosmicDashboardState extends State<CosmicDashboard> {
  // Services
  final _astrologyService = AstrologyService();
  final _ayurvedaService = AyurvedaService();
  final _skyService = SkyPositionsService();
  final _user = FirebaseAuth.instance.currentUser;

  // Sky slider state - using ValueNotifier to avoid full widget rebuilds
  final ValueNotifier<double> _sliderValueNotifier = ValueNotifier(0.5);
  final ValueNotifier<DateTime> _sliderDateNotifier =
      ValueNotifier(DateTime.now());

  // Consolidated loading state
  DashboardLoadingState _loadingState = const DashboardLoadingState();

  // Transit overlay state
  bool _showTransitOverlay = false;
  double _chartBlendValue = 0.0;

  @override
  void initState() {
    super.initState();
    // Load all data in parallel
    _loadSkyPositions();
    _loadUpcomingEvents();
    _loadGlobalMuhurat();
  }

  @override
  void dispose() {
    _sliderValueNotifier.dispose();
    _sliderDateNotifier.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Data Loading Methods
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
        AppLogger.i('CosmicDashboard: Upcoming events loaded',
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

    AppLogger.d('CosmicDashboard: Loading sky positions for slider',
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
        AppLogger.i('CosmicDashboard: Sky positions loaded successfully',
            category: LogCategory.ui,
            data: {'availableDays': _skyService.availableDays});
      } else {
        AppLogger.w('CosmicDashboard: Failed to load sky positions',
            category: LogCategory.ui,
            data: {
              'retryCount': _loadingState.skyRetryCount,
              'maxRetries': _DashboardConstants.maxSkyLoadRetries
            });

        // If this is the first attempt and cache is empty, try to populate cache
        if (_loadingState.skyRetryCount == 0 &&
            _skyService.availableDays == 0) {
          await _triggerSkyPositionsCachePopulation();
        }

        // Auto-retry with exponential backoff
        if (_loadingState.skyRetryCount <
            _DashboardConstants.maxSkyLoadRetries) {
          final newRetryCount = _loadingState.skyRetryCount + 1;
          setState(() {
            _loadingState =
                _loadingState.copyWith(skyRetryCount: newRetryCount);
          });

          final delay = _DashboardConstants.retryBaseDelay * newRetryCount;
          AppLogger.d('CosmicDashboard: Scheduling retry after $delay',
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
      AppLogger.i('CosmicDashboard: Attempting to populate sky positions cache',
          category: LogCategory.ui);

      final functions =
          FirebaseFunctions.instanceFor(region: 'asia-southeast2');
      final callable = functions.httpsCallable('prefetchSkyPositions');
      await callable.call({
        'daysBack': 30,
        'daysAhead': 30,
      });

      // Wait a moment then retry loading
      await Future.delayed(_DashboardConstants.cachePopulationDelay);
      if (mounted) {
        _loadSkyPositions(isRetry: true);
      }
    } catch (e) {
      AppLogger.e(
          'CosmicDashboard: Failed to trigger sky positions cache population',
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
      AppLogger.d('CosmicDashboard: Muhurat loaded', category: LogCategory.ui);
    } else {
      AppLogger.w('CosmicDashboard: Muhurat fetch failed',
          category: LogCategory.ui);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Slider Methods
  // ─────────────────────────────────────────────────────────────

  void _onSliderChanged(double value) {
    _sliderValueNotifier.value = value;
    final daysOffset =
        ((value - 0.5) * 2 * _DashboardConstants.sliderRangeDays).round();
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

  // ─────────────────────────────────────────────────────────────
  // Build Methods
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brown = AppTheme.primaryColor;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<AstrologyProfile?>(
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
                      return _buildSkeleton(isDark, brown);
                    }

                    return _buildDashboardContent(
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
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
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

    AppLogger.i(
      'CosmicDashboard: Determining currentPositions',
      category: LogCategory.ui,
      data: {
        'isSkyLoaded': _loadingState.isSkyLoaded,
        'now': now.toIso8601String(),
        'globalSkyPositionsFound': globalSkyPositions != null,
        'globalSkyPositionsPlanetCount': globalSkyPositions?.length ?? 0,
        'globalSkyPositionsPlanets': globalSkyPositions?.keys.toList(),
        'insightTransitsFound': insightTransits != null,
        'insightTransitsPlanetCount': insightTransits?.length ?? 0,
        'usingGlobalSky': currentPositions == globalSkyPositions,
        'usingInsightTransits': currentPositions == insightTransits,
        'finalPlanetCount': currentPositions?.length ?? 0,
        'finalPlanets': currentPositions?.keys.toList(),
      },
    );

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

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              16 + bottomInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimensions.spacingSm),

                // Header
                _buildHeader(brown),

                SizedBox(height: spacing),

                // Mandala first (floats without card)
                if (_kShowMandala)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: DailyMandalaCard(
                      insight: insight,
                      astrologyProfile: profile,
                      ayurvedaProfile: ayurvedaProfile,
                      onCosmicTap: () => _openAstroDetails(profile),
                      onWellnessTap: () =>
                          _openAyurvedaDetails(ayurvedaProfile),
                      onRitualTap: () => _openRitualCheckin(
                        ayurvedaProfile,
                        profile,
                      ),
                      onMindfulTap: () => _showMindfulPrompt(),
                      onResonanceTap: () => _shareMandala(insight, profile),
                      onShareTap: () => _shareMandala(insight, profile),
                    ),
                  ),

                if (_kShowMandala) SizedBox(height: spacing),

                // TODAY's Vedic Date Card
                // IMPORTANT: Only TODAY's data — never profile.samvatInfo (birth data)!
                Builder(builder: (context) {
                  final globalPanchang = _skyService.getTodayPanchang();
                  final insightPanchangRaw =
                      insight?.astrologicalData?['panchang'];
                  final insightPanchang = insightPanchangRaw is Map
                      ? Map<String, dynamic>.from(insightPanchangRaw)
                      : null;
                  final todaySamvatRaw =
                      insight?.astrologicalData?['todaySamvat'];
                  final todaySamvat = todaySamvatRaw is Map
                      ? Map<String, dynamic>.from(todaySamvatRaw)
                      : null;
                  // Merge today's sources (lowest → highest priority):
                  // 1. todaySamvat (lunar month, vikram year)
                  // 2. insight panchang (tithi, nakshatra, yoga)
                  // 3. global panchang (full panchang if available)
                  final Map<String, dynamic> merged = {};
                  if (todaySamvat != null) merged.addAll(todaySamvat);
                  if (insightPanchang != null) merged.addAll(insightPanchang);
                  if (globalPanchang != null) merged.addAll(globalPanchang);
                  final todayPanchang = merged.isNotEmpty ? merged : null;
                  return CosmicDateTimeCard(
                    samvat: todayPanchang,
                    brown: brown,
                  );
                }),

                SizedBox(height: spacing),

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

                          AppLogger.i(
                            'CosmicDashboard: Building chart positions',
                            category: LogCategory.ui,
                            data: {
                              'sliderDate': sliderDate.toIso8601String(),
                              'sliderValue': sliderValue,
                              'skyPositionsFound': skyPositions != null,
                              'skyPositionsPlanetCount':
                                  skyPositions?.length ?? 0,
                              'skyPositionsPlanets':
                                  skyPositions?.keys.toList(),
                              'currentPositionsFound': currentPositions != null,
                              'currentPositionsPlanetCount':
                                  currentPositions?.length ?? 0,
                              'currentPositionsPlanets':
                                  currentPositions?.keys.toList(),
                              'finalPositionsFound': positions != null,
                              'finalPositionsPlanetCount':
                                  positions?.length ?? 0,
                              'finalPositionsPlanets': positions?.keys.toList(),
                              'willShowChart':
                                  positions != null && positions.isNotEmpty,
                            },
                          );

                          if (positions == null || positions.isEmpty) {
                            AppLogger.w(
                              'CosmicDashboard: Hiding chart - no positions',
                              category: LogCategory.ui,
                              data: {
                                'sliderDate': sliderDate.toIso8601String(),
                                'skyPositionsNull': skyPositions == null,
                                'currentPositionsNull':
                                    currentPositions == null,
                              },
                            );
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

                // Today's Insight
                if (insight != null &&
                    (insight.displayTheme.isNotEmpty ||
                        insight.displayMessage.isNotEmpty)) ...[
                  CosmicInsightCard(insight: insight, brown: brown),
                  SizedBox(height: spacing),
                ],

                // Quick Actions
                CosmicQuickActions(
                  brown: brown,
                  onFullChart: () {
                    if (profile != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AstrologyDetailsPage(uid: _user!.uid),
                        ),
                      );
                    }
                  },
                  onAskAI: () {
                    Navigator.pop(context);
                    TabHandler.switchTab(0);
                  },
                ),

                const SizedBox(height: AppDimensions.spacingSection),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color brown) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.paddingSm),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: brown.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingXs),
        Text(
          'Cosmic Today',
          style: TextStyle(
            fontSize: AppTheme.holyCowTextSize,
            fontWeight: FontWeight.w600,
            color: brown,
          ),
        ),
      ],
    );
  }

  Widget _buildMuhuratPlaceholder(bool isDark, Color brown, Color cardColor) {
    final c = AppTheme.primaryColor;
    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Row(
          children: [
            AppLoadingIndicator(
              size: 16,
              strokeWidth: 2,
              color: c.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Text(
              'Loading time guidance...',
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w500,
                color: c.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(bool isDark, Color brown) {
    return ShimmerBox(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimensions.spacingLg),
            Container(
              width: 120,
              height: 24,
              decoration: BoxDecoration(
                color: brown.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: brown.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: brown.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Navigation Methods
  // ─────────────────────────────────────────────────────────────

  void _openAstroDetails(AstrologyProfile? profile) {
    if (profile == null || !profile.hasCalculatedData) {
      _showInfoSnackbar(
          'Complete your birth details to unlock the full chart.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AstrologyDetailsPage(uid: _user!.uid),
      ),
    );
  }

  void _openAyurvedaDetails(AyurvedaProfile? profile) {
    if (profile == null || !profile.hasData) {
      _showInfoSnackbar(
          'Complete your Ayurveda profile to see wellness details.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AyurvedaDetailsPage(uid: _user!.uid),
      ),
    );
  }

  void _openRitualCheckin(
      AyurvedaProfile? ayurvedaProfile, AstrologyProfile? astroProfile) {
    if (ayurvedaProfile == null || astroProfile == null) {
      _showInfoSnackbar('Finish your profiles to start today\'s ritual.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VikritiCheckInPage(
          ayurvedaProfile: ayurvedaProfile,
          astroProfile: astroProfile,
        ),
      ),
    );
  }

  void _shareMandala(DailyInsight? insight, AstrologyProfile? profile) {
    final theme = insight?.displayTheme ?? 'Daily Mandala';
    final content = insight?.displayMessage ??
        'Five alignments for today: cosmic, body, ritual, mindful, and connect.';

    ShareService.showInsightCardPreview(
      context: context,
      cardType: 'hero',
      title: theme,
      content: content,
      sunSign: profile?.sunSign,
      moonSign: profile?.moonSign,
      risingSign: profile?.ascendant,
    );
  }

  void _showMindfulPrompt() {
    final brown = AppTheme.primaryColor;

    AppBottomSheet.show(
      context,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.self_improvement_rounded,
              size: 48,
              color: Color(0xFF5C6BC0),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              'Take a Mindful Moment',
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w700,
                color: brown,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              'Pause. Take three deep breaths.\nNotice how you feel right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                height: 1.5,
                color: brown.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXxl),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'I\'m Present',
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5C6BC0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    showCustomSnackBar(context, message: message, duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating);
  }
}
