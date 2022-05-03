import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class UserPreview extends StatefulWidget {
  final String uid;
  final bool showName;

  UserPreview({this.uid, this.showName, Key key}) : super(key: key);
  @override
  _UserPreviewState createState() => _UserPreviewState();
}

class _UserPreviewState extends State<UserPreview> {
  final CollectionReference spacesCollection =
      FirebaseFirestore.instance.collection('spaces');
  File userPicture;
  String name = '';
  String username = 'user';

  @override
  void initState() {
    super.initState();
    getData();
  }

  getData() async {
    DocumentSnapshot authorDoc = await spacesCollection.doc(widget.uid).get();
    name = authorDoc['name'];
    username = authorDoc['nickname'];
    String authordp = authorDoc['displayPicture'];
    if (authordp != '')
      userPicture = await DefaultCacheManager().getSingleFile(authordp);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Column(
        children: [
          Material(
            elevation: 2,
            shape: CircleBorder(),
            borderOnForeground: true,
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: AspectRatio(
              aspectRatio: 1,
              child: (userPicture != null)
                  ? Image.file(
                      userPicture,
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      'assets/images/user.png',
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          if (widget.showName == true && username != null)
            Padding(
              padding: const EdgeInsets.all(2.0),
              child: Text(
                '$username',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
