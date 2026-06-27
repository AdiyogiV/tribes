import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/presentation/widgets/timeline/muhurat_timeline_widget.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_date_time_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard/cosmic_dashboard_data.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/features/astrology/domain/astro_calendar_service.dart';
import 'package:aurogram/shared/services/widget_data_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/nakshatra_ring_widget.dart';
import 'package:aurogram/features/astrology/presentation/pages/holycow/widgets/holycow_panchang_resolver.dart';
import 'package:aurogram/features/astrology/presentation/pages/holycow/widgets/holycow_secondary_cards.dart';
import 'package:aurogram/features/astrology/presentation/pages/holycow/widgets/holycow_muhurat_placeholder.dart';
import 'package:aurogram/features/astrology/presentation/pages/holycow/widgets/holycow_desktop_today_strip.dart';
import 'package:aurogram/features/astrology/presentation/pages/holycow/widgets/holycow_signin_cta_banner.dart';

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

  /// Slider range in days (±N from today).  Used to compute the slider ↔
  /// days offset mapping.  Defaults to 180 for the extended calendar range.
  final int sliderRangeDays;

  /// Optional calendar service for extended-range position lookups.
  final AstroCalendarService? calendarService;

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
    this.sliderRangeDays = 180,
    this.calendarService,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brown = AppTheme.primaryColor;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final todayPanchang = skyService.getTodayPanchang();

    // Single source of truth for the panchang merge + nakshatra precedence
    // chain (shared with the wheel builder via HolyCowPanchangResolver).
    final panchang = HolyCowPanchangResolver.resolve(
      insight: insight,
      skyService: skyService,
      calendarService: calendarService,
    );
    final nakshatraSamvat = panchang.nakshatraSamvat;
    final todayNakshatra = panchang.todayNakshatra;

    // Push the fully-merged samvat to native home screen widgets.
    // This is the most complete data source (insight + panchang + samvat).
    if (nakshatraSamvat != null) {
      WidgetDataService.instance.updateWidgetData(nakshatraSamvat);
    }

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
        // across tier transitions.  The text insight (Daily Vibe card)
        // renders ABOVE the wheel (wheelFirst: false) so the guidance text
        // sits on top and the wheel below it on both mobile and desktop.
        final wheelWidget = _buildWheelWidget(wheelFirst: false);

        // The header — dense strip on desktop, split cards on mobile.
        // Desktop: single dense strip.
        // Mobile: VedicTimeCard (clock + Pr·Gh·Pa) + VedicDateCard (month, tithi).
        final headerWidget = ValueListenableBuilder<DateTime>(
          valueListenable: sliderDateNotifier,
          builder: (context, sliderDate, _) {
            final today = DateTime.now();
            final isToday = sliderDate.year == today.year &&
                sliderDate.month == today.month &&
                sliderDate.day == today.day;

            // Single source of truth: calendarService normalises month
            // names (e.g. "Jyeshtam" → "Jyeshtha") and covers all dates
            // including today.  Fall back to the merged samvat only when
            // calendarService hasn't loaded yet.
            final dateSamvat =
                calendarService?.getPanchangForDate(sliderDate) ??
                    (isToday ? nakshatraSamvat : null);

            if (isWide) {
              return HolyCowDesktopTodayStrip(
                samvat: dateSamvat ?? nakshatraSamvat,
                todayPanchang: todayPanchang,
                brown: brown,
                todayNakshatra: todayNakshatra,
                selectedDate: isToday ? null : sliderDate,
                selectedDatePanchang: dateSamvat,
              );
            } else {
              // On mobile the split cards handle everything.
              return const SizedBox.shrink();
            }
          },
        );

        // Mobile: single combined card (clock left, date center, time right)
        final combinedCardWidget = ValueListenableBuilder<DateTime>(
          valueListenable: sliderDateNotifier,
          builder: (context, sliderDate, _) {
            final today = DateTime.now();
            final isToday = sliderDate.year == today.year &&
                sliderDate.month == today.month &&
                sliderDate.day == today.day;
            final dateSamvat =
                calendarService?.getPanchangForDate(sliderDate) ??
                    (isToday ? nakshatraSamvat : null);
            return VedicCombinedCard(
              samvat: dateSamvat,
              brown: brown,
              selectedDate: isToday ? null : sliderDate,
              onResetToToday: onResetToToday,
              nakshatraName: isToday ? todayNakshatra : null,
            );
          },
        );

        // The bag of secondary cards in their canonical order. Inlined into
        // a single Column either in the right pane (desktop) or directly
        // under the wheel (mobile).
        //
        // On mobile the wheel + text-insight combo is injected directly
        // BELOW the Current Sky card. On desktop the wheel lives in its own
        // left column, so we don't inject it into the secondary list.
        final secondaryCards = HolyCowSecondaryCards(
          profile: profile,
          insight: insight,
          ayurvedaProfile: ayurvedaProfile,
          loadingState: loadingState,
          skyService: skyService,
          calendarService: calendarService,
          sliderValueNotifier: sliderValueNotifier,
          sliderDateNotifier: sliderDateNotifier,
          showTransitOverlay: showTransitOverlay,
          chartBlendValue: chartBlendValue,
          onSliderChanged: onSliderChanged,
          onResetToToday: onResetToToday,
          onToggleTransitOverlay: onToggleTransitOverlay,
          onBlendValueChanged: onBlendValueChanged,
          onLoadSkyPositions: onLoadSkyPositions,
          onTriggerCachePopulation: onTriggerCachePopulation,
          nakshatraController: nakshatraController,
          spacing: spacing,
          insertAfterSkyCard: isWide ? null : wheelWidget,
        );

        // Time-guidance (muhurat) card — sits directly beneath the date card.
        final muhuratCard = _buildMuhuratCard(
          cardColor: cardColor,
          spacing: spacing,
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
            ? HolyCowSignInCtaBanner(
                brown: brown,
                isDark: isDark,
                horizontal: false,
              )
            : null;
        final mobileCtaBanner = isSignedOut && !isWide
            ? HolyCowSignInCtaBanner(
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
              if (isWide) ...[
                headerWidget,
                SizedBox(height: spacing),
                // Time guidance sits right under the date strip.
                muhuratCard,
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
                          secondaryCards,
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
                // Combined clock+date card → muhurat → sky card → wheel+insight
                //
                // The wheel itself uses OverlayPortal internally so its
                // magnified visual paints ABOVE adjacent cards regardless of
                // normal Column paint order. It now sits directly below the
                // Current Sky card (injected into secondaryCards).
                combinedCardWidget,
                SizedBox(height: spacing + 10),
                // Falls back to combined card for non-today selected dates
                headerWidget,
                // Time guidance sits right under the date card.
                muhuratCard,
                secondaryCards,
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
      // Re-resolve panchang inside this builder so the wheel sees the
      // freshest data on rebuilds. Same resolver as build() — one source.
      final panchang = HolyCowPanchangResolver.resolve(
        insight: insight,
        skyService: skyService,
        calendarService: calendarService,
      );
      final nakshatraSamvat = panchang.nakshatraSamvat;
      final todayNakshatra = panchang.todayNakshatra;
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
          final today = DateTime.now();
          final daysOffset = date
              .difference(DateTime(today.year, today.month, today.day))
              .inDays;
          sliderValueNotifier.value =
              (0.5 + daysOffset / (2 * sliderRangeDays)).clamp(0.0, 1.0);
          sliderDateNotifier.value = date;
        },
      );
    });
  }

  /// Build the bag of supporting cards in their canonical display order.
  /// Returned as a flat List so the caller can place them in either a
  /// single-column stack (mobile) or a right-pane Column (desktop).
  /// Muhurat / "time guidance" card. Lives directly under the date card.
  /// Single source of truth: AstroCalendarService muhurat for the selected
  /// date (the calendar carries muhurat for every day in range).
  Widget _buildMuhuratCard({
    required Color cardColor,
    required double spacing,
  }) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: sliderDateNotifier,
      builder: (context, sliderDate, _) {
        final today = DateTime.now();
        final daysDiff = sliderDate
            .difference(DateTime(today.year, today.month, today.day))
            .inDays
            .abs();

        // One source of truth: the astro calendar carries muhurat for every
        // day in range, so it serves today and every other date alike.
        final calMuhurat = calendarService?.getMuhuratForDate(sliderDate);
        if (calMuhurat != null && calMuhurat.isNotEmpty) {
          return Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: MuhuratTimelineWidget(muhurat: calMuhurat),
          );
        }

        // Loading placeholder only for today window.
        if (loadingState.isMuhuratLoading &&
            daysDiff <= 1 &&
            FirebaseAuth.instance.currentUser != null) {
          return Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: HolyCowMuhuratPlaceholder(cardColor: cardColor),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

}
