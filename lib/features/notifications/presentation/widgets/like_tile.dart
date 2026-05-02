import 'package:flutter/material.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/preview_box.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/notifications/presentation/widgets/unified_notification_card.dart';
import 'package:aurogram/features/notifications/presentation/widgets/notification_data_mixin.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class LikeTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const LikeTile({this.data, super.key});

  @override
  _LikeTileState createState() => _LikeTileState();
}

class _LikeTileState extends State<LikeTile> with NotificationDataMixin {
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
      likerId = widget.data?['liker']?.toString() ?? '';

      await Future.wait([
        _fetchUserInfo(),
        _fetchSpaceAndDateInfo(),
        _fetchPostInfo(),
      ]);
    } catch (e) {
      AppLogger.e('Error fetching like notification data',
          category: LogCategory.general, data: {'error': e.toString()});
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
    if (likerId.isNotEmpty) {
      // Use mixin helpers — handles fast-path from notification data + Firestore fallback
      author = await fetchUserDisplayName(likerId, widget.data);
      leadingURL = (await fetchUserAvatar(likerId)) ?? '';
    }
  }

  Future<void> _fetchSpaceAndDateInfo() async {
    final spaceId = widget.data?['space']?.toString();
    space = await fetchSpaceName(spaceId,
        fallbackName: widget.data?['spaceName']?.toString() ?? 'A Gram');
    date = parseNotificationTimestamp(widget.data);
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
        // Post might be deleted, use thumbnail from notification data if available
        if (widget.data?['thumbnail'] != null) {
          trailingURL = widget.data!['thumbnail'].toString();
        }
      }
    }
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
      timestamp: date,
      trailing: trailingURL.isNotEmpty
          ? Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
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
          context.push('/thread/${widget.data!['postId']}');
        } else {
          showCustomSnackBar(context, message: 'Post or space information is unavailable', duration: const Duration(seconds: 2), backgroundColor: AppTheme.errorColor);
        }
      },
    );
  }
}
