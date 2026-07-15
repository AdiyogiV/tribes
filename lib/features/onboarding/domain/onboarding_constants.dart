import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';

// Intent class for Enter key handling
class EnterIntent extends Intent {
  final VoidCallback onTap;
  const EnterIntent(this.onTap);
}

// ============================================================================
// ANIMATION TIMING CONSTANTS
// Centralized for consistency and easy tuning
// ============================================================================
class AnimationTiming {
  static const cardRevealDelay = Duration(milliseconds: 600);
  static const initialRevealDelay = Duration(milliseconds: 400);
  static const loadingMessageCycle = Duration(seconds: 2);
  static const pollingInterval = Duration(seconds: 2);
  static const maxPollingWait = Duration(seconds: 60);
  // Backend sync usually lands in 10-20s, but App Check throttling ("Too many
  // attempts") can delay the sync Cloud Function by 10-15s, pushing the real
  // wait past 45s. Give it generous headroom so the chart reveal doesn't fail
  // ("No profile found") while the calculation is still finishing.
  static const maxAstroWait = Duration(seconds: 75);
  static const astroRetryInterval = Duration(milliseconds: 800);
}

// ============================================================================
// ONBOARDING PHASE CONSTANTS (sequential: main flow 0-3, alternate 5-6)
// ============================================================================
class OnboardingPhase {
  static const int loading = 0;
  static const int signReveal = 1;
  static const int birthReading = 2;
  static const int currentTimes = 3;
  // 4 (pathChoice) removed — users now land on the home dashboard directly.
  static const int skip = 5;
  static const int retry = 6;
}

// ============================================================================
// THEME COLORS - Aligned with AppTheme farm aesthetic
// ============================================================================
class OnboardingColors {
  // Primary accents - using app theme colors
  static Color get primary => AppTheme.primaryColor;
  static const Color sunGold = Color(0xFFF5C542);
  static const Color moonPurple = AppTheme.cosmicPurple;
  static const Color risingGreen = AppTheme.emeraldGreen;
  static const Color warmAmber = Color(0xFFE6A23C);

  // Soft backgrounds for cards
  static Color textPrimary(BuildContext context) => AppTheme.textColor;
  static Color textSecondary(BuildContext context) =>
      AppTheme.textSecondaryColor;
}
