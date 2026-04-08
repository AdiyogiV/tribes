import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import 'preview_box_placeholders.dart';

/// Image builder helpers used by [PreviewBox].
///
/// These are extracted as free functions so the main file stays compact.

/// Builds the primary preview image (network on web, file on mobile).
Widget buildPreviewImage({
  required bool isWeb,
  required String? webPreviewUrl,
  required dynamic preview,
  required bool compact,
  required bool isUploading,
  required BuildContext context,
}) {
  if (isWeb && webPreviewUrl != null) {
    return Image.network(
      webPreviewUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        AppLogger.w('Error loading preview image (web)',
            category: LogCategory.ui, data: {'error': error.toString()});
        return PreviewBoxPlaceholders.error(context,
            compact: compact, isUploading: isUploading);
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return PreviewBoxPlaceholders.loading(context);
      },
    );
  }
  // Mobile: use Image.file
  if (!isWeb && preview != null) {
    return Image.file(
      preview!,
      fit: BoxFit.cover,
      errorBuilder: (ctx, error, stackTrace) {
        return PreviewBoxPlaceholders.error(ctx,
            compact: compact, isUploading: isUploading);
      },
    );
  }
  return PreviewBoxPlaceholders.error(context,
      compact: compact, isUploading: isUploading);
}

/// Builds the author profile picture image (network on web, file on mobile).
Widget buildAuthorPicImage({
  required bool isWeb,
  required String? webAuthorPicUrl,
  required dynamic authorPicture,
  required bool compact,
}) {
  Widget errorWidget = Container(
    color: AppTheme.primaryLightColor.withValues(alpha: 0.2),
    child: Icon(
      Icons.person,
      color: AppTheme.textSecondaryLightColor,
      size: compact ? 10 : 20,
    ),
  );

  if (isWeb && webAuthorPicUrl != null) {
    return Image.network(
      webAuthorPicUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => errorWidget,
    );
  }
  if (!isWeb && authorPicture != null) {
    return Image.file(
      authorPicture!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => errorWidget,
    );
  }
  return errorWidget;
}
