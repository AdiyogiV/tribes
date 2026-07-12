import 'package:flutter/material.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_constants.dart';
import 'package:aurogram/features/onboarding/presentation/steps/shared_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

// ============================================================================
// Skip Phase - User skipped birth details
// ============================================================================
class SkipPhase extends StatelessWidget {
  final VoidCallback onChat;
  final VoidCallback onAddBirthDetails;

  const SkipPhase({
    super.key,
    required this.onChat,
    required this.onAddBirthDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Clean header - app icon without shadow
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              child: Image.asset(
                'assets/images/icon_transparent.png',
                height: 56,
                width: 56,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            Text(
              'Welcome!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: OnboardingColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
              child: Text(
                'Add birth details anytime to unlock personalized astrology insights.',
                style: TextStyle(
                  fontSize: 14,
                  color: OnboardingColors.textSecondary(context),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSection),
            PathButton(
              icon: Icons.smart_toy_rounded,
              color: OnboardingColors.warmAmber,
              title: 'Meet Aryabhatt',
              subtitle: 'Your AI companion',
              onTap: onChat,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            PathButton(
              icon: Icons.nights_stay_rounded,
              color: OnboardingColors.moonPurple,
              title: 'Add Birth Details',
              subtitle: 'Unlock cosmic insights',
              onTap: onAddBirthDetails,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Retry Phase - Calculation taking too long
// ============================================================================
class RetryPhase extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onGoToProfile;
  final VoidCallback onExplore;

  const RetryPhase({
    super.key,
    required this.onRetry,
    required this.onGoToProfile,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Clean header - app icon without shadow
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              child: Image.asset(
                'assets/images/icon_transparent.png',
                height: 56,
                width: 56,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            Text(
              'Still Calculating...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: OnboardingColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
              child: Text(
                'Your chart is taking a bit longer. You can wait or check your profile later.',
                style: TextStyle(
                  fontSize: 14,
                  color: OnboardingColors.textSecondary(context),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSection),
            PathButton(
              icon: Icons.refresh_rounded,
              color: OnboardingColors.moonPurple,
              title: 'Try Again',
              subtitle: 'Wait for calculation',
              onTap: onRetry,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            PathButton(
              icon: Icons.account_circle_rounded,
              color: OnboardingColors.risingGreen,
              title: 'Go to Profile',
              subtitle: 'Check chart when ready',
              onTap: onGoToProfile,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            PathButton(
              icon: Icons.explore_rounded,
              color: OnboardingColors.warmAmber,
              title: 'Explore App',
              subtitle: 'Come back later',
              onTap: onExplore,
            ),
          ],
        ),
      ),
    );
  }
}
