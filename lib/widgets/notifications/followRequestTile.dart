import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:yantra/pages/theatre.dart';
import 'package:yantra/pages/userProfile.dart';
import 'package:yantra/services/databaseService.dart';
import 'package:yantra/widgets/previewBoxes/userPreviewBox.dart';

class FollowRequestTile extends StatefulWidget {
  final String uid;
  FollowRequestTile({this.uid});
  @override
  _FollowRequestTileState createState() => _FollowRequestTileState();
}

class _FollowRequestTileState extends State<FollowRequestTile> {
  String name = '';
  String username = '';
  String displayPicture;
  final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('users');

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    DocumentSnapshot userDoc = await DatabaseService().getSpace(widget.uid);
    name = userDoc['name'];
    username = userDoc['nickname'];
    displayPicture = userDoc['displayPicture'];
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
                    Text("$name",
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
                  await DatabaseService().rejectFollowRequest(widget.uid);
                  setState(() {

                  });
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
                  await DatabaseService().approveFollower(widget.uid);
                  setState(() {

                  });
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
