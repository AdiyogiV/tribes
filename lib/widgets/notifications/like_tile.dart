import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/pages/thread_view.dart';
import 'package:aurogram/widgets/preview_boxes/preview_box.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/notifications/unified_notification_card.dart';

class LikeTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const LikeTile({this.data, super.key});

  @override
  _LikeTileState createState() => _LikeTileState();
}

class _LikeTileState extends State<LikeTile> {
  String author = 'Unknown';
  String likerId = '';
  String space = 'Unknown Space';
  String date = '';
  String leadingURL = '';
  String trailingURL = '';
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Try to fetch data, but show notification even if some data is missing
      // Don't delete notifications - show with fallback data instead

      await Future.wait([
        _fetchUserInfo(),
        _fetchSpaceInfo(),
        _fetchDateInfo(),
        _fetchPostInfo(),
      ]);
    } catch (e) {
      AppLogger.e('Error fetching like notification data',
          category: LogCategory.general, data: {'error': e.toString()});
      // Show notification with fallback data instead of hiding it
      if (author == 'Unknown') author = 'Someone';
      if (space == 'Unknown Space') space = 'A Space';
    } finally {
      if (mounted) {
        setState(() {
          ready = true;
        });
      }
    }
  }

  Future<void> _fetchUserInfo() async {
    if (widget.data?['liker'] != null) {
      likerId = widget.data!['liker'].toString();

      // Use likerName from notification data if available (fast path)
      final notificationLikerName = widget.data?['likerName']?.toString();
      final notificationLikerPic =
          widget.data?['likerDisplayPicture']?.toString();

      if (notificationLikerName != null &&
          notificationLikerName.isNotEmpty &&
          notificationLikerName != 'Someone') {
        author = notificationLikerName;
        leadingURL = notificationLikerPic ?? '';
      } else {
        // Fallback: fetch from user document (legacy notifications or missing data)
        try {
          final userService = locator<UserService>();
          author = await userService.getUserDisplayName(widget.data!['liker']);

          // Get avatar separately
          DocumentSnapshot? user = await DatabaseService()
              .getUser(widget.data!['liker'])
              .timeout(Duration(seconds: 5));
          if (user.exists) {
            leadingURL = user.get('displayPicture')?.toString() ?? '';
          }
        } catch (e) {
          // Error fetching user - getUserDisplayName already handles deleted users correctly
          // Use generic fallback instead of assuming deleted
          author = widget.data?['likerName']?.toString() ?? 'User';
        }
      }
    }
  }

  Future<void> _fetchSpaceInfo() async {
    if (widget.data?['space'] != null) {
      try {
        DocumentSnapshot? spaceDoc = await DatabaseService()
            .getSpace(widget.data!['space'])
            .timeout(Duration(seconds: 5));
        if (spaceDoc.exists) {
          space = spaceDoc.get('name')?.toString() ?? 'A Space';
        }
      } catch (e) {
        // Use fallback
        space = widget.data?['spaceName']?.toString() ?? 'A Gram';
      }
    }
  }

  Future<void> _fetchDateInfo() async {
    if (widget.data?['timestamp'] != null) {
      try {
        date =
            TimeDisplay.getCompactTimestamp(widget.data!['timestamp'].toDate());
      } catch (e) {
        date = 'Recently';
      }
    }
  }

  Future<void> _fetchPostInfo() async {
    if (widget.data?['postId'] != null) {
      try {
        DocumentSnapshot? postDoc = await locator<PostDbService>()
            .getPost(widget.data!['postId'])
            .timeout(Duration(seconds: 5));
        if (postDoc.exists && postDoc.data() != null) {
          final data = postDoc.data() as Map<String, dynamic>;
          trailingURL = data['thumbnail']?.toString() ?? '';
        }
      } catch (e) {
        // Post might be deleted, but we'll still show the notification
        // Use thumbnail from notification data if available
        if (widget.data?['thumbnail'] != null) {
          trailingURL = widget.data!['thumbnail'].toString();
        }
      }
    }
  }

  String get _timestamp {
    if (widget.data?['timestamp'] != null) {
      try {
        return TimeDisplay.getCompactTimestamp(widget.data!['timestamp'].toDate());
      } catch (_) {}
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: SkeletonListItem(height: 70),
      );
    }
    final isRead = widget.data?['read'] == true;
    final spaceSubtitle = (space.isNotEmpty && space != 'Unknown Space') ? space : null;
    return UnifiedNotificationCard(
      isRead: isRead,
      leading: UserAvatar(
        userId: likerId,
        imageUrl: leadingURL,
        size: 40,
        nameInitials: author.isNotEmpty ? author.substring(0, 1) : null,
      ),
      title: '$author liked your post',
      subtitle: spaceSubtitle,
      timestamp: _timestamp,
      trailing: trailingURL.isNotEmpty
          ? Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: PreviewBox(previewUrl: trailingURL),
              ),
            )
          : null,
      onTap: () {
        if (widget.data?['postId'] != null) {
          Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(builder: (context) => ThreadView(postId: widget.data!['postId'])),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Post or space information is unavailable'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.fixed,
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      },
    );
  }
}
