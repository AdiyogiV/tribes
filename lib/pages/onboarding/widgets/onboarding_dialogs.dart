import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Dialog to show expanded card details in onboarding
/// Short, contextual, and personalized information
class CardDetailsDialog extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String description;
  final String? expandedContent;
  final bool isDark;

  const CardDetailsDialog({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
    this.expandedContent,
    required this.isDark,
  });

  static void show(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String description,
    String? expandedContent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => CardDetailsDialog(
        icon: icon,
        color: color,
        title: title,
        subtitle: subtitle,
        description: description,
        expandedContent: expandedContent,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppDimensions.paddingXxl),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.9, end: 1.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Material(
          color: cardColor,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 360,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon and title (fixed, not scrollable)
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingXxl),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                        ),
                        child: Icon(
                          icon,
                          size: 28,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingLg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingXs),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: color,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingSm),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Description
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.black54,
                            height: 1.4,
                          ),
                        ),

                        // Expanded content if available
                        if (expandedContent != null &&
                            expandedContent!.isNotEmpty) ...[
                          const SizedBox(height: AppDimensions.spacingLg),
                          Text(
                            expandedContent!,
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : Colors.black87,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Beautiful notification permission prompt sheet
/// Shows contextual value proposition before asking for permission
class NotificationPermissionSheet extends StatelessWidget {
  final Color primaryColor;
  final bool isDark;

  const NotificationPermissionSheet({
    super.key,
    required this.primaryColor,
    required this.isDark,
  });

  static const Color sunGold = Color(0xFFF5C542);

  @override
  Widget build(BuildContext context) {
    final cardColor =
        isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white;

    return Container(
      margin: const EdgeInsets.all(AppDimensions.paddingLg),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with glow
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingLg),
                decoration: BoxDecoration(
                  color: sunGold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wb_sunny_rounded,
                  size: 40,
                  color: sunGold,
                ),
              ),

              const SizedBox(height: AppDimensions.spacingXl),

              // Title
              Text(
                'Daily Cosmic Updates',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: AppDimensions.spacingMd),

              // Description
              Text(
                'Get gentle morning notifications when your personalized daily insights are ready. We\'ll only notify you once a day.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: primaryColor.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: AppDimensions.spacingSm),

              // Features
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFeatureChip('🌅 Morning insights', primaryColor),
                  const SizedBox(width: AppDimensions.spacingSm),
                  _buildFeatureChip('🔔 Once daily', primaryColor),
                ],
              ),

              const SizedBox(height: AppDimensions.spacingXxl),

              // Enable button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop(true);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        size: 20,
                        color: primaryColor,
                      ),
                      const SizedBox(width: AppDimensions.spacingMdSm),
                      Text(
                        'Enable Notifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.spacingMd),

              // Skip button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(false);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSm),
                  child: Text(
                    'Maybe Later',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
