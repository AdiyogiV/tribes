import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

class FollowersPreview extends StatefulWidget {
  final String? uid;
  final bool? showName;
  final bool? isSelected;
  const FollowersPreview(
      {Key? key, this.uid, required this.showName, @required this.isSelected})
      : super(key: key);

  @override
  _FollowersPreviewState createState() => _FollowersPreviewState();
}

class _FollowersPreviewState extends State<FollowersPreview> {
  final CollectionReference spacesCollection =
      FirebaseFirestore.instance.collection('spaces');
  File? userPicture;
  String name = '';
  String? username;

  @override
  void initState() {
    super.initState();
    getData();
  }

  Future<void> getData() async {
    DocumentSnapshot authordocuments =
        await spacesCollection.doc(widget.uid).get();
    name = authordocuments['name'];

    username = authordocuments['nickname'];
    String authordp = authordocuments['displayPicture'];
    if (authordp != '') {
      userPicture = await DefaultCacheManager().getSingleFile(authordp);
    }
    if (mounted) {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.loose, children: <Widget>[
      Container(
        color: AppTheme.scaffoldLightColor,
        child: AspectRatio(
          aspectRatio: 1,
          child: Column(
            children: [
              Material(
                elevation: 2,
                shape: CircleBorder(),
                clipBehavior: Clip.antiAliasWithSaveLayer,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: (userPicture != null)
                      ? Image.file(
                          userPicture!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Image.asset(
                          'assets/images/user.png',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                ),
              ),
              if (widget.showName == true)
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Text('$username'),
                )
            ],
          ),
        ),
      ),
      if (widget.isSelected == true)
        Padding(
            padding: EdgeInsets.only(right: 10.0, top: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                GestureDetector(
                  onTap: () {},
                  child: CircleAvatar(
                      backgroundColor: AppTheme.successColor,
                      radius: 16.0,
                      child: Icon(
                        Icons.check,
                        color: AppTheme.scaffoldLightColor,
                        size: 14,
                      )),
                )
              ],
            )),
    ]);
  }
}
