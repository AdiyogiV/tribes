import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/presentation/widgets/timeline/muhurat_timeline_widget.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/cosmic_date_time_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard/cosmic_dashboard_data.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/features/astrology/domain/astro_calendar_service.dart';
import 'package:aurogram/features/astrology/domain/forecast_service.dart';
import 'package:aurogram/shared/services/widget_data_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/energy_card.dart';
import 'package:aurogram/features/astrology/presentation/pages/baba/widgets/baba_panchang_resolver.dart';
import 'package:aurogram/features/astrology/presentation/pages/baba/widgets/baba_secondary_cards.dart';
import 'package:aurogram/features/astrology/presentation/pages/baba/widgets/baba_muhurat_placeholder.dart';
import 'package:aurogram/features/astrology/presentation/pages/baba/widgets/baba_signin_cta_banner.dart';

/// Builds the full cosmic dashboard content panel with all cards.
class BabaCosmicContent extends StatelessWidget {
  final AstrologyProfile? profile;
  final AyurvedaProfile? ayurvedaProfile;
  final DashboardLoadingState loadingState;
  final SkyPositionsService skyService;
  final ValueNotifier<double> sliderValueNotifier;
  final ValueNotifier<DateTime> sliderDateNotifier;
  final ValueChanged<double> onSliderChanged;
  final VoidCallback onResetToToday;
  final Future<void> Function({bool isRetry}) onLoadSkyPositions;
  final Future<void> Function() onTriggerCachePopulation;

  /// Optional signal fired by the parent when the user taps "Today" on the
  /// sky chart — the nakshatra wheel listens and snaps back to today.
  final Listenable? wheelResetSignal;

  /// Live wheel state controller — passed directly to [EnergyCard]
  /// so independent cards on the page can listen to wheel position changes.
  final NakshatraWheelController? nakshatraController;

  /// Slider range in days (±N from today).  Used to compute the slider ↔
  /// days offset mapping.  Defaults to 180 for the extended calendar range.
  final int sliderRangeDays;

  /// Optional calendar service for extended-range position lookups.
  final AstroCalendarService? calendarService;

  /// The unified forecast (date → computed day) driving the wheel's real
  /// alignment % and woven narrative.
  final Map<String, ForecastDay>? forecast;

  /// The circle selector strip, rendered directly BELOW the (common) date card
  /// and ABOVE the swappable body. Null on surfaces without the selector.
  final Widget? stripSlot;

  /// When non-null, replaces the whole body BELOW the date card + strip (e.g.
  /// the friend view). The date card stays common on top for everyone.
  final Widget? bodyOverride;

  const BabaCosmicContent({
    super.key,
    required this.profile,
    this.ayurvedaProfile,
    required this.loadingState,
    required this.skyService,
    required this.sliderValueNotifier,
    required this.sliderDateNotifier,
    required this.onSliderChanged,
    required this.onResetToToday,
    required this.onLoadSkyPositions,
    required this.onTriggerCachePopulation,
    this.wheelResetSignal,
    this.nakshatraController,
    this.sliderRangeDays = 180,
    this.calendarService,
    this.forecast,
    this.stripSlot,
    this.bodyOverride,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brown = AppTheme.primaryColor;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Single source of truth for the panchang merge + nakshatra precedence
    // chain (shared with the wheel builder via BabaPanchangResolver).
    final panchang = BabaPanchangResolver.resolve(
      skyService: skyService,
      calendarService: calendarService,
    );
    final nakshatraSamvat = panchang.nakshatraSamvat;
    final todayNakshatra = panchang.todayNakshatra;

    // Push the fully-merged samvat to native home screen widgets.
    // This is the complete merged panchang/samvat source.
    if (nakshatraSamvat != null) {
      WidgetDataService.instance.updateWidgetData(nakshatraSamvat);
    }

    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;

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
        // renders BELOW the wheel (wheelFirst: true) so the wheel is the
        // visual hero and the guidance text sits beneath it on both mobile
        // and desktop.
        final wheelWidget = _buildWheelWidget(wheelFirst: true);

        // Mobile: ONE card that MERGES the date/clock row with the Time
        // Guidance timeline below it. Each half renders "embedded" (no inner
        // card surface) so they share a single Material/shadow. The muhurat
        // half only appears when there's data (or a loading placeholder in the
        // today window); otherwise the card is just the date row.
        final mergedDateMuhuratCard = ValueListenableBuilder<DateTime>(
          valueListenable: sliderDateNotifier,
          builder: (context, sliderDate, _) {
            final today = DateTime.now();
            final isToday = sliderDate.year == today.year &&
                sliderDate.month == today.month &&
                sliderDate.day == today.day;
            final dateSamvat =
                calendarService?.getPanchangForDate(sliderDate) ??
                    (isToday ? nakshatraSamvat : null);

            // One source of truth: the astro calendar carries muhurat for
            // every day in range.
            final calMuhurat = calendarService?.getMuhuratForDate(sliderDate);
            final hasMuhurat = calMuhurat != null && calMuhurat.isNotEmpty;
            final daysDiff = sliderDate
                .difference(DateTime(today.year, today.month, today.day))
                .inDays
                .abs();
            final showLoading = !hasMuhurat &&
                loadingState.isMuhuratLoading &&
                daysDiff <= 1 &&
                FirebaseAuth.instance.currentUser != null;

            return Material(
              color: cardColor,
              elevation: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  VedicCombinedCard(
                    samvat: dateSamvat,
                    brown: brown,
                    selectedDate: isToday ? null : sliderDate,
                    onResetToToday: onResetToToday,
                    nakshatraName: isToday ? todayNakshatra : null,
                    embedded: true,
                  ),
                  if (hasMuhurat) ...[
                    MuhuratTimelineWidget(muhurat: calMuhurat, embedded: true),
                  ] else if (showLoading) ...[
                    BabaMuhuratPlaceholder(
                        cardColor: cardColor, embedded: true),
                  ],
                ],
              ),
            );
          },
        );

        // The bag of secondary cards in their canonical order. Inlined into
        // a single Column for both mobile and desktop.
        // We now inject the wheel into the secondary list unconditionally,
        // so it sits in the same stack as the Sky and Balance cards.
        final secondaryCards = BabaSecondaryCards(
          profile: profile,
          ayurvedaProfile: ayurvedaProfile,
          loadingState: loadingState,
          skyService: skyService,
          calendarService: calendarService,
          sliderValueNotifier: sliderValueNotifier,
          sliderDateNotifier: sliderDateNotifier,
          onSliderChanged: onSliderChanged,
          onResetToToday: onResetToToday,
          onLoadSkyPositions: onLoadSkyPositions,
          onTriggerCachePopulation: onTriggerCachePopulation,
          spacing: spacing,
          insertBeforeSkyCard: wheelWidget,
        );

        // The sign-in upsell — only visible when signed-out.
        final isSignedOut = FirebaseAuth.instance.currentUser == null;
        final ctaBanner = isSignedOut
            ? BabaSignInCtaBanner(
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
              mergedDateMuhuratCard,
              SizedBox(height: spacing),
              // Circle selector sits right below the common date card.
              if (stripSlot != null) ...[
                stripSlot!,
                SizedBox(height: spacing),
              ],
              if (bodyOverride != null) ...[
                bodyOverride!,
                SizedBox(height: 16 + bottomInset),
              ] else ...[
                secondaryCards,
                if (ctaBanner != null) ...[
                  ctaBanner,
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
      final panchang = BabaPanchangResolver.resolve(
        skyService: skyService,
        calendarService: calendarService,
      );
      final nakshatraSamvat = panchang.nakshatraSamvat;
      final todayNakshatra = panchang.todayNakshatra;
      final birthNakshatra = profile?.moonNakshatra ?? profile?.nakshatra;
      final lagnaNakshatra = profile?.lagnaNakshatra;
      return EnergyCard(
        todayNakshatra: todayNakshatra,
        birthNakshatra: birthNakshatra,
        lagnaNakshatra: lagnaNakshatra,
        todaySamvat: nakshatraSamvat,
        wheelResetSignal: wheelResetSignal,
        controller: nakshatraController,
        forecast: forecast,
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


}
