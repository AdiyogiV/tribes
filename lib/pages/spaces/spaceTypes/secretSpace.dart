import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:yantra/pages/spaces/editSpace.dart';
import 'package:yantra/pages/spaces/gridSpaceView.dart';
import 'package:yantra/pages/theatre.dart';
import 'package:yantra/services/databaseService.dart';

class SecretSpace extends StatefulWidget {
  final String space;
  const SecretSpace({this.space, Key key}) : super(key: key);

  @override
  _SecretSpaceState createState() => _SecretSpaceState();
}

class _SecretSpaceState extends State<SecretSpace> {
  String displayPicture;
  File displayPicFile;
  bool gridViewOn = false;
  int initPage = 0;
  String name = '';
  User user = FirebaseAuth.instance.currentUser;
  bool isMember = false;

  getSpaceBox() async {
    if (displayPicture != null) {
      displayPicFile =
          await DefaultCacheManager().getSingleFile(displayPicture);
    }
    setState(() {});
  }

  getSpaceRole() async {
    if (user != null) {
      isMember = await DatabaseService().isMember(widget.space);
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    getSpaceRole();
  }

  setPageView(int initPage) {
    this.setState(() {
      this.initPage = initPage;
      gridViewOn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isMember) {
      return Container(
        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
        child: Center(child: Text("Verification Pending")),
      );
    }
    return CupertinoPageScaffold(
        backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
        navigationBar: CupertinoNavigationBar(
          middle: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                  height: 30,
                  width: 30,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5.0),
                    child: (displayPicFile != null)
                        ? Image.file(
                            displayPicFile,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            child: Image.asset(
                              'assets/images/noise.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                  )),
              Text(
                name,
                style: TextStyle(fontWeight: FontWeight.w300),
              ),
              GestureDetector(
                  onTap: () {
                    gridViewOn = !gridViewOn;
                    setState(() {});
                  },
                  child: gridViewOn
                      ? Icon(
                          Icons.grid_view_outlined,
                          size: 25,
                          color: Colors.black87,
                        )
                      : Icon(
                          Icons.view_carousel,
                          size: 25,
                          color: Colors.black87,
                        )),
              GestureDetector(
                  onTap: () {
                    Navigator.of(context)
                        .push(CupertinoPageRoute(builder: (context) {
                      return EditSpace(
                        space: widget.space,
                      );
                    }));
                  },
                  child: Icon(
                    Icons.info_outline,
                    size: 25,
                    color: Colors.black87,
                  )),
            ],
          ),
        ),
        child: SafeArea(
          child: gridViewOn
              ? GridSpaceView(
                  rid: widget.space,
                  setPageView: setPageView,
                )
              : Theatre(
                  initpage: initPage,
                  rid: widget.space,
                ),
        ));
  }
}
