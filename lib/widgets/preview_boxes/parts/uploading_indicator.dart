import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// Animated three dots indicator for uploading posts.
///
/// Extracted from preview_box.dart.
class UploadingIndicator extends StatefulWidget {
  final bool compact;
  final Color iconColor;
  final Color textColor;

  const UploadingIndicator({
    super.key,
    required this.compact,
    required this.iconColor,
    required this.textColor,
  });

  @override
  State<UploadingIndicator> createState() => _UploadingIndicatorState();
}

class _UploadingIndicatorState extends State<UploadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotSize = widget.compact ? 6.0 : 8.0;
    final dotSpacing = widget.compact ? 4.0 : 6.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated three dots
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Stagger the animation for each dot
                final delay = index * 0.2;
                final progress = (_controller.value + delay) % 1.0;
                // Create a smooth pulse: fade in then out
                final opacity = progress < 0.5
                    ? 0.3 + (progress * 2 * 0.7) // 0.3 to 1.0
                    : 1.0 - ((progress - 0.5) * 2 * 0.7); // 1.0 to 0.3

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: dotSpacing / 2),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color: widget.iconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
        // Static text (no animation)
        if (!widget.compact) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Uploading',
            style: TextStyle(
              color: widget.textColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
