import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/features/astrology/presentation/widgets/insight_cards/astro_card_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Hero card - opening wisdom, slightly larger text
class HeroCard extends StatelessWidget {
  final InsightSection section;
  
  const HeroCard({super.key, required this.section});

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              section.title,
              style: theme.titleStyle,
            ),
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
