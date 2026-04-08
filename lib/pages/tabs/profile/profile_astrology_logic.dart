import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/models/ayurveda_profile.dart';
import 'package:aurogram/services/astrology_service.dart';
import 'package:aurogram/services/ayurveda_service.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

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
      dailyInsightStream = AstrologyService().streamTodayInsight(astroUid!);
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
            setState(() {
              astrologyProfileFuture = Future.value(profile);
              astroRefreshKey = astroRefreshKey + 1;
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
        setState(() {
          astrologyProfileFuture =
              AstrologyService().getProfile(astroUid!, forceRefresh: true);
          astroRefreshKey = astroRefreshKey + 1;
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
