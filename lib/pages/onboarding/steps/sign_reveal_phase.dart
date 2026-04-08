import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/pages/onboarding/onboarding_constants.dart';
import 'package:aurogram/pages/onboarding/onboarding_sign_data.dart';
import 'package:aurogram/pages/onboarding/widgets/onboarding_dialogs.dart';
import 'package:aurogram/pages/onboarding/steps/shared_widgets.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

class SignRevealPhase extends StatelessWidget {
  final AstrologyProfile profile;
  final int signRevealStep;
  final VoidCallback onContinue;
  final VoidCallback onShare;

  const SignRevealPhase({
    super.key,
    required this.profile,
    required this.signRevealStep,
    required this.onContinue,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        final isWideScreen = isTablet || isDesktop;

        if (isWideScreen) {
          return _buildWideLayout(context, isDesktop);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  Widget _buildWideLayout(BuildContext context, bool isDesktop) {
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 500 : 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Clean header
                        Text(
                          'Your Cosmic Blueprint',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        Text(
                          'The three pillars of who you are',
                          style: TextStyle(
                            fontSize: 16,
                            color: OnboardingColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingSection),
                        // Cards stacked vertically (same as mobile)
                        // Rising first - your outer mask
                        _buildSignCard(
                          context: context,
                          icon: Icons.arrow_upward_rounded,
                          color: OnboardingColors.risingGreen,
                          label: 'Rising Sign',
                          value: profile.ascendant ?? '—',
                          description: OnboardingSignData.getSignDescription(
                              profile.ascendant, 'rising'),
                          revealed: signRevealStep >= 1,
                          signType: 'rising',
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),
                        // Sun second - your core identity
                        _buildSignCard(
                          context: context,
                          icon: Icons.wb_sunny_rounded,
                          color: OnboardingColors.sunGold,
                          label: 'Sun Sign',
                          value: profile.sunSign ?? '—',
                          description: OnboardingSignData.getSignDescription(
                              profile.sunSign, 'sun'),
                          revealed: signRevealStep >= 2,
                          signType: 'sun',
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),
                        // Moon third - your emotional self
                        _buildSignCard(
                          context: context,
                          icon: Icons.nights_stay_rounded,
                          color: OnboardingColors.moonPurple,
                          label: 'Moon Sign',
                          value: profile.moonSign ?? '—',
                          description: OnboardingSignData.getSignDescription(
                              profile.moonSign, 'moon'),
                          revealed: signRevealStep >= 3,
                          signType: 'moon',
                        ),
                        // Tap to read more hint
                        if (signRevealStep >= 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              'Tap any card to read more',
                              style: TextStyle(
                                fontSize: 12,
                                color: OnboardingColors.textSecondary(context),
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        // Small share link below cards
                        if (signRevealStep >= 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: ShareLink(onTap: onShare),
                          ),
                        const SizedBox(height: AppDimensions.spacingSection),
                        // Continue button in flow
                        if (signRevealStep >= 3)
                          ContinueButton(
                            label: 'Continue',
                            onTap: onContinue,
                          ),
                        const SizedBox(height: AppDimensions.spacingXxl),
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

  Widget _buildMobileLayout(BuildContext context) {
    return Stack(
      children: [
        // Main scrollable content
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.only(left: 0, right: 0, top: 32, bottom: 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Clean header
                  Text(
                    'Your Cosmic Blueprint',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSmMd),
                  Text(
                    'The three pillars of who you are',
                    style: TextStyle(
                      fontSize: 14,
                      color: OnboardingColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXxl),
                  // Rising first - your outer mask
                  _buildSignCard(
                    context: context,
                    icon: Icons.arrow_upward_rounded,
                    color: OnboardingColors.risingGreen,
                    label: 'Rising Sign',
                    value: profile.ascendant ?? '—',
                    description: OnboardingSignData.getSignDescription(
                        profile.ascendant, 'rising'),
                    revealed: signRevealStep >= 1,
                    signType: 'rising',
                  ),
                  // Sun second - your core identity
                  _buildSignCard(
                    context: context,
                    icon: Icons.wb_sunny_rounded,
                    color: OnboardingColors.sunGold,
                    label: 'Sun Sign',
                    value: profile.sunSign ?? '—',
                    description: OnboardingSignData.getSignDescription(
                        profile.sunSign, 'sun'),
                    revealed: signRevealStep >= 2,
                    signType: 'sun',
                  ),
                  // Moon third - your emotional self
                  _buildSignCard(
                    context: context,
                    icon: Icons.nights_stay_rounded,
                    color: OnboardingColors.moonPurple,
                    label: 'Moon Sign',
                    value: profile.moonSign ?? '—',
                    description: OnboardingSignData.getSignDescription(
                        profile.moonSign, 'moon'),
                    revealed: signRevealStep >= 3,
                    signType: 'moon',
                  ),
                  // Tap to read more hint
                  if (signRevealStep >= 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Tap any card to read more',
                        style: TextStyle(
                          fontSize: 11,
                          color: OnboardingColors.textSecondary(context),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Small share link below cards
                  if (signRevealStep >= 3) ShareLink(onTap: onShare),
                ],
              ),
            ),
          ),
        ),
        // Continue button positioned at bottom (show when all signs revealed)
        if (signRevealStep >= 3)
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

  Widget _buildSignCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String description,
    required bool revealed,
    required String signType,
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
            ? () => _showSignDetails(
                  context: context,
                  icon: icon,
                  color: color,
                  label: label,
                  value: value,
                  description: description,
                  signType: signType,
                )
            : null,
        child: TransparentToolbox(
          height: 130,
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // Label and Icon - left aligned
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
                    // Placement meaning (explaining phrase) - right aligned
                    if (OnboardingSignData.getPlacementMeaning(signType)
                            .isNotEmpty &&
                        revealed)
                      Expanded(
                        child: Text(
                          OnboardingSignData.getPlacementMeaning(signType),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: OnboardingColors.textSecondary(context),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
                // Sign name and tags on same line
                if (revealed) ...[
                  const SizedBox(height: AppDimensions.spacingSmMd),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Sign name - left aligned
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      // Sign traits (tags) - right aligned
                      if (OnboardingSignData.getSignTraits(
                              value == '—' ? null : value)
                          .isNotEmpty)
                        Wrap(
                          spacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: OnboardingSignData.getSignTraits(
                                  value == '—' ? null : value)
                              .map((trait) => Material(
                                    elevation: 1,
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                                    color: color,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                                      ),
                                      child: Text(
                                        trait,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ],
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
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSignDetails({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String description,
    required String signType,
  }) {
    final expandedContent =
        OnboardingSignData.getExpandedSignContent(value, signType);

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
