import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Shows the creation selection dialog (Post or Story).
///
/// Returns the user's choice: 'post', 'story', or null if dismissed.
Future<String?> showCreateSelectionDialog(BuildContext context) {
  return AppBottomSheet.show<String>(
    context,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Post option
            CreationOptionCard(
              icon: CupertinoIcons.square_grid_2x2,
              title: 'Create Post',
              subtitle: 'Share photos, videos, or notes',
              gradient: const LinearGradient(
                colors: [
                  AppTheme.indigoColor, // Indigo
                  AppTheme.pinkAccent, // Pink
                ],
              ),
              onTap: () {
                Navigator.of(context).pop('post');
              },
            ),

            const SizedBox(height: AppDimensions.spacingXxl),

            // Story option
            CreationOptionCard(
              icon: CupertinoIcons.camera_fill,
              title: 'Create Story',
              subtitle: 'Share moments that disappear in 24h',
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0EA5E9), // Sky blue
                  AppTheme.emeraldGreen, // Green
                ],
              ),
              onTap: () {
                Navigator.of(context).pop('story');
              },
            ),

            const SizedBox(height: AppDimensions.spacingXl),
          ],
        ),
      ),
    ),
  );
}

/// Individual creation option card.
class CreationOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const CreationOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingXxl),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingXl),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingSmMd),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow icon
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
