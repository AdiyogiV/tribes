import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:aurogram/pages/creation/text_composer.dart';
import 'package:aurogram/pages/creation/video_picker.dart';
import 'package:aurogram/pages/creation/audio_composer.dart';
import 'package:aurogram/pages/creation/image_composer.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Helper utility for showing media type selection (Video vs Note)
/// Uses a custom bottom modal with beautiful UI and smooth animations
class MediaTypeSelector {
  /// Shows a custom bottom modal to let user choose between Video or Note
  ///
  /// [context] - BuildContext for showing the modal
  /// [space] - The space ID where the post/reply will be created (or 'profile' for profile posts)
  /// [replyTo] - Optional post ID if this is a reply (null for new posts)
  /// [isProfilePost] - Whether this is a profile post (posted to user's profile, not a space)
  static void showMediaTypeSelection({
    required BuildContext context,
    required String space,
    String? replyTo,
    bool isProfilePost = false,
  }) {
    AppBottomSheet.show<void>(
      context,
      child: _MediaTypeSelectionModal(
        space: space,
        replyTo: replyTo,
        isProfilePost: isProfilePost,
      ),
    );
  }
}

/// Custom bottom modal widget with beautiful design
class _MediaTypeSelectionModal extends StatelessWidget {
  final String space;
  final String? replyTo;
  final bool isProfilePost;

  const _MediaTypeSelectionModal({
    required this.space,
    this.replyTo,
    this.isProfilePost = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor;
    final textColor = isDark ? Colors.white : AppTheme.textLightColor;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(bottom: 16),
                height: 4,
                width: 36,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Text(
                replyTo == null ? 'Add post' : 'Add reply',
                style: TextStyle(
                  fontSize: 15,
                  color: textColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(height: AppDimensions.spacingXl),

              // Options in a single row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMinimalOption(
                    context: context,
                    icon: CupertinoIcons.videocam_fill,
                    label: 'Video',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => VideoPicker(
                            sourceItem: 0,
                            space: space,
                            replyTo: replyTo,
                            isProfilePost: isProfilePost,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildMinimalOption(
                    context: context,
                    icon: CupertinoIcons.camera_fill,
                    label: 'Photo',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ImageComposer(
                            sourceItem: 0,
                            space: space,
                            replyTo: replyTo,
                            isProfilePost: isProfilePost,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildMinimalOption(
                    context: context,
                    icon: CupertinoIcons.photo_fill_on_rectangle_fill,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.of(context).pop();
                      _showGalleryPicker(context);
                    },
                  ),
                  _buildMinimalOption(
                    context: context,
                    icon: CupertinoIcons.mic_fill,
                    label: 'Audio',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => AudioComposer(
                            space: space,
                            replyTo: replyTo,
                            isProfilePost: isProfilePost,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildMinimalOption(
                    context: context,
                    icon: CupertinoIcons.text_bubble_fill,
                    label: 'Text',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => TextComposer(
                            space: space,
                            replyTo: replyTo,
                            isProfilePost: isProfilePost,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGalleryPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Choose from Gallery'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => ImageComposer(
                    sourceItem: 1,
                    space: space,
                    replyTo: replyTo,
                    isProfilePost: isProfilePost,
                  ),
                ),
              );
            },
            child: Text('Image'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => VideoPicker(
                    sourceItem: 1,
                    space: space,
                    replyTo: replyTo,
                    isProfilePost: isProfilePost,
                  ),
                ),
              );
            },
            child: Text('Video'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          isDestructiveAction: true,
          child: Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildMinimalOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.textLightColor;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color:
                  AppTheme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 26,
            ),
          ),
          SizedBox(height: AppDimensions.spacingSmMd),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
