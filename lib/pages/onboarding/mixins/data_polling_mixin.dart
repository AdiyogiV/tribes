import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/services/astrology_service.dart';
import 'package:aurogram/services/ayurveda_service.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/models/ayurveda_profile.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/pages/onboarding/onboarding_constants.dart';

/// Provides data-polling helpers for the onboarding flow.
///
/// The host State must expose the mutable fields that polling updates via the
/// abstract getters/setters declared here.
mixin DataPollingMixin<T extends StatefulWidget> on State<T> {
  // ---- fields the host must provide ----
  AstrologyProfile? get pollingProfile;
  set pollingProfile(AstrologyProfile? value);

  AyurvedaProfile? get pollingAyurvedaProfile;
  set pollingAyurvedaProfile(AyurvedaProfile? value);

  String? get pollingFirstReadingContent;
  set pollingFirstReadingContent(String? value);

  bool get pollingIsGeneratingReading;
  set pollingIsGeneratingReading(bool value);

  String? get pollingCurrentTimesReadingContent;
  set pollingCurrentTimesReadingContent(String? value);

  bool get pollingIsGeneratingCurrentTimesReading;
  set pollingIsGeneratingCurrentTimesReading(bool value);

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

  /// Wait for Ayurveda data to be ready.
  Future<void> waitForAyurvedaData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ayurvedaService = AyurvedaService();
    final startTime = DateTime.now();
    int pollCount = 0;
    const maxWait = Duration(seconds: 15); // Shorter wait for Ayurveda

    AppLogger.i('Starting Ayurveda data poll for uid: $uid',
        category: LogCategory.general);

    while (DateTime.now().difference(startTime) < maxWait) {
      pollCount++;
      try {
        final profile =
            await ayurvedaService.getProfile(uid, forceRefresh: true);

        if (profile != null && profile.prakriti != null) {
          pollingAyurvedaProfile = profile;
          AppLogger.i('✅ Ayurveda profile loaded after $pollCount polls',
              category: LogCategory.general);
          return;
        } else if (pollCount % 3 == 0) {
          AppLogger.d('Poll #$pollCount: Waiting for Ayurveda profile...',
              category: LogCategory.general);
        }
      } catch (e) {
        AppLogger.w('Ayurveda profile fetch error (poll #$pollCount): $e',
            category: LogCategory.general);
      }

      if (!mounted) return;
      await Future.delayed(AnimationTiming.astroRetryInterval);
    }

    AppLogger.w('Ayurveda data timeout after $pollCount polls',
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

  /// Triggers Ayurveda calculation asynchronously.
  void triggerAyurvedaCalculationInBackground() {
    final ayurvedaService = AyurvedaService();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    AppLogger.i('🔮 Triggering Ayurveda calculation (background)',
        category: LogCategory.network);

    ayurvedaService
        .getProfile(uid, forceRefresh: true)
        .then((existingProfile) {
      if (existingProfile != null && mounted) {
        setState(() => pollingAyurvedaProfile = existingProfile);
        AppLogger.i('✅ Ayurveda profile already exists',
            category: LogCategory.network);
      } else {
        ayurvedaService.calculateProfile().then((newProfile) {
          if (mounted && newProfile != null) {
            setState(() => pollingAyurvedaProfile = newProfile);
            AppLogger.i('✅ Ayurveda profile calculated',
                category: LogCategory.network);
          }
        }).catchError((e) {
          AppLogger.w('Ayurveda calculation failed: $e',
              category: LogCategory.network);
        });
      }
    }).catchError((e) {
      AppLogger.w('Ayurveda profile fetch failed: $e',
          category: LogCategory.network);
    });
  }

  /// Polls Firestore for the first reading content.
  void pollForFirstReading() async {
    AppLogger.i('Polling for first reading from Firestore...',
        category: LogCategory.general);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      AppLogger.w('No uid for first reading poll',
          category: LogCategory.general);
      return;
    }

    final startTime = DateTime.now();
    int pollCount = 0;
    bool hasTriggeredGeneration = false;

    while (DateTime.now().difference(startTime) <
            AnimationTiming.maxPollingWait &&
        pollingFirstReadingContent == null &&
        mounted) {
      pollCount++;
      try {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

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
                  AppLogger.i(
                      'First reading generation triggered successfully',
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
  }

  /// Check for first reading once (used as final fallback).
  void checkForFirstReadingOnce() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || pollingFirstReadingContent != null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
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

  /// Poll for current times reading.
  void pollForCurrentTimesReading() async {
    AppLogger.i('Polling for current times reading...',
        category: LogCategory.general);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      AppLogger.w('No uid for current times reading poll',
          category: LogCategory.general);
      return;
    }

    final startTime = DateTime.now();
    int pollCount = 0;
    bool hasTriggeredGeneration = false;

    while (DateTime.now().difference(startTime) <
            AnimationTiming.maxPollingWait &&
        pollingCurrentTimesReadingContent == null &&
        mounted) {
      pollCount++;
      try {
        final content = await AstrologyService().getCurrentTimesReading(uid);
        if (content != null && content.isNotEmpty) {
          AppLogger.i('✅ Current times reading found! Poll #$pollCount',
              category: LogCategory.general);
          if (mounted) {
            setState(() {
              pollingCurrentTimesReadingContent = content;
              pollingIsGeneratingCurrentTimesReading = false;
            });
          }
          return;
        }

        if (!hasTriggeredGeneration && pollCount >= 2) {
          hasTriggeredGeneration = true;
          AppLogger.i('Triggering current times reading generation...',
              category: LogCategory.general);
          AstrologyService().generateCurrentTimesReading().then((success) {
            if (success) {
              AppLogger.i('Current times reading generation triggered',
                  category: LogCategory.general);
            }
          }).catchError((e) {
            AppLogger.w('Current times reading trigger failed: $e',
                category: LogCategory.general);
          });
        }
      } catch (e) {
        AppLogger.w('Current times reading poll error: $e',
            category: LogCategory.general);
      }

      await Future.delayed(AnimationTiming.pollingInterval);
    }

    if (mounted && pollingCurrentTimesReadingContent == null) {
      setState(() => pollingIsGeneratingCurrentTimesReading = false);
    }
  }
}
