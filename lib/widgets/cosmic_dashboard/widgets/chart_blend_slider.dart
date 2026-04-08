import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';

/// Slider widget for blending between sky chart and birth chart overlay
class ChartBlendSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final bool isDark;

  const ChartBlendSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final brown = AppTheme.primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          _ModernSlider(
            value: value,
            onChanged: onChanged,
            leftColor: Colors.teal,
            rightColor: Colors.amber.shade600,
            isDark: isDark,
          ),
          // Labels
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingXs),
                    Text(
                      'Sky',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                            value < 0.5 ? FontWeight.w600 : FontWeight.w400,
                        color: brown.withValues(alpha: value < 0.5 ? 0.7 : 0.4),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Birth',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                            value >= 0.5 ? FontWeight.w600 : FontWeight.w400,
                        color:
                            brown.withValues(alpha: value >= 0.5 ? 0.7 : 0.4),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingXs),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade600,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern thin slider widget used throughout cosmic dashboard
class _ModernSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final Color leftColor;
  final Color rightColor;
  final bool isDark;

  const _ModernSlider({
    required this.value,
    required this.onChanged,
    required this.leftColor,
    required this.rightColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onChanged == null;
    final thumbColor = Color.lerp(leftColor, rightColor, value) ?? leftColor;

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 6,
          disabledThumbRadius: 5,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        thumbColor: isDisabled ? Colors.grey.shade400 : thumbColor,
        overlayColor: thumbColor.withValues(alpha: 0.12),
        activeTrackColor: leftColor.withValues(alpha: isDisabled ? 0.25 : 0.7),
        inactiveTrackColor:
            rightColor.withValues(alpha: isDisabled ? 0.1 : 0.3),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        value: value,
        onChanged: onChanged,
        min: 0,
        max: 1,
      ),
    );
  }
}
