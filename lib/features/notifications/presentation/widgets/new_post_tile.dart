import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/shared/services/database_service.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram_picture.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/preview_box.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/notifications/presentation/widgets/unified_notification_card.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class NewPostTile extends StatefulWidget {
  final Map? data;

  const NewPostTile({this.data, super.key});

  @override
  _NewPostTileState createState() => _NewPostTileState();
}

class _NewPostTileState extends State<NewPostTile> {
  String author = 'Unknown Author';
  String authorId = '';
  String authorDp = '';
  String space = 'Unknown Space';
  String date = 'Unknown Date';
  bool ready = false;
  DocumentSnapshot? postDoc;
  DocumentSnapshot? spaceDoc;
  String postThumbnail = '';
  String spacePicture = '';
  String postType = 'video'; // Default to video for backward compatibility
  String postContent = ''; // Content for text posts

  @override
  void initState() {
    super.initState();
    fetchInfo();
  }

  Future<void> fetchInfo() async {
    try {
      // Try to fetch referenced data, but show notification even if some is missing
      // Don't delete notifications - show with fallback data instead

      // Try to fetch post (optional - notification will show even if post is deleted)
      if (widget.data?['postId'] != null) {
        try {
          postDoc = await locator<PostDbService>()
              .getPost(widget.data!['postId'])
              .timeout(Duration(seconds: 5));
        } catch (e) {
          // Log but continue - we'll show notification with fallback data
          AppLogger.w('Could not fetch post for notification',
              category: LogCategory.network, data: {'error': e.toString()});
        }
      }

      // Try to fetch space (optional - notification will show even if space is deleted)
      if (widget.data?['space'] != null) {
        try {
          spaceDoc = await DatabaseService()
              .getSpace(widget.data!['space'])
              .timeout(Duration(seconds: 5));
        } catch (e) {
          // Log but continue - we'll show notification with fallback data
          AppLogger.w('Could not fetch space for notification',
              category: LogCategory.network, data: {'error': e.toString()});
        }
      }

      // Fetch user info with fallback - first check notification data (new notifications)
      if (widget.data?['author'] != null) {
        authorId = widget.data!['author'].toString();

        // Use authorName from notification data if available (fast path)
        final notificationAuthorName = widget.data?['authorName']?.toString();
        final notificationAuthorPic = widget.data?['authorPic']?.toString();

        if (notificationAuthorName != null &&
            notificationAuthorName.isNotEmpty &&
            notificationAuthorName != 'Someone') {
          author = notificationAuthorName;
          authorDp = notificationAuthorPic ?? '';
        } else {
          // Fallback: fetch from user document (legacy notifications)
          try {
            final userService = locator<UserService>();
            author =
                await userService.getUserDisplayName(widget.data!['author']);

            // Get avatar separately
            DocumentSnapshot? user = await locator<UserRepository>()
                .getUser(widget.data!['author'])
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
      }

      // Use space info from fetched doc or fallback
      if (spaceDoc != null && spaceDoc!.exists) {
        space = spaceDoc!.get('name')?.toString() ?? 'A Space';
        spacePicture = spaceDoc!.get('displayPicture')?.toString() ?? '';
      } else {
        // Fallback to notification data or default
        space = widget.data?['spaceName']?.toString() ?? 'A Gram';
      }

      // Fetch timestamp
      if (widget.data?['timestamp'] != null) {
        try {
          date = TimeDisplay.getCompactTimestamp(
              widget.data!['timestamp'].toDate());
        } catch (e) {
          date = 'Recently';
        }
      }

      // Use post info from fetched doc or fallback to notification data
      if (postDoc != null && postDoc!.exists) {
        final data = postDoc!.data() as Map<String, dynamic>?;
        postThumbnail = data?['thumbnail']?.toString() ?? '';
        postType = data?['postType']?.toString() ?? 'video';
        postContent = data?['content']?.toString() ?? '';
      } else {
        // Fallback to notification data
        if (widget.data?['thumbnail'] != null) {
          postThumbnail = widget.data!['thumbnail'].toString();
        }
      }

      ready = true;
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.e('Error fetching post info',
          category: LogCategory.general, data: {'error': e.toString()});
      // Show notification with fallback data instead of hiding it
      if (author.isEmpty || author == 'Unknown Author') author = 'Someone';
      if (space.isEmpty || space == 'Unknown Space') space = 'A Space';
      if (date.isEmpty || date == 'Unknown Date') date = 'Recently';
      ready = true;
      if (mounted) setState(() {});
    }
  }

  Widget _buildPreview() {
    return PreviewBox(
      previewUrl: postThumbnail,
      content: postContent,
      postType: postType,
      showPlayIcon: postType != 'text',
      showNoteIcon: false,
      limitTextPreview: false,
    );
  }

  Widget _buildSpacePlaceholder() {
    return Container(
      color: AppTheme.surfaceColor,
      child: Icon(
        Icons.group_outlined,
        color: AppTheme.textSecondaryColor,
        size: 40,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingXs, horizontal: AppDimensions.paddingLg),
        child: SkeletonListItem(height: 70),
      );
    }

    final isRead = widget.data?['read'] == true;
    return Container(
      decoration: notificationTileDecoration(isRead: isRead),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (widget.data?['postId'] != null) {
              context.push('/thread/${widget.data!['postId']}');
            } else {
              showCustomSnackBar(context, message: 'Post information is unavailable', duration: const Duration(seconds: 2), backgroundColor: AppTheme.errorColor);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with user info
                Row(
                  children: [
                    UserAvatar(
                      userId: authorId,
                      imageUrl: authorDp,
                      size: 40,
                      nameInitials:
                          author.isNotEmpty ? author.substring(0, 1) : null,
                    ),
                    SizedBox(width: AppDimensions.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$author added a new post',
                            style: TextStyle(
                              fontSize: AppTheme.babaTextSize,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: AppDimensions.spacingXxxs),
                          Row(
                            children: [
                              if (space.isNotEmpty &&
                                  space != 'Unknown Space') ...[
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
                                date,
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

                SizedBox(height: AppDimensions.spacingSection), // Increased padding for banner space

                // Space and Post thumbnails with hanging tab banners
                Row(
                  children: [
                    // Space section with hanging tab
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(15),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Space preview
                            GestureDetector(
                              onTap: () {
                                if (widget.data?['space'] != null) {
                                  context.push('/space/${widget.data!['space']}');
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                  border: Border.all(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                  child: AspectRatio(
                                    aspectRatio: 1.0,
                                    child: spacePicture.isNotEmpty
                                        ? GramPicture(
                                            displayPicture: spacePicture)
                                        : _buildSpacePlaceholder(),
                                  ),
                                ),
                              ),
                            ),
                            // Hanging GROUP tab
                            Positioned(
                              top: -20,
                              right: 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                    bottomLeft: Radius.circular(4),
                                    bottomRight: Radius.circular(4),
                                  ),
                                  border: Border.all(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 0.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 2,
                                      offset: Offset(0, -1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'GROUP',
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
                    // New Post section with hanging tab
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Post preview
                          GestureDetector(
                            onTap: () {
                              if (widget.data?['postId'] != null) {
                                context.push('/thread/${widget.data!['postId']}');
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.3),
                                    width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: AspectRatio(
                                  aspectRatio: 1.0,
                                  child: _buildPreview(),
                                ),
                              ),
                            ),
                          ),
                          // Hanging NEW POST tab
                          Positioned(
                            top: -20,
                            right: 8,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green,
                                    Colors.green.withValues(alpha: 0.8),
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
                                    color: Colors.green.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: Offset(0, -1),
                                  ),
                                ],
                              ),
                              child: Text(
                                'NEW POST',
                                style: TextStyle(
                                  fontSize: AppTheme.babaTextSize,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.cardColor,
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
    );
  }
}
