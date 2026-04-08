import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';

/// Empty state widget shown when user has no astrology profile.
///
/// Provides a call-to-action to set up birth details. Wraps [EmptyStateWidget]
/// inside a Material card to match the astrology page's elevated card style.
class AstrologyEmptyState extends StatelessWidget {
  final VoidCallback onSetup;
  final String? title;
  final String? message;
  final String? buttonText;
  final IconData? icon;

  const AstrologyEmptyState({
    super.key,
    required this.onSetup,
    this.title,
    this.message,
    this.buttonText,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Material(
            color: cardColor,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: EmptyStateWidget(
                icon: icon ?? Icons.auto_awesome_rounded,
                iconSize: 48,
                iconColor: AppTheme.primaryColor,
                title: title ?? 'No Astrology Data',
                subtitle: message ??
                    'Add your birth details to see your\npersonalized birth chart',
                padding: EdgeInsets.zero,
                action: ElevatedButton.icon(
                  onPressed: onSetup,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(buttonText ?? 'Add Birth Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}




