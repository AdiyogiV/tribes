import 'package:flutter/material.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/widgets/astrology/insight_cards/astro_card_theme.dart';

/// Guidance card - actionable advice with subtle accent
class GuidanceCard extends StatelessWidget {
  final InsightSection section;
  
  const GuidanceCard({Key? key, required this.section}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.astroCardTheme;
    
    return Material(
      color: theme.cardBackground,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: theme.cardPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
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
