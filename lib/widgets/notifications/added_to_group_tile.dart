import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/pages/spaces/space_screen.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/space_service.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/notifications/unified_notification_card.dart';
import 'package:aurogram/widgets/preview_boxes/gram_picture.dart';
import 'package:aurogram/widgets/preview_boxes/user_picture.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

class AddedToGroupTile extends StatefulWidget {
  final Map? data;

  const AddedToGroupTile({this.data, super.key});

  @override
  _AddedToGroupTileState createState() => _AddedToGroupTileState();
}

class _AddedToGroupTileState extends State<AddedToGroupTile> {
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
      AppLogger.e('Error fetching notification info',
          category: LogCategory.general, data: {'error': e.toString()});
      // Error has occurred, but we'll still set ready to true to show the fallback UI
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
                  if (spaceDoc != null && widget.data?['space'] != null) {
                    Navigator.of(context, rootNavigator: true)
                        .push(CupertinoPageRoute(builder: (context) {
                      return SpaceScreen(
                        rid: widget.data!['space'],
                      );
                    }));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gram information is unavailable'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.fixed,
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.grey[300]!, width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: inviterAvatar.isNotEmpty
                              ? UserPicture(displayPicture: inviterAvatar)
                              : Container(
                                  color: Colors.grey[100],
                                  child: Icon(
                                    Icons.person_outline,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$inviterName added you to $space',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[900],
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.grey[300]!, width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(19),
                              child: spaceDoc != null
                                  ? GramPicture(
                                      displayPicture: spaceDoc!.displayPicture)
                                  : Container(
                                      color: Colors.grey[100],
                                      child: Icon(
                                        Icons.group_outlined,
                                        color: Colors.grey[400],
                                        size: 20,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
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
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            child: SkeletonListItem(height: 70),
          );
  }
}
