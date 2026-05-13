import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/ayurveda/domain/ayurveda_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

/// Mixin providing astrology/ayurveda initialization, timer logic,
/// and retry calculation for the user profile page.
mixin ProfileAstrologyLogic<T extends StatefulWidget> on State<T> {
  /// Subclass must provide these
  String? get astroUid;
  String? get astroCurrentUserUid;

  Future<AstrologyProfile?>? get astrologyProfileFuture;
  set astrologyProfileFuture(Future<AstrologyProfile?>? value);

  Stream<DailyInsight?>? get dailyInsightStream;
  set dailyInsightStream(Stream<DailyInsight?>? value);

  Stream<AyurvedaProfile?>? get ayurvedaProfileStream;
  set ayurvedaProfileStream(Stream<AyurvedaProfile?>? value);

  Timer? get astroRefreshTimer;
  set astroRefreshTimer(Timer? value);

  bool get isAstroCalculating;
  set isAstroCalculating(bool value);

  bool get isRetryingAstro;
  set isRetryingAstro(bool value);

  int get astroRefreshKey;
  set astroRefreshKey(int value);

  AyurvedaService get ayurvedaService;

  void initAstrologyFuture() {
    if (astroUid != null) {
      astrologyProfileFuture = AstrologyService().getProfile(astroUid!);
      // Wrap the insight stream with a timeout: if Firestore never emits
      // (e.g. App Check failure, network down), emit null after 5s so the
      // UI stops showing shimmer and falls back to "Tap to generate…".
      final rawStream = AstrologyService().streamTodayInsight(astroUid!);
      dailyInsightStream = rawStream.timeout(
        const Duration(seconds: 5),
        onTimeout: (sink) {
          AppLogger.w('dailyInsightStream timed out, emitting null',
              category: LogCategory.general);
          sink.add(null);
        },
      );
      ayurvedaProfileStream = ayurvedaService.streamProfile(astroUid!);

      // Check if astro is calculating and start refresh timer if needed
      checkAndStartAstroRefreshTimer();

      // For own profile, trigger lazy background sync to upgrade data
      if (astroUid == astroCurrentUserUid) {
        _triggerLazySyncIfNeeded();
      }
    }
  }

  void _triggerLazySyncIfNeeded() async {
    try {
      final profile = await astrologyProfileFuture;
      if (profile == null || !profile.isEnabled) return;

      if (profile.hasCalculatedData && profile.needsFullSync) {
        AstrologyService().triggerLazySync(mode: 'standard');
      }
    } catch (_) {
      AppLogger.w('UserProfile: astro lazy sync check failed',
          category: LogCategory.general);
    }
  }

  void checkAndStartAstroRefreshTimer() async {
    if (astroUid == null || astroUid != astroCurrentUserUid) return;

    try {
      final profile = await astrologyProfileFuture;
      final isCalculating =
          profile != null && profile.isEnabled && !profile.hasCalculatedData;

      if (isCalculating && !isAstroCalculating) {
        isAstroCalculating = true;
        startAstroRefreshTimer();
      }
    } catch (_) {
      AppLogger.w('UserProfile: astro refresh timer check failed',
          category: LogCategory.general);
    }
  }

  void startAstroRefreshTimer() {
    astroRefreshTimer?.cancel();
    astroRefreshTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || astroUid == null) {
        timer.cancel();
        return;
      }

      try {
        final profile = await AstrologyService()
            .getProfile(astroUid!, forceRefresh: true);

        if (profile != null && profile.hasCalculatedData) {
          timer.cancel();
          isAstroCalculating = false;
          if (mounted) {
            // Only update the future — do NOT increment astroRefreshKey.
            // Incrementing the key was causing the ValueKey-keyed Column in
            // ProfileContentBody to unmount/remount all cards, destroying
            // every FutureBuilder & StreamBuilder state and sending insights,
            // rank, and astrology cards back into loading states.
            // FutureBuilders detect the new future via didUpdateWidget and
            // re-subscribe automatically.
            setState(() {
              astrologyProfileFuture = Future.value(profile);
            });
          }
        }
      } catch (_) {
        AppLogger.w('UserProfile: astro refresh timer iteration failed',
            category: LogCategory.general);
      }
    });
  }

  Future<void> retryAstrologyCalculation() async {
    if (!mounted || astroUid == null || isRetryingAstro) return;
    isRetryingAstro = true;
    HapticFeedback.lightImpact();

    try {
      showCustomSnackBar(context, message: 'Recalculating your stars...', backgroundColor: Colors.blueGrey.shade700);

      final success = await AstrologyService().calculateAndSaveAll(astroUid!);

      if (mounted) {
        // Only update the future — FutureBuilders detect the change via
        // didUpdateWidget and re-subscribe automatically. No need to
        // increment astroRefreshKey which would destroy all card states.
        setState(() {
          astrologyProfileFuture =
              AstrologyService().getProfile(astroUid!, forceRefresh: true);
        });
      }

      if (!success && AstrologyService().lastAuthFailure && mounted) {
        showCustomSnackBar(context, message: 'Session expired. Please log in again.', backgroundColor: Colors.red.shade700);
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, message: 'Could not recalculate: $e', backgroundColor: Colors.red.shade600);
      }
    } finally {
      isRetryingAstro = false;
    }
  }
}
