import 'package:flutter/material.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Card to display today's cosmic insight
/// Matches astrology details page card styling
class CosmicInsightCard extends StatelessWidget {
  final DailyInsight insight;
  final Color brown;

  const CosmicInsightCard({
    super.key,
    required this.insight,
    required this.brown,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final c = AppTheme.primaryColor;

    final message = insight.displayMessage;

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - Title Case, matches astrology details page
            Text(
              'Current Energy',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
            // Message - full text
            if (message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
