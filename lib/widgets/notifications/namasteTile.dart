import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/pages/tabs/userProfile.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

class NamasteTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const NamasteTile({this.data, Key? key}) : super(key: key);

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
      DocumentSnapshot? user = await DatabaseService()
          .getUser(widget.data!['author'])
          .timeout(Duration(seconds: 5));
      if (user.exists) {
        author = user['name']?.toString() ?? 'Someone';
        picture = user['displayPicture']?.toString() ?? '';
      } else {
        // User might be deleted, but show notification anyway
        author = 'Someone';
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
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: SkeletonListItem(height: 70),
      );
    }

    return Container(
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
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                UserAvatar(
                  userId: authorId,
                  imageUrl: picture,
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
                        '$author greets you with namaste!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        widget.data!['timestamp'] != null
                            ? TimeDisplay.getCompactTimestamp(
                                (widget.data!['timestamp'] as Timestamp)
                                    .toDate())
                            : date,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
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
