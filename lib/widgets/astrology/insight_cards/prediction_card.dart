import 'package:flutter/material.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/widgets/astrology/insight_cards/astro_card_theme.dart';

/// Prediction card - future forecast with subtle highlight
class PredictionCard extends StatelessWidget {
  final InsightSection section;
  
  const PredictionCard({Key? key, required this.section}) : super(key: key);

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
          // Subtle gradient to make prediction feel special
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.cardBackground,
              theme.brown.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('✦ ', style: TextStyle(color: theme.brown, fontSize: 12)),
                Expanded(child: Text(section.title, style: theme.titleStyle)),
              ],
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
