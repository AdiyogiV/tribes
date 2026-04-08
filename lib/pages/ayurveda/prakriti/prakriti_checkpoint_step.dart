import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// The checkpoint step shown after core questions are answered,
/// allowing the user to finish or continue with extended questions.
class PrakritiCheckpointStep extends StatelessWidget {
  final VoidCallback onFinishNow;
  final VoidCallback onContinueExtended;

  const PrakritiCheckpointStep({
    super.key,
    required this.onFinishNow,
    required this.onContinueExtended,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingXxl),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.spacingXl),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle,
                size: 48, color: Colors.green.shade600),
          ),
          const SizedBox(height: AppDimensions.spacingXxl),
          const Text(
            'Quick Assessment Complete!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'You answered 5 core questions.\nWant more accuracy?',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: AppDimensions.spacingSection),

          // Option cards
          _CheckpointCard(
            isDark: isDark,
            icon: Icons.check,
            title: 'Finish Now',
            subtitle: 'Use 5 questions for your assessment',
            isRecommended: false,
            onTap: onFinishNow,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          _CheckpointCard(
            isDark: isDark,
            icon: Icons.add_circle_outline,
            title: 'Answer 5 More Questions',
            subtitle: 'Better accuracy with deeper assessment',
            isRecommended: true,
            onTap: onContinueExtended,
          ),
        ],
      ),
    );
  }
}

class _CheckpointCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isRecommended;
  final VoidCallback onTap;

  const _CheckpointCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isRecommended,
    required this.onTap,
  });

  Color get _accentColor => AppTheme.primaryColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        decoration: BoxDecoration(
          color: isRecommended
              ? _accentColor.withValues(alpha: 0.1)
              : isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
          border: Border.all(
            color: isRecommended
                ? _accentColor.withValues(alpha: 0.3)
                : isDark
                    ? Colors.white12
                    : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isRecommended
                    ? _accentColor.withValues(alpha: 0.15)
                    : isDark
                        ? Colors.white12
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Icon(icon,
                  color: isRecommended ? _accentColor : null, size: 22),
            ),
            const SizedBox(width: AppDimensions.spacingMdLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  if (isRecommended) ...[
                    const SizedBox(height: AppDimensions.spacingXs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accentColor,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                      ),
                      child: const Text('Recommended',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: isDark ? Colors.white38 : Colors.black26),
          ],
        ),
      ),
    );
  }
}
