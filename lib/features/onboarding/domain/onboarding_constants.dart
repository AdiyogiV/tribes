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
  // Increased wait time - backend sync can take 10-20 seconds
  static const maxAstroWait = Duration(seconds: 25);
  static const astroRetryInterval = Duration(milliseconds: 800);
}

// ============================================================================
// ONBOARDING PHASE CONSTANTS (sequential: main flow 0-5, alternate 6-7)
// ============================================================================
class OnboardingPhase {
  static const int loading = 0;
  static const int signReveal = 1;
  static const int ayurveda = 2;
  static const int birthReading = 3;
  static const int currentTimes = 4;
  static const int pathChoice = 5;
  static const int skip = 6;
  static const int retry = 7;
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
