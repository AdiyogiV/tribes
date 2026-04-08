import 'package:flutter/cupertino.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Upload progress bar
class UploadProgressBar extends StatelessWidget {
  final double progress;

  const UploadProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: AppDimensions.spacingSm),
              AppLoadingIndicator(
                size: 16,
                strokeWidth: 2,
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Text(
                'Uploading... ${progress.toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Attachment button with + icon
class AttachButton extends StatelessWidget {
  final bool isExpanded;
  final bool isUploading;
  final VoidCallback? onTap;

  const AttachButton({
    super.key,
    required this.isExpanded,
    required this.isUploading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isExpanded
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: AnimatedRotation(
          turns: isExpanded ? 0.125 : 0, // 45 degrees
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.add_rounded,
            color: isUploading
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : AppTheme.primaryColor,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Attachment menu with camera, gallery, and video options
class AttachmentMenu extends StatelessWidget {
  final bool isDark;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onVideo;
  final VoidCallback onClose;

  const AttachmentMenu({
    super.key,
    required this.isDark,
    required this.onCamera,
    required this.onGallery,
    required this.onVideo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.cardDarkColor.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AttachOption(
            icon: CupertinoIcons.camera_fill,
            label: 'Camera',
            onTap: onCamera,
          ),
          _AttachOption(
            icon: CupertinoIcons.photo_on_rectangle,
            label: 'Gallery',
            onTap: onGallery,
          ),
          _AttachOption(
            icon: CupertinoIcons.videocam_fill,
            label: 'Video',
            onTap: onVideo,
          ),
        ],
      ),
    );
  }
}

/// Single attachment option button
class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (!kIsWeb) HapticFeedback.lightImpact();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
