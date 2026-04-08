import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/features/profile/presentation/pages/social/invites.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/features/spaces/domain/space_service.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram_picture.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/user_picture.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/notifications/presentation/widgets/unified_notification_card.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class InviteTile extends StatefulWidget {
  final Map? data;

  const InviteTile({this.data, super.key});

  @override
  _InviteTileState createState() => _InviteTileState();
}

class _InviteTileState extends State<InviteTile> {
  final CollectionReference postCollection =
      FirebaseFirestore.instance.collection('posts');
  String inviterName = 'Unknown';
  String inviterAvatar = '';
  String space = 'Unknown Space';
  String date = 'Unknown Date';
  bool ready = false;
  DocumentSnapshot? inviterDoc;
  Space? spaceDoc;

  @override
  void initState() {
    super.initState();
    fetchInfo();
  }

  Future<void> fetchInfo() async {
    try {
      // First check if notification contains the data (new notifications)
      final notificationInviterName = widget.data?['inviterName']?.toString();
      final notificationInviterAvatar = widget.data?['inviterAvatar']?.toString();
      final notificationSpaceName = widget.data?['spaceName']?.toString();
      
      if (notificationInviterName != null && notificationInviterName.isNotEmpty && notificationInviterName != 'Someone') {
        // Use data from notification (fast path)
        inviterName = notificationInviterName;
        inviterAvatar = notificationInviterAvatar ?? '';
      } else if (widget.data?['inviter'] != null) {
        // Fallback: fetch from user document (legacy notifications)
        inviterDoc = await DatabaseService().getUser(widget.data!['inviter']);
        if (inviterDoc != null && inviterDoc!.exists) {
          inviterName = inviterDoc!.get('name')?.toString() ?? 'Someone';
          inviterAvatar = inviterDoc!.get('displayPicture')?.toString() ?? '';
        } else {
          inviterName = 'Someone';
        }
      }

      if (notificationSpaceName != null && notificationSpaceName.isNotEmpty) {
        // Use data from notification (fast path)
        space = notificationSpaceName;
      } else if (widget.data?['space'] != null) {
        // Fallback: fetch from space document (legacy notifications)
        spaceDoc = await SpaceService().getSpace(widget.data!['space']);
        space = spaceDoc?.name ?? 'a gram';
      }

      if (widget.data?['timestamp'] != null) {
        date =
            TimeDisplay.getCompactTimestamp(widget.data!['timestamp'].toDate());
      }

      ready = true;
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.e('Error fetching invite info',
          category: LogCategory.general, data: {'error': e.toString()});
      // Set ready to true to show the fallback UI even if an error occurred
      if (inviterName == 'Unknown') inviterName = 'Someone';
      if (space == 'Unknown Space') space = 'a gram';
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
                  Navigator.of(context, rootNavigator: true)
                      .push(CupertinoPageRoute(builder: (context) {
                    return Invites();
                  }));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                          border:
                              Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: inviterAvatar.isNotEmpty
                              ? UserPicture(displayPicture: inviterAvatar)
                              : Container(
                                  color: AppTheme.surfaceColor,
                                  child: Icon(
                                    Icons.person_outline,
                                    color: AppTheme.textSecondaryColor,
                                    size: 20,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$inviterName invited you to join $space',
                              style: TextStyle(
                                fontSize: AppTheme.holyCowTextSize,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingXxxs),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: AppTheme.holyCowTextSize,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingMd),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                              border: Border.all(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(19),
                              child: spaceDoc != null
                                  ? GramPicture(
                                      displayPicture: spaceDoc!.displayPicture)
                                  : Container(
                                      color: AppTheme.surfaceColor,
                                      child: Icon(
                                        Icons.group_outlined,
                                        color: AppTheme.textSecondaryColor,
                                        size: 20,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                          Icon(
                            Icons.chevron_right,
                            color: AppTheme.textSecondaryColor,
                            size: 20,
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
            child: SkeletonListItem(height: 70),
          );
  }
}
