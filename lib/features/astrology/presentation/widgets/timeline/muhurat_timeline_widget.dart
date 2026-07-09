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
      // Embedded: transparent so it inherits the parent card's surface.
      // Standalone: its own theme-aware surface.
      color: widget.embedded
          ? Colors.transparent
          : (isDark ? const Color(0xFF000000) : Colors.white),
      elevation: 0,
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Padding(
        // Trim the top gap when embedded (it sits directly under the date row);
        // keep the full gap when standalone.
        padding: EdgeInsets.fromLTRB(0, widget.embedded ? 4 : 16, 0, 16),
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
