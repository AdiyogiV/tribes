import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';

import 'uploading_indicator.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Content widgets for text and audio post types inside [PreviewBox].
///
/// Extracted from preview_box.dart to reduce file size.

/// Displays a text post preview inside a PreviewBox.
class PreviewBoxTextContent extends StatelessWidget {
  final String? content;
  final bool compact;
  final bool limitTextPreview;

  const PreviewBoxTextContent({
    super.key,
    required this.content,
    required this.compact,
    required this.limitTextPreview,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double padding = compact ? 6.0 : 12.0;
    final double fontSize = compact ? 7.5 : 12.0;

    // Match TextNotePlayer styling - warm cream background, primary text color
    final backgroundColor =
        isDark ? AppTheme.previewDarkColor : AppTheme.previewLightColor;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
      child: Text(
        limitTextPreview ? _getPreviewText() : _getFullText(),
        style: TextStyle(
          fontSize: fontSize,
          color: isDark
              ? Colors.white
              : AppTheme.primaryColor.withValues(alpha: 0.85),
          height: 1.35,
          fontWeight: FontWeight.w400,
        ),
        overflow: TextOverflow.fade,
        maxLines: compact ? 8 : 12,
      ),
    );
  }

  String _getPreviewText() {
    String text = content ?? '';
    if (text.trim().isEmpty) return 'Empty note';
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    if (text.length > 100) return '${text.substring(0, 100)}...';
    return text;
  }

  String _getFullText() {
    String text = content ?? '';
    if (text.trim().isEmpty) return 'Empty note';
    return text.trim();
  }
}

/// Displays an audio post preview inside a PreviewBox.
class PreviewBoxAudioContent extends StatelessWidget {
  final bool compact;
  final bool isUploading;
  final int? durationInSeconds;
  final String? title;

  const PreviewBoxAudioContent({
    super.key,
    required this.compact,
    required this.isUploading,
    this.durationInSeconds,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Match note preview colors: warm cream (light) / warm brown (dark)
    final backgroundColor =
        isDark ? AppTheme.previewDarkColor : AppTheme.previewLightColor;

    // Show uploading indicator if still uploading
    if (isUploading) {
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

    // Show voice icon with duration after upload
    final iconSize = compact ? 28.0 : 40.0;
    final durationFontSize = compact ? 9.0 : 12.0;

    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Voice icon in a circle
            Container(
              width: iconSize + 16,
              height: iconSize + 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
              ),
              child: Icon(
                CupertinoIcons.waveform,
                color: AppTheme.primaryColor.withValues(alpha: 0.8),
                size: iconSize,
              ),
            ),

            // Duration display
            if (durationInSeconds != null && durationInSeconds! > 0) ...[
              SizedBox(height: compact ? 4 : 8),
              Text(
                _formatAudioDuration(durationInSeconds!),
                style: TextStyle(
                  fontSize: durationFontSize,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
              ),
            ],

            // Title if available
            if (title != null && title!.isNotEmpty && !compact) ...[
              const SizedBox(height: AppDimensions.spacingSmMd),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatAudioDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
