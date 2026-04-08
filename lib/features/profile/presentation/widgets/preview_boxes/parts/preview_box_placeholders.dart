import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';

import 'uploading_indicator.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Placeholder widgets used by [PreviewBox] for loading, error, uploading
/// states.
///
/// Extracted from preview_box.dart to reduce file size.
class PreviewBoxPlaceholders {
  PreviewBoxPlaceholders._();

  /// Shown while the preview image is loading.
  static Widget loading(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.previewDarkColor : AppTheme.previewLightColor;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
    );
  }

  /// Shown when the preview image fails to load.
  ///
  /// If [isUploading] is true, delegates to [uploadingPlaceholder] instead.
  static Widget error(
    BuildContext context, {
    required bool compact,
    required bool isUploading,
  }) {
    if (isUploading) {
      return uploadingPlaceholder(context, compact: compact);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.previewDarkColor : AppTheme.previewLightColor;

    // Compact mode: minimal icon
    if (compact) {
      return Container(
        color: backgroundColor,
        child: Center(
          child: Icon(
            CupertinoIcons.photo,
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            size: 16,
          ),
        ),
      );
    }

    // Full size: show icon with text
    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.photo,
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
              size: 28,
            ),
            const SizedBox(height: AppDimensions.spacingSmMd),
            Text(
              'No preview',
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown when the post is still uploading but no thumbnail is available yet.
  static Widget uploadingPlaceholder(
    BuildContext context, {
    required bool compact,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.previewDarkColor : AppTheme.previewLightColor;

    return Container(
      color: backgroundColor,
      child: Center(
        child: UploadingIndicator(
          compact: compact,
          iconColor: AppTheme.primaryColor.withValues(alpha: 0.6),
          textColor: AppTheme.primaryColor.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  /// Semi-transparent overlay shown on top of a thumbnail while uploading.
  static Widget uploadingOverlay({required bool compact}) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: UploadingIndicator(
          compact: compact,
          iconColor: Colors.white.withValues(alpha: 0.95),
          textColor: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
