import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/features/astrology/presentation/widgets/timeline/muhurat_timeline_widget.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_date_time_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_panchang_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/upcoming_events_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/your_chart_mini_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/vedic_time_utils.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard/widgets/cosmic_sky_chart_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard/cosmic_dashboard_data.dart';
import 'package:aurogram/features/astrology/presentation/widgets/dialogs/house_details_dialog.dart';
import 'package:aurogram/features/astrology/data/utils/chart_utils.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/nakshatra_ring_widget.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Builds the full cosmic dashboard content panel with all cards.
class HolyCowCosmicContent extends StatelessWidget {
  final AstrologyProfile? profile;
  final DailyInsight? insight;
  final AyurvedaProfile? ayurvedaProfile;
  final DashboardLoadingState loadingState;
  final SkyPositionsService skyService;
  final ValueNotifier<double> sliderValueNotifier;
  final ValueNotifier<DateTime> sliderDateNotifier;
  final bool showTransitOverlay;
  final double chartBlendValue;
  final ValueChanged<double> onSliderChanged;
  final VoidCallback onResetToToday;
  final VoidCallback onToggleTransitOverlay;
  final ValueChanged<double> onBlendValueChanged;
  final Future<void> Function({bool isRetry}) onLoadSkyPositions;
  final Future<void> Function() onTriggerCachePopulation;

  /// Optional signal fired by the parent when the user taps "Today" on the
  /// sky chart — the nakshatra wheel listens and snaps back to today.
  final Listenable? wheelResetSignal;

  /// Live wheel state controller — passed directly to [NakshatraRingWidget]
  /// so independent cards on the page can listen to wheel position changes.
  final NakshatraWheelController? nakshatraController;

  const HolyCowCosmicContent({
    super.key,
    required this.profile,
    required this.insight,
    this.ayurvedaProfile,
    required this.loadingState,
    required this.skyService,
    required this.sliderValueNotifier,
    required this.sliderDateNotifier,
    required this.showTransitOverlay,
    required this.chartBlendValue,
    required this.onSliderChanged,
    required this.onResetToToday,
    required this.onToggleTransitOverlay,
    required this.onBlendValueChanged,
    required this.onLoadSkyPositions,
    required this.onTriggerCachePopulation,
    this.wheelResetSignal,
    this.nakshatraController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brown = AppTheme.primaryColor;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Fallback positions from insight transits (used when sky cache misses)
    final insightTransits =
        insight?.astrologicalData?['transits'] as Map<String, dynamic>?;

    final globalMuhurat = skyService.globalMuhurat;
    final todayPanchang = skyService.getTodayPanchang();

    // Merged samvat/panchang for the nakshatra ring's tithi strip.
    // Priority: todaySamvat (richest tithi data) → insightPanchang → globalPanchang.
    // Computed here (not inside the Builder closure) so it can be passed to
    // NakshatraRingWidget without restructuring the Builder tree.
    final todaySamvatRaw = insight?.astrologicalData?['todaySamvat'];
    final todaySamvatMap = todaySamvatRaw is Map
        ? Map<String, dynamic>.from(todaySamvatRaw)
        : null;
    final insightPanchangRaw = insight?.astrologicalData?['panchang'];
    final insightPanchangMap = insightPanchangRaw is Map
        ? Map<String, dynamic>.from(insightPanchangRaw)
        : null;
    final mergedSamvat = <String, dynamic>{};
    if (todaySamvatMap != null) mergedSamvat.addAll(todaySamvatMap);
    if (insightPanchangMap != null) {
      insightPanchangMap.forEach((k, v) { if (v != null) mergedSamvat[k] = v; });
    }
    if (todayPanchang != null) {
      todayPanchang.forEach((k, v) { if (v != null) mergedSamvat[k] = v; });
    }
    final nakshatraSamvat = mergedSamvat.isNotEmpty ? mergedSamvat : null;

    // Resolve today's nakshatra at the parent level so the desktop strip can
    // render the NAKSHATRA cell for signed-out users.  We follow the exact
    // same precedence chain the wheel widget uses (insight panchang first,
    // global panchang second) — that path is known to succeed where the
    // strip's prior fallback (todayPanchang/samvat keys only) failed.
    String? todayNakshatra;
    final panchangRawForStrip = insight?.astrologicalData?['panchang'];
    if (panchangRawForStrip is Map) {
      todayNakshatra = _extractNakshatraName(panchangRawForStrip['nakshatra']);
    }
    if (todayNakshatra == null || todayNakshatra.isEmpty) {
      if (todayPanchang != null) {
        todayNakshatra = _extractNakshatraName(todayPanchang['nakshatra']);
      }
    }
    // Last-ditch fallback: walk the merged samvat for any nakshatra-shaped key.
    if (todayNakshatra == null || todayNakshatra.isEmpty) {
      for (final key in const [
        'nakshatra',
        'nakshatra_name',
        'moonNakshatra',
      ]) {
        final extracted = _extractNakshatraName(mergedSamvat[key]);
        if (extracted != null && extracted.isNotEmpty) {
          todayNakshatra = extracted;
          break;
        }
      }
    }

    // Check actual renderable content, not just map keys — the card
    // itself returns SizedBox.shrink() when extracted values are empty,
    // so the surrounding spread must match to avoid phantom spacing.
    final hasPanchang = todayPanchang != null &&
        todayPanchang.isNotEmpty &&
        (todayPanchang['nakshatra'] != null ||
            todayPanchang['yoga'] != null ||
            todayPanchang['karana'] != null);
    final cardColor = isDark ? const Color(0xFF1A1A1C) : Colors.white;

    // ──────────────────────────────────────────────────────────────────────
    // Adaptive web/desktop layout
    //
    // The width passed into the LayoutBuilder is the width of the *cosmic
    // pane* — i.e. window − sidebar nav (88/280) − chat column (64/340). So
    // a 1500px window with the nav rail expanded and a signed-out 64px chat
    // rail leaves us with ~1156px here. The breakpoints below are tuned
    // against THAT pane width, not the raw window width.
    //
    // Four width tiers:
    //   < 1000  → single column, max ~760px (mobile-style reading width)
    //   1000–1199 → two columns, fluid (use whatever space we have, snug)
    //   1200–1499 → two columns, max ~1180px (laptop dashboard)
    //   ≥ 1500   → two columns, max ~1320px (large monitor dashboard)
    //
    // On two-column tiers:
    //   • A dense "today strip" replaces the lonely Vedic Date card.
    //   • Left column = wheel + Daily Vibe (adaptive width 420 → 520).
    //   • Right column (flex) = Sky Chart, Muhurat, Panchang, Your Chart, …
    //
    // `_secondaryCards()` is the single source of card order, so both
    // single-column and two-column tiers share content — only placement
    // differs.
    // ──────────────────────────────────────────────────────────────────────
    // Threshold to enable the two-column dashboard.  Calibrated so that even
    // a 1024px laptop window (cosmic pane ≈ 870px when signed-out with the
    // sidebar in icon-only mode) still gets the side-by-side wheel|sky
    // layout.  Anything below this collapses to a single-column stack that
    // reads cleanly on phones and tablets.
    const double desktopBreak = 820.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isWide = screenWidth >= desktopBreak;

        // Adaptive left-column width — narrower panes get a snugger wheel
        // column so the right column has enough room to be useful.
        //
        // Breakpoints calibrated against the cosmic *pane* width (not window):
        //   ≥ 1400 → 520 (large desktop, 1500+ Chrome window)
        //   ≥ 1100 → 480 (real-laptop desktop, ~1500 Chrome with chat rail)
        //   ≥ 950  → 420 (mid laptop)
        //   ≥ 880  → 380 (narrow laptop, 1280 window with chat history open)
        //   else   → 360 (tightest 2-col — 1024 window with sidebar collapsed)
        final leftColumnWidth = screenWidth >= 1400
            ? 520.0
            : screenWidth >= 1100
                ? 480.0
                : screenWidth >= 950
                    ? 420.0
                    : screenWidth >= 880
                        ? 380.0
                        : 360.0;

        // Adaptive content cap: wider on bigger monitors but never blown out.
        // The lower tier doesn't cap — at that width every pixel counts.
        final maxContentWidth = screenWidth >= 1400
            ? 1320.0
            : screenWidth >= 1100
                ? 1180.0
                : screenWidth >= desktopBreak
                    ? screenWidth // fluid — no cap, just gutters
                    : 760.0;

        final outerPadding = screenWidth > maxContentWidth
            ? (screenWidth - maxContentWidth) / 2
            : 16.0;
        final spacing = screenWidth > 700 ? 16.0 : 12.0;

        // Build the canonical wheel widget once — same instance is used in
        // both layouts so wheel state (controller, animations) is preserved
        // across tier transitions.  On desktop the wheel is the visual hero,
        // so we render it ABOVE the Daily Vibe card; on mobile we keep the
        // read-then-see order (vibe first, wheel below).
        final wheelWidget = _buildWheelWidget(wheelFirst: isWide);

        // The header — dense strip on desktop, full vertical card on mobile.
        final headerWidget = isWide
            ? _DesktopTodayStrip(
                samvat: nakshatraSamvat,
                todayPanchang: todayPanchang,
                brown: brown,
                todayNakshatra: todayNakshatra,
              )
            : CosmicDateTimeCard(samvat: nakshatraSamvat, brown: brown);

        // The bag of secondary cards in their canonical order. Inlined into
        // a single Column either in the right pane (desktop) or directly
        // under the wheel (mobile).
        final secondaryCards = _secondaryCards(
          context: context,
          isDark: isDark,
          brown: brown,
          cardColor: cardColor,
          insightTransits: insightTransits,
          globalMuhurat: globalMuhurat,
          todayPanchang: todayPanchang,
          hasPanchang: hasPanchang,
          spacing: spacing,
          nakshatraSamvat: nakshatraSamvat,
        );

        // The sign-in upsell — only visible when signed-out.
        //
        // On desktop the right column is mostly empty for signed-out users
        // (sky chart / muhurat / events / panchang all require data), so we
        // promote the CTA into the right column itself (vertical variant) —
        // this fills the dead space AND surfaces the CTA closer to the wheel.
        //
        // On mobile/tablet the single-column layout doesn't have a dead
        // space problem, so the horizontal banner sits at the bottom as before.
        final isSignedOut = FirebaseAuth.instance.currentUser == null;
        final desktopInlineCta = isSignedOut && isWide
            ? _SignInCtaBanner(
                brown: brown,
                isDark: isDark,
                horizontal: false,
              )
            : null;
        final mobileCtaBanner = isSignedOut && !isWide
            ? _SignInCtaBanner(
                brown: brown,
                isDark: isDark,
                horizontal: false,
              )
            : null;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: outerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              headerWidget,
              SizedBox(height: spacing),
              if (isWide) ...[
                // Two-column dashboard
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: leftColumnWidth,
                      child: wheelWidget,
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...secondaryCards,
                          if (desktopInlineCta != null) ...[
                            desktopInlineCta,
                            SizedBox(height: spacing),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16 + bottomInset),
              ] else ...[
                // Single-column stack (mobile + small tablet)
                wheelWidget,
                SizedBox(height: spacing),
                ...secondaryCards,
                if (mobileCtaBanner != null) ...[
                  mobileCtaBanner,
                  SizedBox(height: spacing),
                ],
                SizedBox(height: 16 + bottomInset),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Build the nakshatra wheel + Daily Vibe widget. Extracted to keep
  /// the layout switch in [build] readable.
  ///
  /// [wheelFirst] flips the internal Column order so on desktop layouts the
  /// wheel renders ABOVE the Daily Vibe card (wheel is the visual hero).
  Widget _buildWheelWidget({bool wheelFirst = false}) {
    return Builder(builder: (context) {
      // Re-resolve samvat / panchang inside this builder so the wheel
      // sees the freshest data on rebuilds.
      final insightTransits =
          insight?.astrologicalData?['transits'] as Map<String, dynamic>?;
      final _ = insightTransits; // suppress unused-local lint
      final todaySamvatRaw = insight?.astrologicalData?['todaySamvat'];
      final todaySamvatMap = todaySamvatRaw is Map
          ? Map<String, dynamic>.from(todaySamvatRaw)
          : null;
      final insightPanchangRaw = insight?.astrologicalData?['panchang'];
      final insightPanchangMap = insightPanchangRaw is Map
          ? Map<String, dynamic>.from(insightPanchangRaw)
          : null;
      final mergedSamvat = <String, dynamic>{};
      if (todaySamvatMap != null) mergedSamvat.addAll(todaySamvatMap);
      if (insightPanchangMap != null) {
        insightPanchangMap.forEach((k, v) {
          if (v != null) mergedSamvat[k] = v;
        });
      }
      final tp = skyService.getTodayPanchang();
      if (tp != null) {
        tp.forEach((k, v) {
          if (v != null) mergedSamvat[k] = v;
        });
      }
      final nakshatraSamvat = mergedSamvat.isNotEmpty ? mergedSamvat : null;

      String? todayNakshatra;
      final panchangRaw = insight?.astrologicalData?['panchang'];
      if (panchangRaw is Map) {
        todayNakshatra = _extractNakshatraName(panchangRaw['nakshatra']);
      }
      if (todayNakshatra == null || todayNakshatra.isEmpty) {
        final globalP = skyService.getTodayPanchang();
        if (globalP != null) {
          todayNakshatra = _extractNakshatraName(globalP['nakshatra']);
        }
      }
      final birthNakshatra = profile?.moonNakshatra ?? profile?.nakshatra;
      final lagnaNakshatra = profile?.lagnaNakshatra;
      return NakshatraRingWidget(
        todayNakshatra: todayNakshatra,
        birthNakshatra: birthNakshatra,
        lagnaNakshatra: lagnaNakshatra,
        todaySamvat: nakshatraSamvat,
        wheelResetSignal: wheelResetSignal,
        controller: nakshatraController,
        insight: insight,
        wheelFirst: wheelFirst,
        onDateChanged: (date) {
          // Sync both notifiers so the sky-chart slider stays in
          // visual agreement with the wheel's day selection.
          // Slider maps 0..1 → −30..+30 days (range = 60 days).
          final today = DateTime.now();
          final daysOffset = date
              .difference(DateTime(today.year, today.month, today.day))
              .inDays;
          sliderValueNotifier.value =
              (0.5 + daysOffset / 60.0).clamp(0.0, 1.0);
          sliderDateNotifier.value = date;
        },
      );
    });
  }

  /// Build the bag of supporting cards in their canonical display order.
  /// Returned as a flat List so the caller can place them in either a
  /// single-column stack (mobile) or a right-pane Column (desktop).
  List<Widget> _secondaryCards({
    required BuildContext context,
    required bool isDark,
    required Color brown,
    required Color cardColor,
    required Map<String, dynamic>? insightTransits,
    required Map<String, dynamic>? globalMuhurat,
    required Map<String, dynamic>? todayPanchang,
    required bool hasPanchang,
    required double spacing,
    required Map<String, dynamic>? nakshatraSamvat,
  }) {
    return [
              // Current Sky with optional Birth Chart overlay
              if (loadingState.isSkyLoaded) ...[
                ValueListenableBuilder<double>(
                  valueListenable: sliderValueNotifier,
                  builder: (context, sliderValue, _) {
                    return ValueListenableBuilder<DateTime>(
                      valueListenable: sliderDateNotifier,
                      builder: (context, sliderDate, _) {
                        final skyPositions =
                            skyService.getPositionsForDate(sliderDate);
                        // Only fall back to insightTransits for TODAY — using
                        // today's planet positions for a past/future date would
                        // show the wrong sky mislabelled as that date.
                        final today = DateTime.now();
                        final isSliderToday =
                            sliderDate.year == today.year &&
                            sliderDate.month == today.month &&
                            sliderDate.day == today.day;
                        final positions =
                            skyPositions != null && skyPositions.isNotEmpty
                                ? skyPositions
                                : (isSliderToday ? insightTransits : null);

                        if (positions == null || positions.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return CosmicSkyChartCard(
                          todayPositions: positions,
                          birthChartData: profile?.birthChartData,
                          isDark: isDark,
                          sliderValue: sliderValue,
                          sliderDate: sliderDate,
                          skyDataLoaded: loadingState.isSkyLoaded,
                          skyDataLoading: loadingState.isSkyLoading,
                          showTransitOverlay: showTransitOverlay,
                          chartBlendValue: chartBlendValue,
                          onSliderChanged: onSliderChanged,
                          onResetToToday: onResetToToday,
                          onToggleTransitOverlay: onToggleTransitOverlay,
                          onBlendValueChanged: onBlendValueChanged,
                          onLoadSkyPositions: onLoadSkyPositions,
                          onTriggerCachePopulation: onTriggerCachePopulation,
                          getPositionsForDate: skyService.getPositionsForDate,
                          getInterpolatedPositions:
                              skyService.getInterpolatedPositions,
                          // TODO: re-enable when Current Sky page is improved
                          onExploreSky: null,
                          onExploreBirthChart: profile != null
                              ? () {
                                  final uid =
                                      FirebaseAuth.instance.currentUser?.uid ??
                                          '';
                                  context.push(
                                      '${RouteNames.astrologyDetails}/$uid');
                                }
                              : null,
                          onHouseTap: (houseNumber, currentPositions) {
                            _showSkyHouseDialog(
                              context,
                              profile,
                              houseNumber,
                              currentPositions,
                              isDark,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: spacing),
              ],

              // Muhurat section (time guidance).  The placeholder is only
              // shown to signed-in users — for signed-out users the muhurat
              // service never resolves, so a perpetual "Loading…" card just
              // looks broken.  Skipping it cleanly for signed-out users.
              if (globalMuhurat != null && globalMuhurat.isNotEmpty) ...[
                MuhuratTimelineWidget(muhurat: globalMuhurat),
                SizedBox(height: spacing),
              ] else if (loadingState.isMuhuratLoading &&
                  FirebaseAuth.instance.currentUser != null) ...[
                _HolyCowMuhuratPlaceholder(cardColor: cardColor),
                SizedBox(height: spacing),
              ],

              // Upcoming Planetary Events
              // The card internally filters to major planets and may
              // return SizedBox.shrink() — only add spacing when the
              // card will actually render content.
              if (loadingState.isEventsLoaded &&
                  skyService.hasUpcomingEvents &&
                  skyService.allUpcomingEvents.any((e) =>
                      const ['Sun', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn']
                          .contains(e.planet))) ...[
                UpcomingEventsCard(
                  brown: brown,
                  events: skyService.allUpcomingEvents,
                  maxEvents: 8,
                ),
                SizedBox(height: spacing),
              ],

              // Panchang (global only)
              if (hasPanchang) ...[
                CosmicPanchangCard(
                    panchang: todayPanchang!, brown: brown),
                SizedBox(height: spacing),
              ],

              // Current Balance (Ayurveda Vikriti) — tappable → Ayurveda Details
              if (ayurvedaProfile != null &&
                  ayurvedaProfile!.prakriti != null) ...[
                GestureDetector(
                  onTap: () {
                    final uid =
                        FirebaseAuth.instance.currentUser?.uid ?? '';
                    context.push('${RouteNames.ayurvedaDetails}/$uid');
                  },
                  child: TodaysBalanceCard(
                    prakriti: ayurvedaProfile!.prakriti!,
                    vikriti: ayurvedaProfile!.vikriti,
                    isCalculating: false,
                    lastCheckIn: ayurvedaProfile!.lastCheckIn,
                    isDark: isDark,
                  ),
                ),
                SizedBox(height: spacing),
              ],

              // Your Birth Stars card (matches profile card style)
              if (profile != null) ...[
                YourChartMiniCard(
                  profile: profile!,
                  brown: brown,
                  onTap: () {
                    final uid =
                        FirebaseAuth.instance.currentUser?.uid ?? '';
                    context.push('${RouteNames.astrologyDetails}/$uid');
                  },
                ),
                SizedBox(height: spacing),
              ],

              // (Current Energy moved into the Daily Vibe hero card at the top
              // of the page — the NakshatraRingWidget now consumes `insight`
              // and renders its message inline. The standalone card here would
              // duplicate that content, so it's been removed.)

              // ── Mood check-in + Week forecast — bottom of page ──────────────
              // These live here, not inside NakshatraRingWidget, so they are
              // independent cards that can be freely repositioned.
              // NakshatraMoodCheckInCard collapses when the wheel is not at
              // today; NakshatraWeekForecastCard hides when birth data is absent.
              if (nakshatraController != null) ...[
                NakshatraMoodCheckInCard(controller: nakshatraController!),
                SizedBox(height: spacing),
                NakshatraWeekForecastCard(
                  controller: nakshatraController!,
                  todaySamvat: nakshatraSamvat,
                ),
                SizedBox(height: spacing),
              ],

              // (Sign-in CTA used to live here — moved out to a full-width
              // banner below the 2-column row so it doesn't lopside the right
              // column.  See HolyCowCosmicContent.build → ctaBanner.)

              const SizedBox(height: AppDimensions.spacingSection),
    ];
  }

  /// Extract a nakshatra name from panchang data which may be a plain
  /// String or a Map with a 'name' key.
  static String? _extractNakshatraName(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    if (value is Map) {
      return value['name']?.toString() ??
          value['nakshatra']?.toString() ??
          value.values.firstOrNull?.toString();
    }
    final s = value.toString();
    return s.isNotEmpty ? s : null;
  }

  /// Build and show the per-house current-state popup for a tap on the
  /// Current Sky chart. Combines transiting planets (from [currentPositions])
  /// with the user's natal interpretation and the biweekly sky reading
  /// stored on [profile].
  void _showSkyHouseDialog(
    BuildContext context,
    AstrologyProfile? profile,
    int houseNumber,
    Map<String, dynamic> currentPositions,
    bool isDark,
  ) {
    final lagnaSignIndex =
        ChartUtils.getLagnaSignIndex(profile?.birthChartData);

    // In the sign-fixed Current Sky chart the geometric tap position maps
    // directly to a zodiac sign (1=Aries, 2=Taurus, …), NOT to the user's
    // house number.  Convert sign position → actual house number so every
    // lookup below (natal interpretation, sky reading, planet filter) uses
    // the correct house.
    final tappedSignIndex = houseNumber - 1; // 0-based (0=Aries)
    final actualHouse =
        ((tappedSignIndex - lagnaSignIndex + 12) % 12) + 1;

    final zodiacSign =
        HouseSignifications.getSignForHouse(actualHouse, lagnaSignIndex);
    final signLord = HouseSignifications.getSignLord(zodiacSign);

    // Walk current sky positions and pick those whose sign maps to this house.
    final planets = <String>[];
    currentPositions.forEach((planet, data) {
      if (data is! Map) return;
      if (planet.toLowerCase() == 'ascendant') return;

      final m = Map<String, dynamic>.from(
          data.map((k, v) => MapEntry(k.toString(), v)));
      final sign = (m['sign'] as String?)?.toLowerCase() ?? '';
      int? signIndex = ChartConstants.signToIndex[sign];
      if (signIndex == null) {
        final lon = m['longitude'];
        if (lon is num) signIndex = (lon / 30).floor() % 12;
      }
      if (signIndex == null) return;

      final h = ((signIndex - lagnaSignIndex + 12) % 12) + 1;
      if (h == actualHouse) planets.add(planet);
    });

    // Current Sky context — sky reading only, no natal interpretation.
    SkyHouseReading? skyReading;
    String? cycleEndDate;
    final houses = profile?.skyHouseReadings?['houses'];
    if (houses is Map) {
      final raw = houses['$actualHouse'] ?? houses[actualHouse];
      if (raw is Map) {
        skyReading = SkyHouseReading(
          headline: (raw['headline'] as String?)?.trim(),
          reading: (raw['reading'] as String?)?.trim(),
          focus: (raw['focus'] as String?)?.trim(),
          watch: (raw['watch'] as String?)?.trim(),
        );
      }
      cycleEndDate = profile?.skyHouseReadings?['cycleEndDate'] as String?;
    }

    HouseDetailsDialog.show(
      context,
      HouseInfo(
        houseNumber: actualHouse,
        zodiacSign: zodiacSign,
        signLord: signLord,
        planets: planets,
        skyReading: skyReading,
        cycleEndDate: cycleEndDate,
      ),
      isDark,
    );
  }

}

/// Muhurat loading placeholder
class _HolyCowMuhuratPlaceholder extends StatelessWidget {
  final Color cardColor;
  const _HolyCowMuhuratPlaceholder({required this.cardColor});

  @override
  Widget build(BuildContext context) {
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
}

// HolyCowCosmicSkeleton is defined in holycow_empty_states.dart

// ─────────────────────────────────────────────────────────────────────────
// Desktop "today strip"
//
// Replaces the lonely Vedic Date card on wide layouts. A dense horizontal
// row of today's high-level cosmic facts that sits above the two-column
// dashboard and gives an at-a-glance "where am I in the cosmos" feel.
//
// Content (left → right):
//   • Western date  • Vedic time (Pr·Gh·Pa)
//   • Tithi (e.g. "Krishna Saptami")
//   • Lunar month (e.g. "Vaishakha Masa")
//   • Today's nakshatra
//   • ⓘ info button
//
// Cells with missing data are skipped entirely so the strip never looks
// half-loaded.
// ─────────────────────────────────────────────────────────────────────────

class _DesktopTodayStrip extends StatefulWidget {
  final Map<String, dynamic>? samvat;
  final Map<String, dynamic>? todayPanchang;
  final Color brown;

  /// Pre-resolved nakshatra name from the parent — uses the same insight
  /// panchang path the wheel relies on, which is the only path that works
  /// for signed-out users (samvat/todayPanchang don't carry nakshatra for them).
  final String? todayNakshatra;

  const _DesktopTodayStrip({
    required this.samvat,
    required this.todayPanchang,
    required this.brown,
    this.todayNakshatra,
  });

  @override
  State<_DesktopTodayStrip> createState() => _DesktopTodayStripState();
}

class _DesktopTodayStripState extends State<_DesktopTodayStrip> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Re-render the vedic clock every 15s — same cadence as CosmicDateTimeCard.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final c = AppTheme.primaryColor;

    final samvat = widget.samvat;
    final vedicTimeShort = VedicTimeUtils.getVedicTimeShort(_now);

    // Tithi (e.g. "Krishna Saptami") — derived from the same data that
    // CosmicDateTimeCard parses, but assembled horizontally.
    final fullVedicDate = VedicTimeUtils.buildFullVedicDate(samvat);
    final lunarMonth = samvat?['lunar_month_full_name']?.toString() ??
        samvat?['lunar_month_name']?.toString() ??
        samvat?['lunarMonthFull']?.toString() ??
        samvat?['lunarMonth']?.toString();
    String? tithiLine;
    if (fullVedicDate != null && lunarMonth != null) {
      tithiLine = fullVedicDate.replaceFirst(lunarMonth, '').trim();
      if (tithiLine.isEmpty) tithiLine = null;
    } else {
      tithiLine = fullVedicDate;
    }
    final monthLine = lunarMonth != null ? '$lunarMonth Masa' : null;

    // Today's nakshatra — prefer the parent-resolved value (uses the
    // insight panchang path which works for signed-out users); fall back to
    // todayPanchang / samvat keys when running on legacy data paths.
    String? todayNakshatra = widget.todayNakshatra;
    if (todayNakshatra == null || todayNakshatra.isEmpty) {
      for (final raw in [
        widget.todayPanchang?['nakshatra'],
        samvat?['nakshatra'],
        samvat?['nakshatra_name'],
        samvat?['moonNakshatra'],
      ]) {
        if (raw is String && raw.isNotEmpty) {
          todayNakshatra = raw;
          break;
        }
        if (raw is Map) {
          final name = raw['name']?.toString();
          if (name != null && name.isNotEmpty) {
            todayNakshatra = name;
            break;
          }
        }
      }
    }

    // Today (Western)
    final today = _now;
    final weekdayShort = _weekdayShort(today.weekday).toUpperCase();
    final monthShort = _monthShort(today.month).toUpperCase();
    final dateStr = '$weekdayShort $monthShort ${today.day}';

    // Vedic weekday (Vaar) — derived purely from the date, so this ALWAYS
    // renders regardless of auth state.  Gives signed-out users a richer
    // strip even when panchang data is unavailable.  Each day corresponds
    // to a classical planetary lord (e.g. Saturday → Saturn → Shanivar).
    final vaarLabel = _vedicWeekday(today.weekday);
    final vaarPlanet = _vedicWeekdayPlanet(today.weekday);

    // Moon phase — astronomical approximation using a reference new moon
    // and the synodic month (29.530588 days).  Computed from the date
    // alone so it works for all users.  Lovely delight element.
    final moonPhase = _moonPhase(today);

    // Build the cells we want to show, skipping any without data.
    final cells = <Widget>[
      _StripCell(
        label: 'TODAY',
        value: dateStr,
        c: c,
      ),
      _StripCell(
        label: 'VEDIC',
        value: vedicTimeShort,
        c: c,
      ),
      // VAAR is always present — purely date-derived.
      _StripCell(
        label: 'VAAR',
        value: '$vaarPlanet $vaarLabel',
        c: c,
      ),
      // MOON phase — always present, also purely date-derived.
      _StripCell(
        label: 'MOON',
        value: '${moonPhase.$1} ${moonPhase.$2}',
        c: c,
      ),
      if (tithiLine != null && tithiLine.isNotEmpty)
        _StripCell(
          label: 'TITHI',
          value: tithiLine,
          c: c,
        ),
      if (monthLine != null)
        _StripCell(
          label: 'MASA',
          value: monthLine,
          c: c,
        ),
      if (todayNakshatra != null && todayNakshatra.isNotEmpty)
        _StripCell(
          label: 'NAKSHATRA',
          value: '☽ $todayNakshatra',
          c: c,
        ),
    ];

    return Material(
      color: cardColor,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingLg,
          vertical: AppDimensions.paddingMd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Cells with thin vertical dividers between them.
            // Cells size to their content — they don't stretch.  This keeps
            // the strip readable for signed-out users (who only have TODAY +
            // VEDIC) while still looking balanced when all 5 cells render.
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMd,
                  ),
                  color: c.withValues(alpha: 0.10),
                ),
              cells[i],
            ],
            // Push the ⓘ icon to the far right regardless of cell count.
            const Spacer(),
            // ⓘ info — defers to the same explainer sheet as the mobile card.
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                AppBottomSheet.show(
                  context,
                  child: VedicTimeInfoSheet(isDark: isDark, brown: c),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: c.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekdayShort(int wd) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(wd - 1).clamp(0, 6)];
  }

  static String _monthShort(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[(m - 1).clamp(0, 11)];
  }

  // Vedic weekday names (Vaar). DateTime.weekday is 1-7 where 1=Monday.
  static String _vedicWeekday(int wd) {
    const names = [
      'Somavar',     // Mon — Moon
      'Mangalvar',   // Tue — Mars
      'Budhvar',     // Wed — Mercury
      'Guruvar',     // Thu — Jupiter
      'Shukravar',   // Fri — Venus
      'Shanivar',    // Sat — Saturn
      'Ravivar',     // Sun — Sun
    ];
    return names[(wd - 1).clamp(0, 6)];
  }

  // Classical planetary lord glyph for each weekday — a subtle visual
  // anchor so the VAAR cell reads as a piece of astrology, not just a
  // translation.
  static String _vedicWeekdayPlanet(int wd) {
    const glyphs = ['☾', '♂', '☿', '♃', '♀', '♄', '☉'];
    return glyphs[(wd - 1).clamp(0, 6)];
  }

  /// Approximate moon phase for a given date.  Returns a (emoji, label)
  /// tuple computed from a reference new-moon epoch and the synodic
  /// period.  Accurate to within ~½ day, which is plenty for a UI cell.
  ///
  /// Reference: Jan 6 2000 18:14 UTC was an exact new moon.
  /// Synodic month: 29.530588 days.
  static (String, String) _moonPhase(DateTime date) {
    // Days since reference new moon in UTC.
    final ref = DateTime.utc(2000, 1, 6, 18, 14);
    final days = date.toUtc().difference(ref).inSeconds / 86400.0;
    final synodic = 29.530588;
    var phase = (days / synodic) % 1.0;
    if (phase < 0) phase += 1.0;

    // 8 standard moon-phase buckets.  Cutpoints are roughly 1/16 fractions
    // so each named phase gets equal sky time around its peak.
    if (phase < 0.0625) return ('🌑', 'New');
    if (phase < 0.1875) return ('🌒', 'Waxing crescent');
    if (phase < 0.3125) return ('🌓', 'First quarter');
    if (phase < 0.4375) return ('🌔', 'Waxing gibbous');
    if (phase < 0.5625) return ('🌕', 'Full');
    if (phase < 0.6875) return ('🌖', 'Waning gibbous');
    if (phase < 0.8125) return ('🌗', 'Last quarter');
    if (phase < 0.9375) return ('🌘', 'Waning crescent');
    return ('🌑', 'New');
  }
}

/// Small two-line cell used inside [_DesktopTodayStrip]. Upper line is the
/// label (small, low-opacity, letter-spaced); lower line is the value
/// (regular weight, full opacity, single-line ellipsised).
class _StripCell extends StatelessWidget {
  final String label;
  final String value;
  final Color c;
  const _StripCell({required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.holyCowTextSize - 4,
            fontWeight: FontWeight.w600,
            color: c.withValues(alpha: 0.45),
            letterSpacing: 0.8,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTheme.holyCowTextSize,
            fontWeight: FontWeight.w600,
            color: c,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Sign-in CTA banner
//
// A full-width brand-aligned upsell shown only when the user is signed-out.
// Lives below the two-column dashboard so it doesn't lopside either column.
//
// Two layouts:
//   • horizontal (desktop): icon + headline column + benefit chips + button
//     in a single row — fills the dashboard width like a footer banner.
//   • vertical   (mobile):  icon + headline + benefits stacked + full-width
//     button — a closing prompt at the bottom of the scroll.
// ─────────────────────────────────────────────────────────────────────────
class _SignInCtaBanner extends StatelessWidget {
  final Color brown;
  final bool isDark;
  final bool horizontal;

  const _SignInCtaBanner({
    required this.brown,
    required this.isDark,
    required this.horizontal,
  });

  static const _benefits = <(IconData, String)>[
    (Icons.auto_awesome_rounded, 'Personalized readings'),
    (Icons.public_rounded, 'Your full birth chart'),
    (Icons.timeline_rounded, 'Track moods across cycles'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    final cardColor = isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(RouteNames.login);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.withValues(alpha: isDark ? 0.18 : 0.10),
                c.withValues(alpha: isDark ? 0.06 : 0.02),
              ],
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: horizontal
                ? AppDimensions.paddingXxl
                : AppDimensions.paddingLg,
            vertical: horizontal
                ? AppDimensions.paddingLg
                : AppDimensions.paddingLg,
          ),
          child: horizontal
              ? _buildHorizontal(context, c)
              : _buildVertical(context, c),
        ),
      ),
    );
  }

  Widget _buildHorizontal(BuildContext context, Color c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icon medallion
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 26,
            color: c,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingLg),
        // Headline + subtitle
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unlock your cosmic blueprint',
                style: TextStyle(
                  fontSize: AppTheme.holyCowTextSize + 4,
                  fontWeight: FontWeight.w700,
                  color: c,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sign in to add your birth details and see how today\'s sky speaks to you.',
                style: TextStyle(
                  fontSize: AppTheme.holyCowTextSize,
                  fontWeight: FontWeight.w500,
                  color: c.withValues(alpha: 0.7),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spacingLg),
        // Benefit chips — collapse gracefully on narrower widths
        Expanded(
          flex: 6,
          child: Wrap(
            spacing: AppDimensions.spacingMd,
            runSpacing: AppDimensions.spacingSm,
            alignment: WrapAlignment.center,
            children: [
              for (final (icon, label) in _benefits)
                _CtaBenefitChip(icon: icon, label: label, color: c),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spacingLg),
        // Primary CTA button
        FilledButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            context.push(RouteNames.login);
          },
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('Sign in'),
          style: FilledButton.styleFrom(
            backgroundColor: c,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVertical(BuildContext context, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 22,
                color: c,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Unlock your cosmic blueprint',
                    style: TextStyle(
                      fontSize: AppTheme.holyCowTextSize + 2,
                      fontWeight: FontWeight.w700,
                      color: c,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sign in to see how today\'s sky speaks to you.',
                    style: TextStyle(
                      fontSize: AppTheme.holyCowTextSize - 1,
                      fontWeight: FontWeight.w500,
                      color: c.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        Wrap(
          spacing: AppDimensions.spacingMd,
          runSpacing: AppDimensions.spacingSm,
          children: [
            for (final (icon, label) in _benefits)
              _CtaBenefitChip(icon: icon, label: label, color: c),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push(RouteNames.login);
            },
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Sign in'),
            style: FilledButton.styleFrom(
              backgroundColor: c,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small pill used inside [_SignInCtaBanner] benefits row.
class _CtaBenefitChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CtaBenefitChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.75)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.holyCowTextSize - 1,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
