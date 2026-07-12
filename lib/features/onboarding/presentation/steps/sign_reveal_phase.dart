import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_constants.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_sign_data.dart';
import 'package:aurogram/features/onboarding/presentation/widgets/onboarding_dialogs.dart';
import 'package:aurogram/features/onboarding/presentation/steps/shared_widgets.dart';

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
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: _buildContent(context),
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
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 32, right: 32, top: 64, bottom: 120),
              child: _buildContent(context),
            ),
          ),
        ),
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

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THE BLUEPRINT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: OnboardingColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 48),

        // Rising
        _buildSignRow(
          context: context,
          label: 'Rising',
          value: profile.ascendant ?? '—',
          description: OnboardingSignData.getSignDescription(profile.ascendant, 'rising'),
          revealed: signRevealStep >= 1,
          signType: 'rising',
        ),

        // Sun
        _buildSignRow(
          context: context,
          label: 'Sun',
          value: profile.sunSign ?? '—',
          description: OnboardingSignData.getSignDescription(profile.sunSign, 'sun'),
          revealed: signRevealStep >= 2,
          signType: 'sun',
        ),

        // Moon
        _buildSignRow(
          context: context,
          label: 'Moon',
          value: profile.moonSign ?? '—',
          description: OnboardingSignData.getSignDescription(profile.moonSign, 'moon'),
          revealed: signRevealStep >= 3,
          signType: 'moon',
          isLast: true,
        ),

        if (signRevealStep >= 3)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: ShareLink(onTap: onShare),
          ),
          
        if (signRevealStep >= 3 && MediaQuery.of(context).size.width >= 600)
          Padding(
            padding: const EdgeInsets.only(top: 64),
            child: ContinueButton(
              label: 'Continue',
              onTap: onContinue,
            ),
          ),
      ],
    );
  }

  Widget _buildSignRow({
    required BuildContext context,
    required String label,
    required String value,
    required String description,
    required bool revealed,
    required String signType,
    bool isLast = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: revealed ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        return Opacity(
          opacity: anim.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - anim)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: revealed
            ? () => _showSignDetails(
                  context: context,
                  label: label,
                  value: value,
                  description: description,
                  signType: signType,
                )
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isLast ? Colors.transparent : AppTheme.primaryColor.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                  if (revealed && OnboardingSignData.getPlacementMeaning(signType).isNotEmpty)
                    Text(
                      OnboardingSignData.getPlacementMeaning(signType),
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (revealed) ...[
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.primaryColor,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w300,
                      color: AppTheme.primaryColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSignDetails({
    required BuildContext context,
    required String label,
    required String value,
    required String description,
    required String signType,
  }) {
    final expandedContent =
        OnboardingSignData.getExpandedSignContent(value, signType);

    CardDetailsDialog.show(
      context,
      icon: Icons.auto_awesome,
      color: AppTheme.primaryColor,
      title: value,
      subtitle: label,
      description: description,
      expandedContent: expandedContent,
    );
  }
}
