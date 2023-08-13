import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class UserPreview extends StatefulWidget {
  final String? uid;
  final bool? showName;

  UserPreview({this.uid, this.showName, Key? key}) : super(key: key);
  @override
  _UserPreviewState createState() => _UserPreviewState();
}

class _UserPreviewState extends State<UserPreview> {
  final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('users');
  File? userPicture;
  String name = '';
  String username = 'user';

  @override
  void initState() {
    super.initState();
    if(widget.uid!.isNotEmpty) getData();
  }

  getData() async {
    DocumentSnapshot authordocuments =
        await usersCollection.doc(widget.uid).get();
    name = authordocuments['name'];
    username = authordocuments['nickname'];
    String authordp = authordocuments['displayPicture'];
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
                      userPicture!,
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      'assets/images/user.png',
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          if (widget.showName == true)
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
