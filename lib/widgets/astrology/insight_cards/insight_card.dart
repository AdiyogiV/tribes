import 'package:flutter/material.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/widgets/astrology/insight_cards/astro_card_theme.dart';

/// Standard insight card - clean text with rich formatting
class InsightCard extends StatelessWidget {
  final InsightSection section;
  final Widget? footer;
  
  const InsightCard({super.key, required this.section, this.footer});

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(section.title, style: theme.titleStyle),
            if (section.content.isNotEmpty) ...[
              SizedBox(height: theme.titleContentSpacing),
              theme.buildRichText(section.content),
            ],
            if (footer != null) ...[
              const SizedBox(height: 12),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
