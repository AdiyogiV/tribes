import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Time slider widget for navigating through different dates
class TimelineSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final bool hasData;
  final bool isLoading;
  final VoidCallback? onLoadData;
  final VoidCallback? onForceRefresh;
  final bool isDark;

  const TimelineSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.hasData,
    required this.isLoading,
    this.onLoadData,
    this.onForceRefresh,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final brown = AppTheme.primaryColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        children: [
          _ModernSlider(
            value: value,
            onChanged: hasData ? onChanged : null,
            leftColor: Colors.teal.shade600,
            rightColor: Colors.teal.shade300,
            isDark: isDark,
          ),
          // Loading indicator or status (centered, no dates)
          if (!hasData)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: [
                  if (isLoading)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppLoadingIndicator(
                          size: 12,
                          strokeWidth: 1.5,
                          color: Colors.teal.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: AppDimensions.spacingSmMd),
                        Text(
                          'Loading timeline...',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.teal.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Text(
                          'Timeline data not available',
                          style: TextStyle(
                            fontSize: 9,
                            color: brown.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingXs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (onLoadData != null)
                              GestureDetector(
                                onTap: onLoadData,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                  ),
                                  child: Text(
                                    'Load Data',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.teal.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            if (onLoadData != null && onForceRefresh != null)
                              const SizedBox(width: AppDimensions.spacingSmMd),
                            if (onForceRefresh != null)
                              GestureDetector(
                                onTap: onForceRefresh,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                  ),
                                  child: Text(
                                    'Force Refresh',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.orange.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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

/// Modern thin slider widget
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
