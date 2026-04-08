import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Onboarding progress sidebar for web
/// Shows the different phases of onboarding with progress indicators
/// Matches the design style of the main sidebar navigation
class OnboardingProgressSidebar extends StatelessWidget {
  final int currentPhase;
  final int signRevealStep;
  final int ayurvedaRevealStep;
  final bool hasReading;
  final bool isGeneratingReading;
  final bool hasCurrentTimesReading;
  final bool isGeneratingCurrentTimesReading;

  const OnboardingProgressSidebar({
    super.key,
    required this.currentPhase,
    required this.signRevealStep,
    required this.ayurvedaRevealStep,
    required this.hasReading,
    required this.isGeneratingReading,
    required this.hasCurrentTimesReading,
    required this.isGeneratingCurrentTimesReading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.primaryColor;
    final sidebarWidth = 280.0; // Match main sidebar width

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: sidebarWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkColor : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header - matching main sidebar style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                    child: Image.asset(
                      'assets/images/icon_transparent.png',
                      height: 32,
                      width: 32,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMdLg),
                  Expanded(
                    child: Text(
                      'Astroboarding',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.spacingSm),

            // Progress steps - matching nav item style
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
                children: [
                  _buildStep(
                    context: context,
                    icon: Icons.stars_rounded,
                    selectedIcon: Icons.stars,
                    label: 'Reading the Stars',
                    isActive: currentPhase == 0,
                    isCompleted: currentPhase > 0,
                    primaryColor: primaryColor,
                    isDark: isDark,
                  ),
                  _buildStep(
                    context: context,
                    icon: Icons.auto_awesome_outlined,
                    selectedIcon: Icons.auto_awesome_rounded,
                    label: 'Cosmic Blueprint',
                    isActive: currentPhase == 1,
                    isCompleted: currentPhase > 1 ||
                        (currentPhase == 1 && signRevealStep >= 3),
                    primaryColor: primaryColor,
                    isDark: isDark,
                  ),
                  _buildStep(
                    context: context,
                    icon: Icons.spa_outlined,
                    selectedIcon: Icons.spa_rounded,
                    label: 'Ayurveda',
                    isActive: currentPhase == 2,
                    isCompleted: currentPhase > 2 ||
                        (currentPhase == 2 && ayurvedaRevealStep >= 2),
                    primaryColor: primaryColor,
                    isDark: isDark,
                  ),
                  _buildStep(
                    context: context,
                    icon: Icons.menu_book_outlined,
                    selectedIcon: Icons.menu_book_rounded,
                    label: 'Birth Reading',
                    isActive: currentPhase == 3,
                    isCompleted:
                        currentPhase > 3 || (currentPhase == 3 && hasReading),
                    isGenerating:
                        currentPhase == 3 && isGeneratingReading && !hasReading,
                    primaryColor: primaryColor,
                    isDark: isDark,
                  ),
                  _buildStep(
                    context: context,
                    icon: Icons.schedule_outlined,
                    selectedIcon: Icons.schedule_rounded,
                    label: 'Current Times',
                    isActive: currentPhase == 4,
                    isCompleted: currentPhase > 4 ||
                        (currentPhase == 4 && hasCurrentTimesReading),
                    isGenerating: currentPhase == 4 &&
                        isGeneratingCurrentTimesReading &&
                        !hasCurrentTimesReading,
                    primaryColor: primaryColor,
                    isDark: isDark,
                  ),
                  _buildStep(
                    context: context,
                    icon: Icons.explore_outlined,
                    selectedIcon: Icons.explore_rounded,
                    label: 'Choose Your Path',
                    isActive: currentPhase == 5,
                    isCompleted: currentPhase > 5,
                    primaryColor: primaryColor,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required BuildContext context,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isActive,
    required bool isCompleted,
    required Color primaryColor,
    required bool isDark,
    bool isGenerating = false,
  }) {
    // Theme-aware active color: black for light theme, white for dark theme
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: isDark ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: isActive
              ? Border.all(
                  color: activeColor.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            // Icon or status indicator
            if (isCompleted)
              Icon(
                Icons.check_circle_rounded,
                size: 22,
                color: activeColor.withValues(alpha: 0.8),
              )
            else if (isGenerating)
              AppLoadingIndicator(
                size: 22,
                color: activeColor,
              )
            else
              Icon(
                isActive ? selectedIcon : icon,
                size: 22,
                color: isActive ? activeColor : inactiveColor,
              ),
            const SizedBox(width: AppDimensions.spacingMdLg),
            // Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
