import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/theme/theme_helper.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/features/feed/presentation/widgets/quoted_post_preview.dart';
import 'package:aurogram/services/repost_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class TextComposer extends StatefulWidget {
  final String space;
  final String? replyTo;
  final bool isProfilePost;
  final String? quotedPostId;
  final Map<String, dynamic>? quotedPostData;

  const TextComposer({
    super.key,
    required this.space,
    this.replyTo,
    this.isProfilePost = false,
    this.quotedPostId,
    this.quotedPostData,
  });

  @override
  TextComposerState createState() => TextComposerState();
}

class TextComposerState extends State<TextComposer> {
  final TextEditingController _contentController = TextEditingController();
  final PostDbService _postDbService = locator<PostDbService>();

  bool _isPosting = false;
  bool addToSpaceFeed = true; // Default to true for new posts
  bool canAddToSpaceFeed = false; // Will be set based on permissions
  String? space;

  @override
  void initState() {
    super.initState();
    _initializeSpaceFeedSettings();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// Initialize space feed settings (copied from videoPicker.dart)
  Future<void> _initializeSpaceFeedSettings() async {
    space = widget.space;

    // For new posts (not replies), default to adding to space feed
    if (widget.replyTo == null) {
      addToSpaceFeed = true;
    }

    // Check if user has permission to post to space feed for replies
    if (space != null && widget.replyTo != null) {
      canAddToSpaceFeed =
          await DatabaseService().checkSpaceFeedPostingPermissions(space!);
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.quotedPostId != null
              ? 'Quote'
              : (widget.replyTo == null ? 'Write Note' : 'Write Reply'),
        ),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: _isPosting
            ? const PulsingDots(size: 6)
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isContentValid() ? _handlePost : null,
                child: Text(
                  'Post',
                  style: TextStyle(
                    color: _isContentValid()
                        ? AppTheme.primaryColor
                        : CupertinoColors.inactiveGray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Content field
                      if (widget.quotedPostData != null) ...[
                        QuotedPostPreview(
                            quotedPostData: widget.quotedPostData!),
                        const SizedBox(height: AppDimensions.spacingMd),
                      ],
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            border: Border.all(
                              color: AppTheme.textSecondaryColor
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: CupertinoTextField(
                            controller: _contentController,
                            placeholder: widget.quotedPostId != null
                                ? 'Add your thoughts...'
                                : (widget.replyTo == null
                                    ? 'Share your thoughts...'
                                    : 'Write your reply...'),
                            placeholderStyle: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 16,
                            ),
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textColor,
                              height: 1.4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                            padding: EdgeInsets.all(AppDimensions.paddingLg),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),

                      // Space feed toggle (only show for replies if user has permission)
                      if (widget.replyTo != null) _buildSpaceFeedSwitch(),

                      SizedBox(height: AppDimensions.spacingLg),

                      // Character count and info
                      Row(
                        children: [
                          Text(
                            '${_contentController.text.length}/2000',
                            style: TextStyle(
                              color: _contentController.text.length > 2000
                                  ? CupertinoColors.systemRed
                                  : AppTheme.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            CupertinoIcons.doc_text,
                            color: AppTheme.primaryColor,
                            size: 16,
                          ),
                          SizedBox(width: AppDimensions.spacingXs),
                          Text(
                            'Text Note',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isContentValid() {
    if (_isPosting || _contentController.text.length > 2000) return false;
    if (widget.quotedPostId != null) {
      return true; // quote allows empty commentary
    }
    return _contentController.text.trim().isNotEmpty;
  }

  Future<void> _handlePost() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showCustomSnackBar(
        context,
        message: 'You need to be signed in to post',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }

    if (!_isContentValid()) return;

    setState(() {
      _isPosting = true;
    });

    try {
      if (widget.quotedPostId != null && widget.quotedPostData != null) {
        // Quote post flow
        final targetGramId = widget.space == 'profile' || widget.space.isEmpty
            ? null
            : widget.space;
        await RepostService().createQuotePost(
          quotedPostId: widget.quotedPostId!,
          quotedPostData: widget.quotedPostData!,
          commentary: _contentController.text.trim(),
          targetGramId: targetGramId,
        );
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          showCustomSnackBar(
            context,
            message: 'Quote posted!',
            backgroundColor: AppTheme.successColor,
          );
        }
      } else {
        // Regular text post
        String? postId = await _postDbService.createTextPostDocument(
          space: widget.space,
          title: null,
          content: _contentController.text.trim(),
          replyTo: widget.replyTo,
          addToSpaceFeed: addToSpaceFeed,
          isProfilePost: widget.isProfilePost,
        );

        if (postId != null) {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            showCustomSnackBar(
              context,
              message: widget.replyTo == null
                  ? 'Note posted successfully!'
                  : 'Reply posted successfully!',
              backgroundColor: AppTheme.successColor,
            );
          }
        } else {
          throw Exception('Failed to create post');
        }
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(
          context,
          message: 'Failed to post note. Please try again.',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  /// Builds the space feed toggle switch (copied from videoPicker.dart)
  Widget _buildSpaceFeedSwitch() {
    return canAddToSpaceFeed
        ? Card(
            margin: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(color: AppTheme.primaryLightColor, width: 1),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Row(
                children: [
                  Icon(Icons.feed, color: AppTheme.primaryColor, size: 18),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Text(
                        "Add note to group's feed",
                        style: ThemeHelper.bodyTextStyle,
                      ),
                    ),
                  ),
                  CupertinoSwitch(
                    value: addToSpaceFeed,
                    activeTrackColor: AppTheme.primaryColor,
                    onChanged: (value) {
                      if (mounted) setState(() => addToSpaceFeed = value);
                    },
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();
  }
}
