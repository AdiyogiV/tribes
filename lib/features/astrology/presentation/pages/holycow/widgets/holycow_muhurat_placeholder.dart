import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';

/// Muhurat ("time guidance") loading placeholder card.
///
/// Shown only for the today-window while the muhurat is still loading for a
/// signed-in user — see `HolyCowCosmicContent._buildMuhuratCard`.
class HolyCowMuhuratPlaceholder extends StatelessWidget {
  final Color cardColor;
  const HolyCowMuhuratPlaceholder({super.key, required this.cardColor});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Row(
          children: [
            AppLoadingIndicator(
              size: 16,
              strokeWidth: 2,
              color: c.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Text(
              'Loading time guidance...',
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w500,
                color: c.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
