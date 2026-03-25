import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/pages/spaces/spaceScreen.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/space_service.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/previewBoxes/gramPicture.dart';
import 'package:aurogram/widgets/previewBoxes/userPicture.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

class AddedToGroupTile extends StatefulWidget {
  final Map? data;

  const AddedToGroupTile({this.data, Key? key}) : super(key: key);

  @override
  _AddedToGroupTileState createState() => _AddedToGroupTileState();
}

class _AddedToGroupTileState extends State<AddedToGroupTile> {
  final CollectionReference postCollection =
      FirebaseFirestore.instance.collection('posts');
  String inviterName = 'Unknown';
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
      if (widget.data?['inviter'] != null) {
        inviterDoc = await DatabaseService().getUser(widget.data!['inviter']);
        if (inviterDoc != null && inviterDoc!.exists) {
          inviterName = inviterDoc!.get('nickname')?.toString() ?? 'Unknown';
        }
      }

      if (widget.data?['space'] != null) {
        spaceDoc = await SpaceService().getSpace(widget.data!['space']);
        space = spaceDoc?.name ?? 'Unknown Space';
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
      ready = true;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ready
        ? Container(
            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
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
                  padding: EdgeInsets.all(16),
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
                          child: inviterDoc != null && inviterDoc!.exists
                              ? UserPicture(
                                  displayPicture:
                                      inviterDoc!.get('displayPicture'))
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
