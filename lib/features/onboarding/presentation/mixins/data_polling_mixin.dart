import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_constants.dart';

/// Provides data-polling helpers for the onboarding flow.
///
/// The host State must expose the mutable fields that polling updates via the
/// abstract getters/setters declared here.
mixin DataPollingMixin<T extends StatefulWidget> on State<T> {
  bool _isPollingFirstReading = false;

  // ---- fields the host must provide ----
  AstrologyProfile? get pollingProfile;
  set pollingProfile(AstrologyProfile? value);

  String? get pollingFirstReadingContent;
  set pollingFirstReadingContent(String? value);

  bool get pollingIsGeneratingReading;
  set pollingIsGeneratingReading(bool value);

  // ---- polling methods ----

  /// Wait for astro data (backend sync to complete).
  Future<void> waitForAstroData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      AppLogger.w('No uid for astro data wait', category: LogCategory.general);
      return;
    }

    final astroService = AstrologyService();
    final startTime = DateTime.now();
    int pollCount = 0;

    AppLogger.i('Starting astro data poll for uid: $uid',
        category: LogCategory.general);

    while (
        DateTime.now().difference(startTime) < AnimationTiming.maxAstroWait) {
      pollCount++;
      try {
        // Always force refresh to get latest from Firestore
        final profile = await astroService.getProfile(uid, forceRefresh: true);

        if (profile != null) {
          // Check if profile has calculated signs (backend sync complete)
          if (profile.sunSign != null && profile.moonSign != null) {
            pollingProfile = profile;
            AppLogger.i(
                '✅ Profile loaded after $pollCount polls: ${profile.sunSign}/${profile.moonSign}/${profile.ascendant}',
                category: LogCategory.general);
            return;
          } else if (pollCount % 5 == 0) {
            AppLogger.d(
                'Poll #$pollCount: Profile exists but waiting for calculated signs (syncStatus: ${profile.syncStatus})',
                category: LogCategory.general);
          }
        } else if (pollCount % 5 == 0) {
          AppLogger.d('Poll #$pollCount: No profile yet, waiting...',
              category: LogCategory.general);
        }
      } catch (e) {
        AppLogger.w('Profile fetch error (poll #$pollCount): $e',
            category: LogCategory.general);
      }

      if (!mounted) return;
      await Future.delayed(AnimationTiming.astroRetryInterval);
    }

    AppLogger.w(
        'Astro data timeout after $pollCount polls (${AnimationTiming.maxAstroWait.inSeconds}s)',
        category: LogCategory.general);
  }

  /// Triggers daily insight generation as a separate Cloud Function call.
  /// Runs asynchronously - does not block the onboarding flow.
  void triggerDailyInsightInBackground() {
    final astroService = AstrologyService();
    AppLogger.i('🔮 Triggering daily insight generation (background)',
        category: LogCategory.network);

    astroService.generateDailyInsight(forceRegenerate: false).then((result) {
      AppLogger.i('✅ Daily insight generated', category: LogCategory.network);
    }).catchError((e) {
      AppLogger.w('Daily insight generation failed: $e',
          category: LogCategory.network);
    });
  }

  /// Polls Firestore for the first reading content.
  void pollForFirstReading() async {
    if (_isPollingFirstReading) return;
    _isPollingFirstReading = true;
    AppLogger.i('Polling for first reading from Firestore...',
        category: LogCategory.general);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      AppLogger.w('No uid for first reading poll',
          category: LogCategory.general);
      _isPollingFirstReading = false;
      return;
    }

    final startTime = DateTime.now();
    int pollCount = 0;
    bool hasTriggeredGeneration = false;

    while (
        DateTime.now().difference(startTime) < AnimationTiming.maxPollingWait &&
            pollingFirstReadingContent == null &&
            mounted) {
      pollCount++;
      try {
        final userRepo = locator<UserRepository>();
        // First reading is written asynchronously by backend right after sync.
        // Bypass repository TTL cache so onboarding sees fresh Firestore writes.
        userRepo.invalidate(uid);
        final doc = await userRepo.getUser(uid);

        if (doc.exists) {
          final data = doc.data();
          final astroData = data?['astrologyData'] as Map<String, dynamic>?;
          final firstReading =
              astroData?['firstReading'] as Map<String, dynamic>?;
          final content = firstReading?['content']?.toString();

          if (content != null && content.isNotEmpty) {
            AppLogger.i('✅ First reading found! Poll #$pollCount',
                category: LogCategory.general);

            if (mounted) {
              setState(() {
                pollingFirstReadingContent = content;
                pollingIsGeneratingReading = false;
              });
            }
            _isPollingFirstReading = false;
            return;
          } else {
            if (!hasTriggeredGeneration && pollCount >= 3) {
              hasTriggeredGeneration = true;
              AppLogger.i(
                  'No reading found after $pollCount polls, triggering generation...',
                  category: LogCategory.general);

              final astroService = AstrologyService();
              astroService.generateFirstReading().then((success) {
                if (success) {
                  AppLogger.i('First reading generation triggered successfully',
                      category: LogCategory.general);
                } else {
                  AppLogger.w('First reading generation trigger failed',
                      category: LogCategory.general);
                }
              }).catchError((e) {
                AppLogger.w('Error triggering first reading generation: $e',
                    category: LogCategory.general);
              });
            } else if (pollCount % 5 == 0) {
              AppLogger.d('Poll #$pollCount: Waiting for first reading...',
                  category: LogCategory.general);
            }
          }
        }
      } catch (e) {
        AppLogger.w('First reading poll error: $e',
            category: LogCategory.general);
      }

      await Future.delayed(AnimationTiming.pollingInterval);
    }

    AppLogger.w('First reading timeout after $pollCount polls',
        category: LogCategory.general);

    if (pollingFirstReadingContent == null &&
        !hasTriggeredGeneration &&
        mounted) {
      AppLogger.i('Attempting final trigger of first reading generation',
          category: LogCategory.general);
      final astroService = AstrologyService();
      astroService.generateFirstReading().then((success) {
        if (success && mounted) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              checkForFirstReadingOnce();
            }
          });
        }
      });
    }

    _isPollingFirstReading = false;
  }

  /// Check for first reading once (used as final fallback).
  void checkForFirstReadingOnce() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || pollingFirstReadingContent != null) return;

    try {
      final userRepo = locator<UserRepository>();
      // Ensure final fallback check reads latest document state.
      userRepo.invalidate(uid);
      final doc = await userRepo.getUser(uid);
      if (doc.exists) {
        final data = doc.data();
        final astroData = data?['astrologyData'] as Map<String, dynamic>?;
        final firstReading =
            astroData?['firstReading'] as Map<String, dynamic>?;
        final content = firstReading?['content']?.toString();

        if (content != null && content.isNotEmpty && mounted) {
          AppLogger.i('✅ First reading found in final check!',
              category: LogCategory.general);
          setState(() {
            pollingFirstReadingContent = content;
            pollingIsGeneratingReading = false;
          });
        }
      }
    } catch (e) {
      AppLogger.w('Final first reading check error: $e',
          category: LogCategory.general);
    }
  }
}
