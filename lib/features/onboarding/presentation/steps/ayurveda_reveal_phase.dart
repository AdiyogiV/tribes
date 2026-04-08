import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_constants.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_ayurveda_data.dart';
import 'package:aurogram/features/onboarding/presentation/widgets/onboarding_dialogs.dart';
import 'package:aurogram/features/onboarding/presentation/steps/shared_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class AyurvedaRevealPhase extends StatelessWidget {
  final AyurvedaProfile ayurvedaProfile;
  final int ayurvedaRevealStep;
  final VoidCallback onContinue;

  const AyurvedaRevealPhase({
    super.key,
    required this.ayurvedaProfile,
    required this.ayurvedaRevealStep,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final prakriti = ayurvedaProfile.prakriti;
    if (prakriti == null) {
      return const SizedBox.shrink();
    }

    final isTridoshic = prakriti.type.toLowerCase().contains('tridoshic') ||
        prakriti.isBalanced;
    final isDualDosha = prakriti.type.contains('-') && !isTridoshic;

    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        final isWideScreen = isTablet || isDesktop;

        if (isWideScreen) {
          return _buildWideLayout(
              context, prakriti, isTridoshic, isDualDosha, isDesktop);
        }
        return _buildMobileLayout(
            context, prakriti, isTridoshic, isDualDosha);
      },
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    PrakritiData prakriti,
    bool isTridoshic,
    bool isDualDosha,
    bool isDesktop,
  ) {
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              primary: true,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 500 : 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ayurveda',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: OnboardingColors.primary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        Text(
                          'Your predicted ayurvedic energies',
                          style: TextStyle(
                            fontSize: 16,
                            color: OnboardingColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingXxl),
                        // Card 1: Your Constitution
                        _buildAyurvedaCard(
                          context: context,
                          icon: Icons.spa_rounded,
                          color: const Color(0xFF059669),
                          label: 'Your Constitution',
                          value: prakriti.type,
                          description:
                              OnboardingAyurvedaData.getConstitutionDescription(
                                  prakriti, isTridoshic, isDualDosha),
                          revealed: ayurvedaRevealStep >= 1,
                          cardType: 'constitution',
                          prakriti: prakriti,
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),
                        // Card 2: Dosha Percentages
                        _buildAyurvedaCard(
                          context: context,
                          icon: Icons.insights_rounded,
                          color: AppTheme.cosmicPurple,
                          label: 'Prakriti - Your Baseline Nature',
                          value: OnboardingAyurvedaData.getDoshaBalanceTitle(
                              prakriti, isTridoshic),
                          description:
                              OnboardingAyurvedaData.getDoshaBalanceDescription(
                                  prakriti, isTridoshic),
                          revealed: ayurvedaRevealStep >= 2,
                          cardType: 'percentages',
                          prakriti: prakriti,
                        ),
                        // Card 3: Current Balance (Vikriti) - if available
                        if (ayurvedaProfile.vikriti != null) ...[
                          const SizedBox(height: AppDimensions.spacingMd),
                          _buildAyurvedaCard(
                            context: context,
                            icon: Icons.wb_twilight_rounded,
                            color: AppTheme.pinkAccent,
                            label: 'Vikriti - Your Current Energy',
                            value: OnboardingAyurvedaData.getVikritiTitle(
                                ayurvedaProfile.vikriti!),
                            description:
                                OnboardingAyurvedaData.getVikritiDescription(
                                    ayurvedaProfile.vikriti!),
                            revealed: ayurvedaRevealStep >= 3,
                            cardType: 'vikriti',
                            prakriti: prakriti,
                            vikriti: ayurvedaProfile.vikriti,
                          ),
                        ],
                        // Subtle hint
                        if (ayurvedaRevealStep >=
                            (ayurvedaProfile.vikriti != null ? 3 : 2)) ...[
                          const SizedBox(height: AppDimensions.spacingMd),
                          _buildTapHint(context),
                        ],
                        const SizedBox(height: AppDimensions.spacingXxl),
                        // Continue button in flow
                        if (ayurvedaRevealStep >=
                            (ayurvedaProfile.vikriti != null ? 3 : 2))
                          ContinueButton(
                            label: 'Continue',
                            onTap: onContinue,
                          ),
                        const SizedBox(height: AppDimensions.spacingXl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    PrakritiData prakriti,
    bool isTridoshic,
    bool isDualDosha,
  ) {
    return Stack(
      children: [
        // Main scrollable content
        SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.only(left: 0, right: 0, top: 16, bottom: 120),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ayurveda',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: OnboardingColors.primary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSmMd),
                Text(
                  'Your predicted ayurvedic energies',
                  style: TextStyle(
                    fontSize: 14,
                    color: OnboardingColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXl),
                // Card 1: Your Constitution
                _buildAyurvedaCard(
                  context: context,
                  icon: Icons.spa_rounded,
                  color: const Color(0xFF059669),
                  label: 'Your Constitution',
                  value: prakriti.type,
                  description:
                      OnboardingAyurvedaData.getConstitutionDescription(
                          prakriti, isTridoshic, isDualDosha),
                  revealed: ayurvedaRevealStep >= 1,
                  cardType: 'constitution',
                  prakriti: prakriti,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                // Card 2: Dosha Percentages
                _buildAyurvedaCard(
                  context: context,
                  icon: Icons.insights_rounded,
                  color: AppTheme.cosmicPurple,
                  label: 'Your Baseline Nature',
                  value: OnboardingAyurvedaData.getDoshaBalanceTitle(
                      prakriti, isTridoshic),
                  description:
                      OnboardingAyurvedaData.getDoshaBalanceDescription(
                          prakriti, isTridoshic),
                  revealed: ayurvedaRevealStep >= 2,
                  cardType: 'percentages',
                  prakriti: prakriti,
                ),
                // Card 3: Current Balance (Vikriti) - if available
                if (ayurvedaProfile.vikriti != null) ...[
                  const SizedBox(height: AppDimensions.spacingMd),
                  _buildAyurvedaCard(
                    context: context,
                    icon: Icons.wb_twilight_rounded,
                    color: AppTheme.pinkAccent,
                    label: 'Your Current Energy',
                    value: OnboardingAyurvedaData.getVikritiTitle(
                        ayurvedaProfile.vikriti!),
                    description: OnboardingAyurvedaData.getVikritiDescription(
                        ayurvedaProfile.vikriti!),
                    revealed: ayurvedaRevealStep >= 3,
                    cardType: 'vikriti',
                    prakriti: prakriti,
                    vikriti: ayurvedaProfile.vikriti,
                  ),
                ],
                // Subtle hint
                if (ayurvedaRevealStep >=
                    (ayurvedaProfile.vikriti != null ? 3 : 2)) ...[
                  const SizedBox(height: AppDimensions.spacingMd),
                  _buildTapHint(context),
                ],
              ],
            ),
          ),
        ),
        // Continue button positioned at bottom
        if (ayurvedaRevealStep >= (ayurvedaProfile.vikriti != null ? 3 : 2))
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: ContinueButton(
                label: 'Continue',
                onTap: onContinue,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTapHint(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.touch_app_rounded,
          size: 14,
          color: OnboardingColors.textSecondary(context).withValues(alpha: 0.5),
        ),
        const SizedBox(width: AppDimensions.spacingSmMd),
        Text(
          'Tap cards for details',
          style: TextStyle(
            fontSize: 12,
            color:
                OnboardingColors.textSecondary(context).withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAyurvedaCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String description,
    required bool revealed,
    required String cardType,
    PrakritiData? prakriti,
    VikritiData? vikriti,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: revealed ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        final clampedOpacity = anim.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - anim)),
          child: Opacity(
            opacity: clampedOpacity,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: revealed
            ? () {
                HapticFeedback.lightImpact();
                _showAyurvedaDetails(
                  context: context,
                  icon: icon,
                  color: color,
                  label: label,
                  value: value,
                  description: description,
                  cardType: cardType,
                  prakriti: prakriti,
                  vikriti: vikriti,
                );
              }
            : null,
        child: TransparentToolbox(
          height: cardType == 'percentages' && prakriti != null
              ? 182.0
              : cardType == 'vikriti' && vikriti != null
                  ? 202.0
                  : 120.0,
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Icon(icon, color: color, size: 20),
                  ],
                ),
                // Value - conditionally shown when revealed
                if (revealed) ...[
                  const SizedBox(height: AppDimensions.spacingSmMd),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: OnboardingColors.textPrimary(context),
                    ),
                  ),
                ],
                // Description - always shown
                if (description.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacingSmMd),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: OnboardingColors.textSecondary(context),
                      height: 1.3,
                    ),
                    maxLines: cardType == 'constitution'
                        ? 3
                        : cardType == 'vikriti'
                            ? 2
                            : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Dosha bars for percentages card
                if (cardType == 'percentages' &&
                    prakriti != null &&
                    revealed) ...[
                  const SizedBox(height: AppDimensions.spacingMd),
                  _buildDoshaBarMini(
                      context, 'Vata', prakriti.vata, AppTheme.cosmicPurple),
                  const SizedBox(height: AppDimensions.spacingMdSm),
                  _buildDoshaBarMini(context, 'Pitta', prakriti.pitta,
                      AppTheme.amberAccent),
                  const SizedBox(height: AppDimensions.spacingMdSm),
                  _buildDoshaBarMini(context, 'Kapha', prakriti.kapha,
                      AppTheme.emeraldGreen),
                ],
                // Dosha bars for vikriti card
                if (cardType == 'vikriti' && vikriti != null && revealed) ...[
                  const SizedBox(height: AppDimensions.spacingMd),
                  _buildDoshaBarMini(
                      context, 'Vata', vikriti.vata, AppTheme.cosmicPurple),
                  const SizedBox(height: AppDimensions.spacingMdSm),
                  _buildDoshaBarMini(
                      context, 'Pitta', vikriti.pitta, AppTheme.amberAccent),
                  const SizedBox(height: AppDimensions.spacingMdSm),
                  _buildDoshaBarMini(
                      context, 'Kapha', vikriti.kapha, AppTheme.emeraldGreen),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoshaBarMini(
      BuildContext context, String label, int percentage, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        SizedBox(
          width: 35,
          child: Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OnboardingColors.textPrimary(context),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _showAyurvedaDetails({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String description,
    required String cardType,
    PrakritiData? prakriti,
    VikritiData? vikriti,
  }) {
    if (prakriti == null) return;

    final isTridoshic = prakriti.type.toLowerCase().contains('tridoshic') ||
        prakriti.isBalanced;
    final isDualDosha = prakriti.type.contains('-') && !isTridoshic;

    String expandedContent = description;

    if (cardType == 'constitution') {
      expandedContent = OnboardingAyurvedaData.getExpandedConstitutionContent(
          prakriti.type, isTridoshic, isDualDosha, prakriti);
    } else if (cardType == 'percentages') {
      expandedContent = OnboardingAyurvedaData.getExpandedPercentagesContent(
          prakriti, isTridoshic);
    } else if (cardType == 'vikriti' && vikriti != null) {
      expandedContent =
          OnboardingAyurvedaData.getExpandedVikritiContent(vikriti, prakriti);
    }

    CardDetailsDialog.show(
      context,
      icon: icon,
      color: color,
      title: value,
      subtitle: label,
      description: description,
      expandedContent: expandedContent,
    );
  }
}
