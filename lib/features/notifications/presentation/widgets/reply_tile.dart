import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/shared/services/database_service.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/notifications/presentation/widgets/unified_notification_card.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/preview_box.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class ReplyTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const ReplyTile({this.data, super.key});

  @override
  _ReplyTileState createState() => _ReplyTileState();
}

class _ReplyTileState extends State<ReplyTile> {
  String author = '';
  String authorId = '';
  String authorDp = '';
  String space = '';
  String date = '';
  String replyThumbnail = '';
  String originalThumbnail = '';
  String originalPostType = 'video';
  String originalContent = '';
  String originalAuthorId = '';
  String replyPostType = 'video';
  String replyContent = '';
  bool ready = false;
  DocumentSnapshot? replyToPost;
  DocumentSnapshot? repliedPost;

  @override
  void initState() {
    super.initState();
    fetchInfo();
  }

  Future<void> fetchInfo() async {
    try {
      // Try to fetch referenced posts, but don't delete notification if they're missing
      // Show notification with fallback data instead

      if (widget.data?['replyToPost'] != null) {
        try {
          replyToPost = await locator<PostDbService>()
              .getPost(widget.data!['replyToPost'])
              .timeout(Duration(seconds: 5));
        } catch (e) {
          // Log but continue - we'll show notification with fallback data
          AppLogger.w('Could not fetch original post for reply notification',
              category: LogCategory.network, data: {'error': e.toString()});
        }
      }

      if (widget.data?['postId'] != null) {
        try {
          repliedPost = await locator<PostDbService>()
              .getPost(widget.data!['postId'])
              .timeout(Duration(seconds: 5));
        } catch (e) {
          // Log but continue - we'll show notification with fallback data
          AppLogger.w('Could not fetch reply post for notification',
              category: LogCategory.network, data: {'error': e.toString()});
        }
      }

      // Fetch user and space info - use fallback values if data is missing
      // First check if notification contains author info (new notifications)
      final notificationAuthorName = widget.data?['authorName']?.toString();
      final notificationAuthorPic = widget.data?['authorPic']?.toString();

      if (notificationAuthorName != null &&
          notificationAuthorName.isNotEmpty &&
          notificationAuthorName != 'Someone') {
        // Use data from notification (fast path for new notifications)
        authorId = widget.data!['author']?.toString() ?? '';
        author = notificationAuthorName;
        authorDp = notificationAuthorPic ?? '';
      } else if (repliedPost != null && repliedPost!.exists) {
        if (repliedPost!['author'] != null) {
          authorId = repliedPost!['author'].toString();
          try {
            final userService = locator<UserService>();
            author =
                await userService.getUserDisplayName(repliedPost!['author']);

            // Get avatar separately
            DocumentSnapshot? user = await locator<UserRepository>()
                .getUser(repliedPost!['author'])
                .timeout(Duration(seconds: 5));
            if (user.exists) {
              authorDp = user.get('displayPicture')?.toString() ?? '';
            }
          } catch (e) {
            // Error fetching user - getUserDisplayName already handles deleted users correctly
            // Use generic fallback instead of assuming deleted
            if (author.isEmpty) {
              author = 'User';
            }
          }
        } else if (widget.data?['author'] != null) {
          // Fallback to notification data
          authorId = widget.data!['author'].toString();
          try {
            final userService = locator<UserService>();
            author = await userService.getUserDisplayName(authorId);

            // Get avatar separately
            DocumentSnapshot? user = await locator<UserRepository>()
                .getUser(authorId)
                .timeout(Duration(seconds: 5));
            if (user.exists) {
              authorDp = user.get('displayPicture')?.toString() ?? '';
            }
          } catch (e) {
            // Error fetching user - getUserDisplayName already handles deleted users correctly
            // Use generic fallback instead of assuming deleted
            if (author.isEmpty) {
              author = 'User';
            }
          }
        }

        if (repliedPost!['space'] != null) {
          try {
            DocumentSnapshot? spaceDoc = await DatabaseService()
                .getSpace(repliedPost!['space'])
                .timeout(Duration(seconds: 5));
            if (spaceDoc.exists) {
              space = spaceDoc.get('name')?.toString() ?? 'Unknown Space';
            }
          } catch (e) {
            // Use fallback
            space = widget.data?['space'] != null ? 'A Gram' : 'Unknown Gram';
          }
        } else if (widget.data?['space'] != null) {
          try {
            DocumentSnapshot? spaceDoc = await DatabaseService()
                .getSpace(widget.data!['space'])
                .timeout(Duration(seconds: 5));
            if (spaceDoc.exists) {
              space = spaceDoc.get('name')?.toString() ?? 'A Space';
            }
          } catch (e) {
            space = 'A Space';
          }
        }

        final replyData = repliedPost!.data() as Map<String, dynamic>?;
        if (replyData?['timestamp'] != null) {
          DateTime timestamp = replyData!['timestamp'].toDate();
          date = TimeDisplay.getCompactTimestamp(timestamp);
        }

        replyThumbnail = replyData?['thumbnail'] as String? ?? '';
        replyPostType = replyData?['postType'] as String? ?? 'video';
        replyContent = replyData?['content'] as String? ?? '';
      } else {
        // Fallback: use notification data directly
        if (widget.data?['author'] != null) {
          authorId = widget.data!['author'].toString();
          try {
            DocumentSnapshot? user = await locator<UserRepository>()
                .getUser(authorId)
                .timeout(Duration(seconds: 5));
            if (user.exists) {
              author = user.get('name')?.toString() ?? 'Someone';
              authorDp = user.get('displayPicture')?.toString() ?? '';
            }
          } catch (e) {
            author = 'Someone';
          }
        }

        if (widget.data?['timestamp'] != null) {
          try {
            DateTime timestamp = widget.data!['timestamp'].toDate();
            date = TimeDisplay.getCompactTimestamp(timestamp);
          } catch (e) {
            date = 'Recently';
          }
        }

        if (widget.data?['thumbnail'] != null) {
          replyThumbnail = widget.data!['thumbnail'].toString();
        }
      }

      if (replyToPost != null && replyToPost!.exists) {
        final originalData = replyToPost!.data() as Map<String, dynamic>?;
        originalThumbnail = originalData?['thumbnail'] as String? ?? '';
        originalPostType = originalData?['postType'] as String? ?? 'video';
        originalContent = originalData?['content'] as String? ?? '';
        originalAuthorId = originalData?['author'] as String? ?? '';
      }

      // Always show the notification, even if some data is missing
      ready = true;
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.e('Error fetching reply info',
          category: LogCategory.general,
          data: {
            'error': e.toString(),
            'postId': widget.data?['postId'],
            'replyId': widget.data?['replyId']
          });
      // Show notification with fallback data instead of hiding it
      if (author.isEmpty) author = 'Someone';
      if (space.isEmpty) space = 'A Space';
      if (date.isEmpty) date = 'Recently';
      ready = true;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = widget.data?['read'] == true;
    return ready
        ? Container(
            decoration: notificationTileDecoration(isRead: isRead),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  final threadRootId =
                      widget.data?['replyToPost'] ?? widget.data?['postId'];
                  if (threadRootId != null) {
                    context.push('${RouteNames.threadView}/$threadRootId');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          UserAvatar(
                            userId: authorId,
                            imageUrl: authorDp,
                            size: 40,
                            nameInitials: author.isNotEmpty
                                ? author.substring(0, 1)
                                : null,
                          ),
                          SizedBox(width: AppDimensions.spacingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$author replied to your post',
                                  style: TextStyle(
                                    fontSize: AppTheme.babaTextSize,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textColor,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: AppDimensions.spacingXxxs),
                                Row(
                                  children: [
                                    if (space.isNotEmpty) ...[
                                      Text(
                                        space,
                                        style: TextStyle(
                                          fontSize: AppTheme.babaTextSize,
                                          color: AppTheme.textSecondaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        ' • ',
                                        style: TextStyle(
                                          fontSize: AppTheme.babaTextSize,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ],
                                    Text(
                                      repliedPost?['timestamp'] != null
                                          ? TimeDisplay.getCompactTimestamp(
                                              repliedPost!['timestamp']
                                                  .toDate())
                                          : date,
                                      style: TextStyle(
                                        fontSize: AppTheme.babaTextSize,
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(
                          height: 32), // Increased padding for banner space

                      // Post previews with hanging tab banners
                      Row(
                        children: [
                          // Original post section with hanging tab
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Original post preview
                                GestureDetector(
                                  onTap: () {
                                    if (widget.data?['replyToPost'] != null) {
                                      context.push('${RouteNames.threadView}/${widget.data!['replyToPost']}');
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                      border: Border.all(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.04),
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                      child: AspectRatio(
                                        aspectRatio: 1.0,
                                        child: _buildOriginalPreview(),
                                      ),
                                    ),
                                  ),
                                ),
                                // Hanging YOUR POST tab
                                Positioned(
                                  top: -20,
                                  right: 8,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceColor,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        topRight: Radius.circular(8),
                                        bottomLeft: Radius.circular(4),
                                        bottomRight: Radius.circular(4),
                                      ),
                                      border: Border.all(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 0.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.06),
                                          blurRadius: 2,
                                          offset: const Offset(0, -1),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'YOUR POST',
                                      style: TextStyle(
                                        fontSize: AppTheme.babaTextSize,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondaryColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: AppDimensions.spacingLg),

                          // Arrow
                          Column(
                            children: [
                              SizedBox(height: AppDimensions.spacingXl),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                      color: AppTheme.surfaceColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.chevron_right,
                                      size: 16,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                              ),
                            ],
                          ),

                          SizedBox(width: AppDimensions.spacingLg),

                          // Reply post section with hanging tab
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Reply post preview
                                GestureDetector(
                                  onTap: () {
                                    final threadRootId =
                                        widget.data?['replyToPost'] ??
                                            widget.data?['postId'];
                                    if (threadRootId != null) {
                                      context.push('${RouteNames.threadView}/$threadRootId');
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                      border: Border.all(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.3),
                                          width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.1),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                      child: AspectRatio(
                                        aspectRatio: 1.0,
                                        child: _buildReplyPreview(),
                                      ),
                                    ),
                                  ),
                                ),
                                // Hanging THEIR REPLY tab
                                Positioned(
                                  top: -20,
                                  right: 8,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.primaryColor,
                                          AppTheme.primaryColor
                                              .withValues(alpha: 0.8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        topRight: Radius.circular(8),
                                        bottomLeft: Radius.circular(4),
                                        bottomRight: Radius.circular(4),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.2),
                                          blurRadius: 4,
                                          offset: Offset(0, -1),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'THEIR REPLY',
                                      style: TextStyle(
                                        fontSize: AppTheme.babaTextSize,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingXs, horizontal: AppDimensions.paddingLg),
            child: SkeletonListItem(height: 80),
          );
  }

  Widget _buildOriginalPreview() {
    return PreviewBox(
      previewUrl: originalThumbnail,
      content: originalContent,
      postType: originalPostType,
      showPlayIcon: originalPostType != 'text',
      showNoteIcon: false,
      limitTextPreview: false,
    );
  }

  Widget _buildReplyPreview() {
    return PreviewBox(
      previewUrl: replyThumbnail,
      content: replyContent,
      postType: replyPostType,
      showPlayIcon: replyPostType != 'text',
      showNoteIcon: false,
      limitTextPreview: false,
    );
  }
}
