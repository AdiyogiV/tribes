import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/pages/spaces/spaceScreen.dart';
import 'package:aurogram/widgets/previewBoxes/previewBox.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

class LikeTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const LikeTile({this.data, Key? key}) : super(key: key);

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
      try {
        DocumentSnapshot? user = await DatabaseService()
            .getUser(widget.data!['liker'])
            .timeout(Duration(seconds: 5));
        if (user.exists) {
          author = user.get('name')?.toString() ?? 'Someone';
          leadingURL = user.get('displayPicture')?.toString() ?? '';
        }
      } catch (e) {
        // Use fallback - notification will still show
        author = widget.data?['likerName']?.toString() ?? 'Someone';
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
        date = TimeDisplay.getCompactTimestamp(
            widget.data!['timestamp'].toDate());
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
                  if (widget.data?['postId'] != null &&
                      widget.data?['space'] != null) {
                    Navigator.of(context, rootNavigator: true)
                        .push(CupertinoPageRoute(builder: (context) {
                      return SpaceScreen(
                        postId: widget.data!['postId'],
                        rid: widget.data!['space'],
                      );
                    }));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Post or space information is unavailable'),
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
                      UserAvatar(
                        userId: likerId,
                        imageUrl: leadingURL,
                        size: 40,
                        nameInitials:
                            author.isNotEmpty ? author.substring(0, 1) : null,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$author liked your post',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[900],
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Row(
                              children: [
                                if (space.isNotEmpty &&
                                    space != 'Unknown Space') ...[
                                  Flexible(
                                    child: Text(
                                      space,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  Text(
                                    ' • ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                                Flexible(
                                  child: Text(
                                    widget.data?['timestamp'] != null
                                        ? TimeDisplay.getCompactTimestamp(
                                            widget.data!['timestamp'].toDate())
                                        : date,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      if (trailingURL.isNotEmpty)
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.grey[300]!, width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: PreviewBox(previewUrl: trailingURL),
                          ),
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
