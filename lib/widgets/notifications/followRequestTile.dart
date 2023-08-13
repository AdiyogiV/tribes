
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tribes/pages/userProfile.dart';
import 'package:tribes/services/databaseService.dart';
import 'package:tribes/widgets/previewBoxes/userPreviewBox.dart';

class FollowRequestTile extends StatefulWidget {
  final String? space;
  final String? uid;
  Function? onRefresh;
  FollowRequestTile({this.space, this.uid, this.onRefresh, Key? key})
      : super(key: key);
  @override
  _FollowRequestTileState createState() => _FollowRequestTileState();
}

class _FollowRequestTileState extends State<FollowRequestTile> {
  String name = '';
  String username = '';
  String? displayPicture;
  final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('users');

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    DocumentSnapshot userdocuments =
        await DatabaseService().getUser(widget.uid!);
    name = userdocuments['name'];
    username = userdocuments['nickname'];
    displayPicture = userdocuments['displayPicture'];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      child: Material(
        borderRadius: BorderRadius.circular(10),
        elevation: 5,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context)
                      .push(CupertinoPageRoute(builder: (context) {
                    return UserProfilePage(
                      uid: widget.uid,
                    );
                  }));
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: UserPreview(
                    uid: widget.uid,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context)
                      .push(CupertinoPageRoute(builder: (context) {
                    return UserProfilePage(
                      uid: widget.uid,
                    );
                  }));
                },
                child: Column(
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                            color: Colors.black87),
                        textAlign: TextAlign.start),
                    Text("$username",
                        style: TextStyle(
                            fontWeight: FontWeight.w300,
                            fontSize: 14,
                            color: CupertinoTheme.of(context).primaryColor),
                        textAlign: TextAlign.start),
                  ],
                ),
              ),
            ),
            Container(
              height: 50,
              width: 10,
            ),
            Container(
              color: Colors.black45,
              height: 50,
              width: 0.5,
            ),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () async {
                  await DatabaseService()
                      .rejectSpaceMember(widget.space!, widget.uid!);
                  widget.onRefresh!();
                },
                child: Icon(
                  Icons.cancel_rounded,
                  color: CupertinoColors.destructiveRed,
                  size: 30,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () async {
                  await DatabaseService()
                      .approveSpaceMember(widget.space!, widget.uid!);
                  widget.onRefresh!();
                },
                child: Icon(
                  Icons.check_circle,
                  color: CupertinoColors.activeGreen,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
