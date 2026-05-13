import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Card to display today's cosmic insight
/// Matches astrology details page card styling
class CosmicInsightCard extends StatelessWidget {
  final DailyInsight insight;
  final Color brown;
  /// Optional tap handler — when set, card becomes tappable and shows
  /// a "See full reading" affordance at the bottom.
  final VoidCallback? onTap;

  const CosmicInsightCard({
    super.key,
    required this.insight,
    required this.brown,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final c = AppTheme.primaryColor;

    final message = insight.displayMessage;

    final card = Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - Title Case, matches astrology details page
            Text(
              'Current Energy',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
            // Message - full text
            if (message.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.holyCowTextSize,
                  fontWeight: FontWeight.w500,
                  color: c.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ],
            // "See full reading" affordance
            if (onTap != null) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'See more insights',
                    style: TextStyle(
                      fontSize: AppTheme.holyCowTextSize,
                      fontWeight: FontWeight.w600,
                      color: c.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: c.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: card,
      );
    }

    return card;
  }
}
