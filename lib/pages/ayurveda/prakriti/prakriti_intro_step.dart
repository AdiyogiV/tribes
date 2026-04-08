import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// The intro/physical profile step shown before questions begin.
class PrakritiIntroStep extends StatelessWidget {
  const PrakritiIntroStep({super.key});

  Color get _accentColor => AppTheme.primaryColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingXxl),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.spacingLargeSection),
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
            ),
            child: Icon(Icons.spa_outlined, size: 40, color: _accentColor),
          ),
          const SizedBox(height: AppDimensions.spacingXxl),
          Text(
            'Refine Your Prakriti',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
            child: Text(
              'Answer a few quick questions about your natural tendencies. This helps personalize your Ayurveda insights.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLargeSection),

          // What to expect
          _ExpectItem(
            isDark: isDark,
            icon: Icons.timer_outlined,
            text: '2-3 minutes',
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          _ExpectItem(
            isDark: isDark,
            icon: Icons.psychology_outlined,
            text: '5 personality scenarios',
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          _ExpectItem(
            isDark: isDark,
            icon: Icons.auto_awesome,
            text: 'Option for deeper assessment',
          ),
        ],
      ),
    );
  }
}

class _ExpectItem extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String text;

  const _ExpectItem({
    required this.isDark,
    required this.icon,
    required this.text,
  });

  Color get _accentColor => AppTheme.primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: _accentColor.withValues(alpha: 0.8)),
          const SizedBox(width: AppDimensions.spacingLg),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
