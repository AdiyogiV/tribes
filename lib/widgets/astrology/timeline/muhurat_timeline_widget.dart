import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

import 'widgets/muhurat_descriptions.dart';
import 'widgets/timeline_content.dart';
import 'widgets/timeline_controller.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Muhurat timeline visualization widget showing auspicious/inauspicious times
/// Accepts global muhurat data directly (not via AstrologyProfile)
/// Now manages its own animation controller for the blinking current time indicator
class MuhuratTimelineWidget extends StatefulWidget {
  final Map<String, dynamic> muhurat;

  const MuhuratTimelineWidget({
    super.key,
    required this.muhurat,
  });

  @override
  State<MuhuratTimelineWidget> createState() => _MuhuratTimelineWidgetState();
}

class _MuhuratTimelineWidgetState extends State<MuhuratTimelineWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  final _timelineController = TimelineController();

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.muhurat.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with same padding as other cards (16 all sides, 12 bottom gap)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time Guidance',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _timelineController.scrollToNow?.call(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingXs),
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: AppTheme.primaryColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    GestureDetector(
                      onTap: () => showMuhuratInfoDialog(context),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingXs),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppTheme.primaryColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Timeline content - edge to edge (no horizontal padding)
          TimelineContent(
            muhurat: widget.muhurat,
            isDark: isDark,
            blinkController: _blinkController,
            controller: _timelineController,
          ),
          // Bottom padding to match top (16px)
          const SizedBox(height: AppDimensions.spacingLg),
        ],
      ),
    );
  }
}
