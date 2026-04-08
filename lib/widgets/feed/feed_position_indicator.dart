import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Position indicator for horizontal carousels (dot indicators)
class DotIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final Color? activeColor;
  final Color? inactiveColor;
  final double dotSize;
  final double spacing;

  const DotIndicator({
    super.key,
    required this.currentIndex,
    required this.totalCount,
    this.activeColor,
    this.inactiveColor,
    this.dotSize = 6,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (totalCount <= 1) return const SizedBox.shrink();
    
    // Limit visible dots for large collections
    final int maxVisibleDots = 7;
    final bool showEllipsis = totalCount > maxVisibleDots;
    final int visibleCount = showEllipsis ? maxVisibleDots : totalCount;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(visibleCount, (index) {
        // For large collections, show ellipsis indicator
        if (showEllipsis && index == maxVisibleDots - 1 && currentIndex < totalCount - 1) {
          return Container(
            width: dotSize * 2,
            height: dotSize,
            alignment: Alignment.center,
            child: Text(
              '...',
              style: TextStyle(
                fontSize: 10,
                color: inactiveColor ?? AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
          );
        }
        
        final bool isActive = index == currentIndex;
        
        return Container(
          margin: EdgeInsets.symmetric(horizontal: spacing / 2),
          width: isActive ? dotSize * 2 : dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: isActive
                ? (activeColor ?? AppTheme.primaryColor)
                : (inactiveColor ?? AppTheme.primaryColor.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(dotSize / 2),
          ),
        );
      }),
    );
  }
}

/// Text-based position indicator for vertical feeds
class FeedPositionText extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final bool showTotal;

  const FeedPositionText({
    super.key,
    required this.currentIndex,
    required this.totalCount,
    this.showTotal = true,
  });

  @override
  Widget build(BuildContext context) {
    if (totalCount <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        showTotal
            ? '${currentIndex + 1} of $totalCount'
            : '${currentIndex + 1}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}

/// Reply count indicator with swipe hint
class ReplyCountIndicator extends StatelessWidget {
  final int replyCount;
  final bool showSwipeHint;

  const ReplyCountIndicator({
    super.key,
    required this.replyCount,
    this.showSwipeHint = true,
  });

  @override
  Widget build(BuildContext context) {
    if (replyCount <= 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.reply,
          size: 14,
          color: AppTheme.primaryColor.withValues(alpha: 0.7),
        ),
        const SizedBox(width: AppDimensions.spacingXs),
        Text(
          '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.primaryColor.withValues(alpha: 0.7),
          ),
        ),
        if (showSwipeHint) ...[
          const SizedBox(width: AppDimensions.spacingSmMd),
          Icon(
            Icons.swipe,
            size: 12,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.4),
          ),
        ],
      ],
    );
  }
}

/// Scroll progress indicator (linear)
class ScrollProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color? backgroundColor;
  final Color? progressColor;
  final double height;

  const ScrollProgressIndicator({
    super.key,
    required this.progress,
    this.backgroundColor,
    this.progressColor,
    this.height = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: progressColor ?? AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}






