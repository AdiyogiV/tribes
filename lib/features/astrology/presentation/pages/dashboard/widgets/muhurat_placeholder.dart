import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';

/// Muhurat ("time guidance") loading placeholder card.
///
/// Shown only for the today-window while the muhurat is still loading for a
/// signed-in user — see `AstroDashboardContent._buildMuhuratCard`.
class MuhuratPlaceholder extends StatelessWidget {
  final Color cardColor;

  /// When true, skip the outer [Material] card surface so a parent can host
  /// this inside a SHARED card. Defaults to false — standalone card.
  final bool embedded;

  const MuhuratPlaceholder({
    super.key,
    required this.cardColor,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    final content = Padding(
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
              fontSize: AppTheme.babaTextSize,
              fontWeight: FontWeight.w500,
              color: c.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );

    if (embedded) return content;

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: content,
    );
  }
}
