import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/pages/requests.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/space_service.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/notifications/unified_notification_card.dart';
import 'package:aurogram/widgets/preview_boxes/gram_picture.dart';
import 'package:aurogram/widgets/preview_boxes/user_picture.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

class RequestTile extends StatefulWidget {
  final Map? data;

  const RequestTile({this.data, super.key});

  @override
  _RequestTileState createState() => _RequestTileState();
}

class _RequestTileState extends State<RequestTile> {
  final CollectionReference postCollection =
      FirebaseFirestore.instance.collection('posts');
  String requestorName = 'Unknown';
  String requestorAvatar = '';
  String space = 'Unknown Space';
  String date = 'Unknown Date';
  bool ready = false;
  DocumentSnapshot? requestorDoc;
  Space? spaceDoc;

  @override
  void initState() {
    super.initState();
    fetchInfo();
  }

  Future<void> fetchInfo() async {
    try {
      await Future.wait([
        _fetchRequestorInfo(),
        _fetchSpaceInfo(),
        _fetchDateInfo(),
      ]);

      ready = true;
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.e('Error fetching request info',
          category: LogCategory.general, data: {'error': e.toString()});
      ready = true;
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchRequestorInfo() async {
    // First check if notification contains the data (new notifications)
    final notificationRequestorName = widget.data?['requestorName']?.toString();
    final notificationRequestorAvatar = widget.data?['requestorAvatar']?.toString();
    
    if (notificationRequestorName != null && notificationRequestorName.isNotEmpty && notificationRequestorName != 'Someone') {
      // Use data from notification (fast path)
      requestorName = notificationRequestorName;
      requestorAvatar = notificationRequestorAvatar ?? '';
    } else if (widget.data?['requestor'] != null) {
      // Fallback: fetch from user document (legacy notifications)
      requestorDoc = await DatabaseService().getUser(widget.data!['requestor']);
      if (requestorDoc != null && requestorDoc!.exists) {
        requestorName = requestorDoc!.get('name')?.toString() ?? 'Someone';
        requestorAvatar = requestorDoc!.get('displayPicture')?.toString() ?? '';
      } else {
        requestorName = 'Someone';
      }
    }
  }

  Future<void> _fetchSpaceInfo() async {
    // First check if notification contains the data (new notifications)
    final notificationSpaceName = widget.data?['spaceName']?.toString();
    
    if (notificationSpaceName != null && notificationSpaceName.isNotEmpty) {
      // Use data from notification (fast path)
      space = notificationSpaceName;
    } else if (widget.data?['space'] != null) {
      // Fallback: fetch from space document (legacy notifications)
      spaceDoc = await SpaceService().getSpace(widget.data!['space']);
      space = spaceDoc?.name ?? 'a gram';
    }
  }

  Future<void> _fetchDateInfo() async {
    if (widget.data?['timestamp'] != null) {
      date =
          TimeDisplay.getCompactTimestamp(widget.data!['timestamp'].toDate());
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
                  if (widget.data?['space'] != null) {
                    Navigator.of(context, rootNavigator: true)
                        .push(CupertinoPageRoute(builder: (context) {
                      return Requests(space: widget.data!['space']);
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
                              Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: requestorAvatar.isNotEmpty
                              ? UserPicture(displayPicture: requestorAvatar)
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
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$requestorName requested to join $space',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor,
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondaryColor,
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
                                  color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(19),
                              child: spaceDoc != null
                                  ? GramPicture(
                                      displayPicture:
                                          spaceDoc!.displayPicture ?? '')
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
                          SizedBox(width: 8),
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
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            child: SkeletonListItem(height: 70),
          );
  }
}
