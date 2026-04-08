import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/features/profile/presentation/pages/user_profile.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/notifications/presentation/widgets/unified_notification_card.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class NamasteTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const NamasteTile({this.data, super.key});

  @override
  _NamasteTileState createState() => _NamasteTileState();
}

class _NamasteTileState extends State<NamasteTile> {
  final CollectionReference postCollection =
      FirebaseFirestore.instance.collection('posts');
  String author = '';
  String date = '';
  String picture = '';
  String authorId = '';
  bool ready = false;
  bool namaste = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Try to fetch data, but show notification even if user is deleted
      // Don't delete notifications - show with fallback data instead

      await Future.wait([
        _fetchUserInfo(),
        _fetchDateInfo(),
      ]);
    } catch (e) {
      AppLogger.e('Error fetching namaste notification data',
          category: LogCategory.general, data: {'error': e.toString()});
      // Show notification with fallback data instead of hiding it
      if (author.isEmpty) author = 'Someone';
      if (date.isEmpty) date = 'Recently';
    } finally {
      if (mounted) {
        setState(() {
          ready = true;
        });
      }
    }
  }

  Future<void> _fetchUserInfo() async {
    if (widget.data == null || widget.data!['author'] == null) {
      author = 'Someone';
      if (mounted) setState(() => ready = true);
      return;
    }

    try {
      authorId = widget.data!['author'].toString();

      // Use authorName from notification data if available (new notifications)
      final notificationAuthorName = widget.data!['authorName']?.toString();
      final notificationAuthorPic = widget.data!['authorPic']?.toString();

      if (notificationAuthorName != null &&
          notificationAuthorName.isNotEmpty &&
          notificationAuthorName != 'Someone') {
        // Use data from notification (fast path)
        author = notificationAuthorName;
        picture = notificationAuthorPic ?? '';
      } else {
        // Fallback: fetch from user document (legacy notifications)
        try {
          final userService = locator<UserService>();
          author = await userService.getUserDisplayName(widget.data!['author']);

          // Get avatar separately
          DocumentSnapshot? user = await DatabaseService()
              .getUser(widget.data!['author'])
              .timeout(Duration(seconds: 5));
          if (user.exists) {
            picture = user['displayPicture']?.toString() ?? '';
          }
        } catch (e) {
          // Error fetching user - getUserDisplayName already handles deleted users correctly
          // Keep default or use generic fallback
          if (author.isEmpty) {
            author = 'User';
          }
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.e('Error fetching user info',
          category: LogCategory.general, data: {'error': e.toString()});
      // Use fallback - notification will still show
      author = 'Someone';
      ready = true;
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchDateInfo() async {
    if (widget.data == null || widget.data!['timestamp'] == null) {
      if (mounted) setState(() => date = 'Unknown date');
      return;
    }

    try {
      if (widget.data!['timestamp'] is Timestamp) {
        date = TimeDisplay.getCompactTimestamp(
            (widget.data!['timestamp'] as Timestamp).toDate());
      } else {
        date = 'Unknown date';
      }

      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.e('Error fetching date info',
          category: LogCategory.general, data: {'error': e.toString()});
      ready = true;
      if (mounted) setState(() => date = 'Unknown date');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ready || widget.data == null || widget.data!['author'] == null) {
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
            if (widget.data!['author'] != null) {
              Navigator.of(context, rootNavigator: true)
                  .push(CupertinoPageRoute(builder: (context) {
                return UserProfilePage(
                  uid: widget.data!['author'],
                );
              }));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
            child: Row(
              children: [
                UserAvatar(
                  userId: authorId,
                  imageUrl: picture,
                  size: 40,
                  nameInitials:
                      author.isNotEmpty ? author.substring(0, 1) : null,
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$author greets you with namaste!',
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXxxs),
                      Text(
                        widget.data!['timestamp'] != null
                            ? TimeDisplay.getCompactTimestamp(
                                (widget.data!['timestamp'] as Timestamp)
                                    .toDate())
                            : date,
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Center(
                  child: Image.asset(
                    'assets/icons/namaste.png',
                    width: 60,
                    height: 60,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
