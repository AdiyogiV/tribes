import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/widgets/ui/skeletons/skeleton_base.dart';

// =============================================================================
// STORY RING SKELETON: Horizontal list of story avatars
// =============================================================================

/// Skeleton loader for story ring - shows horizontal list of circular avatars
/// with text labels below, matching the actual StoryRing layout.
class StoryRingSkeleton extends StatelessWidget {
  final int itemCount;
  static const double _avatarSize = 84.0; // Increased size (matches StoryRing)
  static const double _ringWidth = 102.0; // Increased size (matches StoryRing)

  const StoryRingSkeleton({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    // Height: ring (102px) + spacing (4px) + text (16px) = 122px, no extra padding
    return SizedBox(
      height: _ringWidth + 20,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _ringWidth + 4 + 6, // Avatar + spacing + text
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circular avatar skeleton with ring (Instagram size)
                  ShimmerBox(
                    child: Container(
                      width: _ringWidth,
                      height: _ringWidth,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SkeletonColors.fromContext(context).base,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: SkeletonCircle(size: _avatarSize),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  // Text label skeleton
                  SizedBox(
                    width: _ringWidth,
                    height: 16,
                    child: Center(
                      child: ShimmerBox(
                        child: SkeletonLine(
                          width: _ringWidth * 0.6,
                          height: 12,
                          borderRadius: 4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
