import 'package:flutter/material.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/widgets/astrology/insight_cards/astro_card_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Guidance card - actionable advice with subtle accent
class GuidanceCard extends StatelessWidget {
  final InsightSection section;
  
  const GuidanceCard({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = context.astroCardTheme;
    
    return Material(
      color: theme.cardBackground,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Container(
        width: double.infinity,
        padding: theme.cardPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          border: Border(
            left: BorderSide(color: theme.brown.withValues(alpha: 0.4), width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(section.title, style: theme.titleStyle),
            if (section.content.isNotEmpty) ...[
              SizedBox(height: theme.titleContentSpacing),
              theme.buildRichText(section.content),
            ],
          ],
        ),
      ),
    );
  }
}
