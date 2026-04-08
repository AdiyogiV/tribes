import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_base.dart';

// =============================================================================
// CARD SKELETONS: For content cards
// =============================================================================

/// Card skeleton for posts/content
class SkeletonCard extends StatelessWidget {
  final double? height;

  const SkeletonCard({super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);

    return ShimmerBox(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.base,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.highlight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMdSm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors.highlight,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Container(
                        width: 60,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors.shimmer,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: colors.highlight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid item skeleton for image grids
class SkeletonGridItem extends StatelessWidget {
  final double aspectRatio;

  const SkeletonGridItem({super.key, this.aspectRatio = 1.0});

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);

    return ShimmerBox(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: colors.base,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colors.shimmer,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Image placeholder with shimmer - simple box for image loading
class ShimmerImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const ShimmerImagePlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);
    return ShimmerBox(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.base,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

// =============================================================================
// POST BOX SKELETON: One post-shaped box with separate skeleton areas
// =============================================================================

/// Single post box with fixed-height skeleton sections: header, content, toolbar.
/// Used in feed (placeholder items) and inside Post when loading. Same layout
/// everywhere so content "fills in" the same box – no list swap, no overflow.
class PostBoxSkeleton extends StatelessWidget {
  const PostBoxSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: avatar + 2 lines (fixed height)
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
          child: Row(
            children: [
              ShimmerBox(
                child: SkeletonCircle(size: 40),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(
                    child: SkeletonLine(width: 120, height: 12),
                  ),
                  const SizedBox(height: AppDimensions.spacingSmMd),
                  ShimmerBox(
                    child: SkeletonLine(width: 80, height: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Content area (fixed height)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: ShimmerBox(
            child: SkeletonBox(height: 180, width: double.infinity),
          ),
        ),
        // Toolbar: icon placeholders (fixed height)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: AppDimensions.spacingLg),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: AppDimensions.spacingLg),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Video post skeleton - tall media box to match typical video posts.
class PostVideoSkeleton extends StatelessWidget {
  const PostVideoSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonCircle(size: 40)),
              const SizedBox(width: AppDimensions.spacingMd),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(child: SkeletonLine(width: 120, height: 12)),
                  const SizedBox(height: AppDimensions.spacingSmMd),
                  ShimmerBox(child: SkeletonLine(width: 80, height: 10)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: ShimmerBox(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: const SkeletonBox(width: double.infinity),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: AppDimensions.spacingLg),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: AppDimensions.spacingLg),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Audio post skeleton - medium height media box.
class PostAudioSkeleton extends StatelessWidget {
  const PostAudioSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonCircle(size: 40)),
              const SizedBox(width: AppDimensions.spacingMd),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(child: SkeletonLine(width: 120, height: 12)),
                  const SizedBox(height: AppDimensions.spacingSmMd),
                  ShimmerBox(child: SkeletonLine(width: 80, height: 10)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: ShimmerBox(
            child: SkeletonBox(height: 220, width: double.infinity),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: AppDimensions.spacingLg),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: AppDimensions.spacingLg),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Text post skeleton - smaller media area and text lines.
class PostTextSkeleton extends StatelessWidget {
  const PostTextSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonCircle(size: 40)),
              const SizedBox(width: AppDimensions.spacingMd),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(child: SkeletonLine(width: 120, height: 12)),
                  const SizedBox(height: AppDimensions.spacingSmMd),
                  ShimmerBox(child: SkeletonLine(width: 80, height: 10)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(
                  child: SkeletonLine(width: double.infinity, height: 12)),
              const SizedBox(height: AppDimensions.spacingSm),
              ShimmerBox(
                  child: SkeletonLine(width: double.infinity, height: 12)),
              const SizedBox(height: AppDimensions.spacingSm),
              ShimmerBox(child: SkeletonLine(width: 200, height: 12)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: AppDimensions.spacingLg),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: AppDimensions.spacingLg),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Image post skeleton - square media box for images.
class PostImageSkeleton extends StatelessWidget {
  const PostImageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonCircle(size: 40)),
              const SizedBox(width: AppDimensions.spacingMd),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerBox(child: SkeletonLine(width: 120, height: 12)),
                  const SizedBox(height: AppDimensions.spacingSmMd),
                  ShimmerBox(child: SkeletonLine(width: 80, height: 10)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: ShimmerBox(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: const SkeletonBox(width: double.infinity),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: AppDimensions.spacingLg),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
              const SizedBox(width: AppDimensions.spacingLg),
              ShimmerBox(child: SkeletonLine(width: 24, height: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact card for posts still processing/uploading.
class PostProcessingCard extends StatelessWidget {
  const PostProcessingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      decoration: BoxDecoration(
        color: colors.base,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: colors.highlight),
      ),
      child: Row(
        children: [
          ShimmerBox(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.shimmer,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Processing post...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSmMd),
                Text(
                  'This post will appear shortly.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact card for missing/unavailable posts.
class PostUnavailableCard extends StatelessWidget {
  const PostUnavailableCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      decoration: BoxDecoration(
        color: colors.base,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: colors.highlight),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.shimmer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              size: 20,
              color: Colors.black38,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Post unavailable',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSmMd),
                Text(
                  'This post could not be loaded.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
