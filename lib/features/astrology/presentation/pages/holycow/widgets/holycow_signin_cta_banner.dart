import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/routing/route_names.dart';

/// Sign-in CTA banner.
///
/// A full-width brand-aligned upsell shown only when the user is signed-out.
/// Lives below the two-column dashboard so it doesn't lopside either column.
///
/// Two layouts:
///   * horizontal (desktop): icon + headline column + benefit chips + button
///     in a single row — fills the dashboard width like a footer banner.
///   * vertical   (mobile):  icon + headline + benefits stacked + full-width
///     button — a closing prompt at the bottom of the scroll.
class HolyCowSignInCtaBanner extends StatelessWidget {
  final Color brown;
  final bool isDark;
  final bool horizontal;

  const HolyCowSignInCtaBanner({
    super.key,
    required this.brown,
    required this.isDark,
    required this.horizontal,
  });

  static const _benefits = <(IconData, String)>[
    (Icons.auto_awesome_rounded, 'Personalized readings'),
    (Icons.public_rounded, 'Your full birth chart'),
    (Icons.timeline_rounded, 'Track moods across cycles'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    final cardColor = isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(RouteNames.login);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.withValues(alpha: isDark ? 0.18 : 0.10),
                c.withValues(alpha: isDark ? 0.06 : 0.02),
              ],
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: horizontal
                ? AppDimensions.paddingXxl
                : AppDimensions.paddingLg,
            vertical: horizontal
                ? AppDimensions.paddingLg
                : AppDimensions.paddingLg,
          ),
          child: horizontal
              ? _buildHorizontal(context, c)
              : _buildVertical(context, c),
        ),
      ),
    );
  }

  Widget _buildHorizontal(BuildContext context, Color c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icon medallion
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 26,
            color: c,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingLg),
        // Headline + subtitle
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unlock your cosmic blueprint',
                style: TextStyle(
                  fontSize: AppTheme.holyCowTextSize + 4,
                  fontWeight: FontWeight.w700,
                  color: c,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sign in to add your birth details and see how today\'s sky speaks to you.',
                style: TextStyle(
                  fontSize: AppTheme.holyCowTextSize,
                  fontWeight: FontWeight.w500,
                  color: c.withValues(alpha: 0.7),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spacingLg),
        // Benefit chips — collapse gracefully on narrower widths
        Expanded(
          flex: 6,
          child: Wrap(
            spacing: AppDimensions.spacingMd,
            runSpacing: AppDimensions.spacingSm,
            alignment: WrapAlignment.center,
            children: [
              for (final (icon, label) in _benefits)
                _CtaBenefitChip(icon: icon, label: label, color: c),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spacingLg),
        // Primary CTA button
        FilledButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            context.push(RouteNames.login);
          },
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('Sign in'),
          style: FilledButton.styleFrom(
            backgroundColor: c,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVertical(BuildContext context, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 22,
                color: c,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Unlock your cosmic blueprint',
                    style: TextStyle(
                      fontSize: AppTheme.holyCowTextSize + 2,
                      fontWeight: FontWeight.w700,
                      color: c,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sign in to see how today\'s sky speaks to you.',
                    style: TextStyle(
                      fontSize: AppTheme.holyCowTextSize - 1,
                      fontWeight: FontWeight.w500,
                      color: c.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        Wrap(
          spacing: AppDimensions.spacingMd,
          runSpacing: AppDimensions.spacingSm,
          children: [
            for (final (icon, label) in _benefits)
              _CtaBenefitChip(icon: icon, label: label, color: c),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push(RouteNames.login);
            },
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Sign in'),
            style: FilledButton.styleFrom(
              backgroundColor: c,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small pill used inside [HolyCowSignInCtaBanner] benefits row.
class _CtaBenefitChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CtaBenefitChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.75)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.holyCowTextSize - 1,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
