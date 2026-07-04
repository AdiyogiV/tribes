import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';

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
    final fgMain = isDark ? Colors.white : Colors.black;
    final fgMuted = isDark ? Colors.white54 : Colors.black54;

    final message = insight.displayMessage;

    return TransparentToolbox.buildCard(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap!();
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header - Chic Editorial
          Text(
            'Current Energy',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 26,
              letterSpacing: -0.5,
              color: fgMain,
              height: 1.1,
            ),
          ),
          // Message - airy, editorial style
          if (message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontSize: 12.5,
                color: fgMuted,
                height: 1.5,
              ),
            ),
          ],
          // "See full reading" affordance
          if (onTap != null) ...[
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SEE MORE INSIGHTS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 3.0,
                    color: fgMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: fgMuted,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
