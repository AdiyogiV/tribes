import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Reusable sign card for onboarding (Sun, Moon, Rising)
class OnboardingSignCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String description;
  final bool revealed;
  final VoidCallback? onTap;

  const OnboardingSignCard({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.description,
    required this.revealed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        onTap: revealed ? onTap : null,
        child: TransparentToolbox(
          content: Row(
            children: [
              // Icon
              Icon(icon, color: color, size: 22),
              const SizedBox(width: AppDimensions.spacingMdLg),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingSm),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: color.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.spacingXxs),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.primaryColor.withValues(alpha: 0.55),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable highlight card for onboarding (Yoga, Dasha, Nakshatra)
class OnboardingHighlightCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String description;
  final bool revealed;
  final VoidCallback? onTap;

  const OnboardingHighlightCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.revealed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: revealed ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        final clampedOpacity = anim.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 16 * (1 - anim)),
          child: Opacity(
            opacity: clampedOpacity,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: revealed ? onTap : null,
        child: TransparentToolbox(
          height: 95,
          content: Row(
            children: [
              // Icon
              Icon(icon, color: color, size: 22),
              const SizedBox(width: AppDimensions.spacingMdLg),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor.withValues(alpha: 0.85),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacingXxs),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: color.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor.withValues(alpha: 0.55),
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable path button for onboarding choices
class OnboardingPathButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const OnboardingPathButton({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: TransparentToolbox(
        content: Row(
          children: [
            // Icon
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppDimensions.spacingMd),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor.withValues(alpha: 0.85),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryColor.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.6),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable continue button for onboarding phases
class OnboardingContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const OnboardingContinueButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: TransparentToolbox(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppTheme.primaryColor.withValues(alpha: 0.85),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Share link button for onboarding
class OnboardingShareLink extends StatelessWidget {
  final VoidCallback onTap;

  const OnboardingShareLink({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_new_rounded,
                color: AppTheme.primaryColor,
                size: 18,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                'Share your blueprint',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onboarding header widget with app icon and title
class OnboardingHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const OnboardingHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final subtitleColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : Colors.black54;

    return Column(
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
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppDimensions.spacingSmMd),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 14,
              color: subtitleColor,
            ),
          ),
        ],
      ],
    );
  }
}
