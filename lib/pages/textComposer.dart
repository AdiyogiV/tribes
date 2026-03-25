import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/theme/theme_helper.dart';
import 'package:aurogram/widgets/common/snackBarService.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';

class TextComposer extends StatefulWidget {
  final String space;
  final String? replyTo;
  final bool isProfilePost;

  const TextComposer({
    Key? key,
    required this.space,
    this.replyTo,
    this.isProfilePost = false,
  }) : super(key: key);

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
        middle: Text(widget.replyTo == null ? 'Write Note' : 'Write Reply'),
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
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CupertinoColors.systemGrey4,
                            ),
                          ),
                          child: CupertinoTextField(
                            controller: _contentController,
                            placeholder: widget.replyTo == null
                                ? 'Share your thoughts...'
                                : 'Write your reply...',
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textLightColor,
                              height: 1.4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.all(16),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),

                      // Space feed toggle (only show for replies if user has permission)
                      if (widget.replyTo != null) _buildSpaceFeedSwitch(),

                      SizedBox(height: 16),

                      // Character count and info
                      Row(
                        children: [
                          Text(
                            '${_contentController.text.length}/2000',
                            style: TextStyle(
                              color: _contentController.text.length > 2000
                                  ? CupertinoColors.systemRed
                                  : AppTheme.textSecondaryLightColor,
                              fontSize: 12,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            CupertinoIcons.doc_text,
                            color: AppTheme.primaryColor,
                            size: 16,
                          ),
                          SizedBox(width: 4),
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
    return _contentController.text.trim().isNotEmpty &&
        _contentController.text.length <= 2000 &&
        !_isPosting;
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
      // Create the text post document with space feed option
      String? postId = await _postDbService.createTextPostDocument(
        space: widget.space,
        title: null, // Notes don't need titles
        content: _contentController.text.trim(),
        replyTo: widget.replyTo,
        addToSpaceFeed: addToSpaceFeed, // Pass the user's choice
        isProfilePost: widget.isProfilePost,
      );

      if (postId != null) {
        // Success! Navigate back to feed
        if (mounted) {
          // Pop all the way back to the main feed
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
