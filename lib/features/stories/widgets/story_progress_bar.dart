import 'package:flutter/material.dart';

/// Segmented progress bar displayed at the top of the story viewer.
/// One segment per story; the current segment fills according to [progressController].
class StoryProgressBar extends StatelessWidget {
  final int storyCount;
  final int currentIndex;
  final AnimationController? progressController;

  const StoryProgressBar({
    super.key,
    required this.storyCount,
    required this.currentIndex,
    required this.progressController,
  });

  @override
  Widget build(BuildContext context) {
    if (storyCount == 0 || progressController == null) {
      return const SizedBox.shrink();
    }
    final progress = progressController!.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: List.generate(storyCount, (i) {
          double fill = 0.0;
          if (i < currentIndex) {
            fill = 1.0;
          } else if (i == currentIndex) {
            fill = progress;
          }
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: c.maxWidth * fill,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}
