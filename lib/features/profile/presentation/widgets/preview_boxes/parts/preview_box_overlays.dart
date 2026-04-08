import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';

/// Overlay badges that appear on top of a [PreviewBox] image.
///
/// Extracted from preview_box.dart to reduce file size.

/// Green repost badge shown in the top-right corner of reposted posts.
class PreviewBoxRepostBadge extends StatelessWidget {
  final bool compact;

  const PreviewBoxRepostBadge({super.key, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: compact ? 4 : 6,
      right: compact ? 4 : 6,
      child: Container(
        padding: EdgeInsets.all(compact ? 3 : 4),
        decoration: BoxDecoration(
          color: AppTheme.scaffoldLightColor.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          CupertinoIcons.arrow_2_squarepath,
          size: compact ? 12 : 16,
          color: AppTheme.successColor,
        ),
      ),
    );
  }
}

/// Author profile picture shown in the top-left corner.
class PreviewBoxAuthorPic extends StatelessWidget {
  final bool compact;
  final Widget authorPicImage;

  const PreviewBoxAuthorPic({
    super.key,
    required this.compact,
    required this.authorPicImage,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: compact ? 4 : 6,
      left: compact ? 4 : 8,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.scaffoldLightColor,
          boxShadow: compact
              ? []
              : [
                  BoxShadow(
                    color: AppTheme.textLightColor.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Material(
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: compact ? 12 : 22,
            height: compact ? 12 : 22,
            child: authorPicImage,
          ),
        ),
      ),
    );
  }
}

/// Play-button icon overlay shown in the center of video previews.
class PreviewBoxPlayIcon extends StatelessWidget {
  const PreviewBoxPlayIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
