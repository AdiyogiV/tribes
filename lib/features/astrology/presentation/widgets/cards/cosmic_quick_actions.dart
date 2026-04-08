import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Quick action buttons for Cosmic Dashboard
/// Matches astrology details page card styling
class CosmicQuickActions extends StatelessWidget {
  final Color brown;
  final VoidCallback onFullChart;
  final VoidCallback onAskAI;

  const CosmicQuickActions({
    super.key,
    required this.brown,
    required this.onFullChart,
    required this.onAskAI,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final c = AppTheme.primaryColor;

    return Row(
      children: [
        Expanded(
          child: _CosmicActionButton(
            label: 'Full Chart',
            color: c,
            cardColor: cardColor,
            onTap: onFullChart,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingMd),
        Expanded(
          child: _CosmicActionButton(
            label: 'Ask AI',
            color: c,
            cardColor: cardColor,
            onTap: onAskAI,
          ),
        ),
      ],
    );
  }
}

class _CosmicActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color cardColor;
  final VoidCallback onTap;

  const _CosmicActionButton({
    required this.label,
    required this.color,
    required this.cardColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
