import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/theme_helper.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Brand header with welcome text.
class LoginBrandHeader extends StatelessWidget {
  final bool isWide;

  const LoginBrandHeader({super.key, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppDimensions.spacingMd),
        Text(
          'welcome to aurogram',
          textAlign: TextAlign.center,
          style: ThemeHelper.headerStyle.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSection),
      ],
    );
  }
}

/// Icon strip showing benefits/brand icons.
class LoginBenefitsStrip extends StatelessWidget {
  final bool isWide;

  const LoginBenefitsStrip({super.key, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final double iconSize = isWide ? 72 : 64;

    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 16,
      spacing: 10,
      children: [
        Image.asset(
          'assets/icons/namaste.png',
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
        ),
        Image.asset(
          'assets/images/icon_transparent.png',
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
        ),
        Image.asset(
          'assets/images/cow1.png',
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

/// EULA acceptance checkbox + policy links.
class LoginPolicyText extends StatelessWidget {
  final bool eulaAccepted;
  final ValueChanged<bool> onEulaChanged;
  final ValueChanged<String> onShowPolicy;

  const LoginPolicyText({
    super.key,
    required this.eulaAccepted,
    required this.onEulaChanged,
    required this.onShowPolicy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
      child: Column(
        children: [
          // EULA Acceptance Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: eulaAccepted,
                onChanged: (value) => onEulaChanged(value ?? false),
                activeColor: AppTheme.primaryColor,
                checkColor: Colors.white,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onEulaChanged(!eulaAccepted),
                  child: Text(
                    'I agree to the Terms of Service, Privacy Policy, and Community Guidelines',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontSize: 14,
                          height: 1.4,
                        ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingMd),
          Wrap(
            alignment: WrapAlignment.center,
            runSpacing: 8,
            children: [
              _buildPolicyLink(context, 'Community Guidelines'),
              _buildDot(context),
              _buildPolicyLink(context, 'Privacy Policy'),
              _buildDot(context),
              _buildPolicyLink(context, 'Terms of Service'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyLink(BuildContext context, String label) {
    return GestureDetector(
      onTap: () => onShowPolicy(label),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
              fontSize: 15,
              decoration: TextDecoration.underline,
            ),
      ),
    );
  }

  Widget _buildDot(BuildContext context) {
    return Text(
      '  •  ',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondaryLightColor,
            fontSize: 15,
          ),
    );
  }
}

/// Subtitle shown when OTP code is sent.
class LoginSubtitle extends StatelessWidget {
  final bool isWide;
  final bool codeSent;

  const LoginSubtitle({
    super.key,
    required this.isWide,
    required this.codeSent,
  });

  @override
  Widget build(BuildContext context) {
    if (!codeSent) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          codeSent
              ? 'Enter the verification code sent to your phone'
              : 'Sign in with your phone number',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.primaryColor.withValues(alpha: 0.9),
                fontWeight: FontWeight.w400,
                fontSize: isWide ? 15 : 16,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}

/// Shows a policy dialog (Community Guidelines / Privacy Policy / Terms).
void showPolicyDialog(BuildContext context, String policyType) {
  String title;
  String content;

  switch (policyType) {
    case 'Community Guidelines':
      title = 'Community Guidelines';
      content = '''Aurogram is a safe, respectful space for everyone.

• Be kind
• Be respectful
• No harassment
• No bullying
• No hate speech
• Content appropriate for all ages
• Welcome new members
• Report bad behaviour
• No impersonation
• No scams

We're here to make Aurogram a place you can trust.''';
      break;
    case 'Privacy Policy':
      title = 'Privacy Policy';
      content = '''Your privacy matters to us.

• We collect only what's needed
• We never sell your data
• Data is encrypted
• Stored securely
• You can delete anytime
• You control your account
• No third-party data sharing
• Minimal analytics
• Location only when you allow
• Transparent about what we use

We're committed to keeping your information safe.''';
      break;
    case 'Terms of Service':
      title = 'Terms of Service';
      content =
          '''By using Aurogram, you agree to use it respectfully and lawfully.

ZERO TOLERANCE POLICY:
• We have zero tolerance for objectionable content or abusive users
• Objectionable content includes harassment, threats, hate speech, explicit content, or any content that violates community standards
• Users who violate these terms will be immediately removed from the platform
• We act on reports within 24 hours by removing content and ejecting offending users

USER RESPONSIBILITIES:
• Use services in good faith
• Respect others' privacy
• Respect others' rights
• No spam
• No misuse
• No illegal activity
• No fake accounts
• Follow the law
• Report objectionable content immediately

MODERATION:
• We may suspend or permanently ban rule-breakers
• All user-generated content is subject to review
• We reserve the right to remove any content that violates these terms

We're here to keep Aurogram safe for everyone.''';
      break;
    default:
      return;
  }

  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (context) => TransparentPolicyDialog(
      title: title,
      content: content,
    ),
  );
}

/// Transparent policy dialog that matches the TransparentToolbox styling.
class TransparentPolicyDialog extends StatelessWidget {
  final String title;
  final String content;

  const TransparentPolicyDialog({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barBase =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context).size.height * (isWide ? 0.7 : 0.8),
          maxWidth: isWide ? 500 : screenWidth * 0.9,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          elevation: 4,
          color: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          ),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    barBase.withValues(alpha: isDark ? 0.85 : 0.95),
                    barBase.withValues(alpha: isDark ? 0.80 : 0.90),
                  ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : barBase.withValues(alpha: 0.32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppTheme.primaryColor.withValues(alpha: 0.1),
                            shape: const CircleBorder(),
                            padding: EdgeInsets.all(AppDimensions.paddingSm),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w400,
                          fontSize: 18,
                          height: 1.5,
                        ),
                        child: Text(content),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
