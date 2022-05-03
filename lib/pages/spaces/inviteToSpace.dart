import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:share/share.dart';
import 'package:yantra/pages/login.dart';
import 'package:yantra/services/databaseService.dart';

class InviteToSpace extends StatefulWidget {
  final String space;
  InviteToSpace({this.space});

  @override
  _InviteToSpaceState createState() => _InviteToSpaceState();
}

class _InviteToSpaceState extends State<InviteToSpace> {
  User user = FirebaseAuth.instance.currentUser;
  String space;
  String link;
  String userName;
  String spaceName;
  File spacePicture;
  File userPicture;
  final CollectionReference userCollection =
      FirebaseFirestore.instance.collection('users');

  @override
  void initState() {
    super.initState();
    getData();
    getInviteLink();
  }

  getData() async {
    DocumentSnapshot authorDoc = await DatabaseService().getSpace(user.uid);
    userName = authorDoc['name'];
    DocumentSnapshot spaceDoc = await DatabaseService().getSpace(widget.space);
    spaceName = spaceDoc['name'];
    if (spaceDoc['displayPicture'] != '')
      spacePicture =
          await DefaultCacheManager().getSingleFile(spaceDoc['displayPicture']);
    spaceName = spaceDoc['name'];
    setState(() {});
  }

  getInviteLink() async {
    space = widget.space;

    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://canay.page.link',
      link: Uri.parse('https://canay.page.link/spaceInvite-$space-${user.uid}'),
      androidParameters: AndroidParameters(
        packageName: 'com.canay.yantra',
        minimumVersion: 24,
      ),
      iosParameters: IOSParameters(
        bundleId: 'com.example.ios',
        minimumVersion: '1.0.1',
        appStoreId: '123456789',
      ),
    );

    final Uri shortUrl = parameters.link;

    setState(() {
      this.link = shortUrl.toString();
    });
    print(link);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          spacePicture != null
              ? Share.shareFiles(
                  [spacePicture.path],
                  text: link,
                  subject:
                      '$userName invited to join the $spaceName space on Yantra',
                )
              : Share.share(
                  link,
                  subject:
                      '$userName invited to join the $spaceName space on Yantra',
                );
        },
        backgroundColor: CupertinoTheme.of(context).primaryColor,
        icon: Icon(Icons.share),
        label: Text('Share Link'),
      ),
      appBar: CupertinoNavigationBar(),
      body: SafeArea(
        child: Center(
          child: (link != null)
              ? GestureDetector(
                  onTap: () {
                    Clipboard.setData(new ClipboardData(text: link));
                  },
                  child: Container(
                      color: CupertinoTheme.of(context).primaryColor,
                      padding: EdgeInsets.all(10),
                      child: Text(
                        link,
                        style: TextStyle(color: Colors.white),
                      )),
                )
              : CircularProgressIndicator(),
        ),
      ),
    );
  }
}
