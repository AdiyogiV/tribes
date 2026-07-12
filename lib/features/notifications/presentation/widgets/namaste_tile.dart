import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/notifications/presentation/widgets/unified_notification_card.dart';
import 'package:aurogram/features/notifications/presentation/widgets/notification_data_mixin.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class NamasteTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const NamasteTile({this.data, super.key});

  @override
  _NamasteTileState createState() => _NamasteTileState();
}

class _NamasteTileState extends State<NamasteTile>
    with NotificationDataMixin {
  String author = '';
  String date = '';
  String picture = '';
  String authorId = '';
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      authorId = widget.data?['author']?.toString() ?? '';

      // Use mixin helpers for common data fetching (parallel)
      final nameAndAvatar = await (
        fetchUserDisplayName(authorId, widget.data),
        fetchUserAvatar(authorId),
      ).wait;

      author = nameAndAvatar.$1;
      picture = nameAndAvatar.$2 ?? '';
      date = parseNotificationTimestamp(widget.data);
    } catch (e) {
      AppLogger.e('Error fetching namaste notification data',
          category: LogCategory.general, data: {'error': e.toString()});
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
              context.push('/user/${widget.data!['author']}');
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
                          fontSize: AppTheme.babaTextSize,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXxxs),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: AppTheme.babaTextSize,
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
