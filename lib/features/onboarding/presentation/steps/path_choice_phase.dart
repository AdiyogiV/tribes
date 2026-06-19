import 'package:flutter/material.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_constants.dart';
import 'package:aurogram/features/onboarding/presentation/steps/shared_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

// ============================================================================
// Path Choice Phase - "Start Exploring" with multiple options
// ============================================================================
class PathChoicePhase extends StatelessWidget {
  final VoidCallback onAstroDetails;
  final VoidCallback onAyurveda;
  final VoidCallback onDailyInsight;
  final VoidCallback onChat;

  const PathChoicePhase({
    super.key,
    required this.onAstroDetails,
    required this.onAyurveda,
    required this.onDailyInsight,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(
                    left: 0, right: 0, top: 24, bottom: 120),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(height: AppDimensions.spacingLg),
                      Text(
                        'Start Exploring',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: OnboardingColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingSmMd),
                      Text(
                        'Your cosmic journey begins here',
                        style: TextStyle(
                          fontSize: 14,
                          color: OnboardingColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXl),
                      PathButton(
                        icon: Icons.stars_rounded,
                        color: OnboardingColors.risingGreen,
                        title: 'Look At Your Stars',
                        subtitle: 'Explore your birth chart',
                        onTap: onAstroDetails,
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      PathButton(
                        icon: Icons.spa_rounded,
                        color: const Color(0xFF059669),
                        title: 'Discover Ayurveda',
                        subtitle: 'Check wellness tips',
                        onTap: onAyurveda,
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      PathButton(
                        icon: Icons.auto_awesome_rounded,
                        color: OnboardingColors.moonPurple,
                        title: 'Personal Guidance',
                        subtitle: 'Read guidance for current times',
                        onTap: onDailyInsight,
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      PathButton(
                        icon: Icons.smart_toy_rounded,
                        color: OnboardingColors.warmAmber,
                        title: 'Chat with Aryabhatt',
                        subtitle: 'Ask questions about anything',
                        onTap: onChat,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
