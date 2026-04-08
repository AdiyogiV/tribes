import 'package:flutter/material.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/widgets/astrology/insight_cards/hero_card.dart';
import 'package:aurogram/widgets/astrology/insight_cards/prediction_card.dart';
import 'package:aurogram/widgets/astrology/insight_cards/guidance_card.dart';
import 'package:aurogram/widgets/astrology/insight_cards/insight_card.dart';

/// Card Dispatcher - Routes card type to appropriate widget
/// Simplified to 3 core types: hero, prediction, guidance
/// All other types fall back to InsightCard for backward compatibility
class CardDispatcher extends StatelessWidget {
  final InsightSection section;
  
  const CardDispatcher({
    super.key,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    switch (section.cardType) {
      case 'hero':
        return HeroCard(section: section);
      
      case 'prediction':
        return PredictionCard(section: section);
      
      case 'guidance':
        return GuidanceCard(section: section);
      
      // All other types (legacy: strength, timing, alert, etc.) use generic card
      default:
        return InsightCard(section: section);
    }
  }
}

/// Extension to build a list of cards from sections
extension CardDispatcherList on List<InsightSection> {
  /// Build card widgets from sections, sorted by displayOrder
  List<Widget> toCardWidgets({double spacing = 12}) {
    // Sort by displayOrder if present, otherwise keep original order
    final sorted = [...this];
    sorted.sort((a, b) {
      final orderA = a.displayOrder ?? 999;
      final orderB = b.displayOrder ?? 999;
      return orderA.compareTo(orderB);
    });
    
    return sorted.asMap().entries.map((entry) {
      final index = entry.key;
      final section = entry.value;
      
      return Padding(
        padding: EdgeInsets.only(top: index == 0 ? 0 : spacing),
        child: CardDispatcher(section: section),
      );
    }).toList();
  }
}
