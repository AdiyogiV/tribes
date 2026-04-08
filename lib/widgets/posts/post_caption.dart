import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/posts/post_data.dart';

// =============================================================================
// POST CAPTION WIDGET
// =============================================================================

/// Displays the post title/caption below the toolbar for video and image posts.
/// Text and audio posts render their own title inside their player widgets.
class PostCaption extends StatelessWidget {
  final PostData displayData;

  const PostCaption({super.key, required this.displayData});

  @override
  Widget build(BuildContext context) {
    // Only show caption for non-text, non-audio posts that have a title.
    if (displayData.title == null || displayData.title!.isEmpty) {
      return const SizedBox.shrink();
    }
    if (displayData.postType == 'text' || displayData.postType == 'audio') {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (displayData.postType != 'image') const SizedBox(height: AppDimensions.spacingSm),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              displayData.title!,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
