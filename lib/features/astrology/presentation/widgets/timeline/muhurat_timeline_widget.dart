import 'package:flutter/material.dart';

import 'widgets/timeline_content.dart';
import 'widgets/timeline_controller.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Muhurat timeline visualization widget showing auspicious/inauspicious times
/// Accepts global muhurat data directly (not via AstrologyProfile)
/// Now manages its own animation controller for the blinking current time indicator
class MuhuratTimelineWidget extends StatefulWidget {
  final Map<String, dynamic> muhurat;
  final bool embedded;

  const MuhuratTimelineWidget({
    super.key,
    required this.muhurat,
    this.embedded = false,
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

    return Material(
      color: Colors.black,
      elevation: 0,
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
        child: TimelineContent(
          muhurat: widget.muhurat,
          isDark: isDark,
          blinkController: _blinkController,
          controller: _timelineController,
        ),
      ),
    );
  }
}
