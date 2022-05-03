import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:yantra/modal/spaceTypes.dart';
import 'package:yantra/pages/login.dart';
import 'package:yantra/pages/recorder.dart';
import 'package:yantra/pages/spaces/createRoom.dart';
import 'package:yantra/pages/spaces/editSpace.dart';
import 'package:yantra/pages/spaces/gridSpaceView.dart';
import 'package:yantra/pages/spaces/spaceTypes/openSpace.dart';
import 'package:yantra/pages/spaces/spaceTypes/secretSpace.dart';
import 'package:yantra/pages/theatre.dart';
import 'package:yantra/services/databaseService.dart';
import 'package:yantra/widgets/Dailogs/loginDailog.dart';
import 'package:yantra/widgets/previewBox.dart';

class SpaceBox extends StatefulWidget {
  final String rid;
  SpaceBox({Key key, this.rid}) : super(key: key);

  @override
  _SpaceBoxState createState() => _SpaceBoxState();
}

class _SpaceBoxState extends State<SpaceBox> {
  String name = '';
  String discription = '';
  Map members;
  int membersCount = 0;
  String displayPicture;
  File displayPicFile;
  String uidSelf = '';
  int personal = 0;
  bool isPublic = false;
  bool gridViewOn = false;
  int initPage = 0;
  int spaceType;

  List<Widget> spacePosts = [];

  final CollectionReference spacesCollection =
      FirebaseFirestore.instance.collection('spaces');
  final CollectionReference spacePostsCollection =
      FirebaseFirestore.instance.collection('spacePosts');
  final CollectionReference spaceRolesCollection =
      FirebaseFirestore.instance.collection('spaceRoles');

  final CollectionReference userCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference postCollection =
      FirebaseFirestore.instance.collection('posts');
  final CollectionReference votesCollection =
      FirebaseFirestore.instance.collection('votes');

  @override
  void initState() {
    super.initState();
    getSpaceBox();
  }

  requestLogin() async {
    await showCupertinoDialog(
        context: context,
        builder: (context) {
          return LoginDailog();
        });
  }

  getSpaceBox() async {
    DocumentSnapshot space = await DatabaseService().getSpace(widget.rid);
    name = space['name'];
    displayPicture = space['displayPicture'];
    spaceType = space['spaceType'];
    setState(() {});
    if (displayPicture != null) {
      displayPicFile =
          await DefaultCacheManager().getSingleFile(displayPicture);
    }
    setState(() {});
  }

  // getFloatingButton() {
  //   if (isMember) {
  //     return FloatingActionButton(
  //       onPressed: () {
  //         Navigator.push(
  //             context,
  //             MaterialPageRoute(
  //                 builder: (context) => Recorder(
  //                       space: widget.rid,
  //                     )));
  //       },
  //       child: Icon(Icons.add),
  //     );
  //   } else {
  //     switch (spaceType) {
  //       case 0:
  //         return FloatingActionButton(
  //           onPressed: () async {
  //             await DatabaseService().addSpaceMember(widget.rid, user.uid);
  //             //await getSpaceRole();
  //             setState(() {});
  //           },
  //           backgroundColor: CupertinoTheme.of(context).primaryColor,
  //           child: Text(
  //             'Join',
  //             style: TextStyle(
  //               color: Colors.white,
  //             ),
  //           ),
  //         );
  //       case 1:
  //         return FloatingActionButton(
  //           onPressed: () async {
  //             await DatabaseService().addSpaceMember(widget.rid, user.uid);
  //             //await getSpaceRole();
  //             setState(() {});
  //           },
  //           backgroundColor: CupertinoTheme.of(context).primaryColor,
  //           child: Text(
  //             'Follow',
  //             style: TextStyle(color: Colors.white),
  //           ),
  //         );
  //       case 2:
  //         return FloatingActionButton(
  //           onPressed: () async {
  //             await DatabaseService().addSpaceMember(widget.rid, user.uid);
  //             //await getSpaceRole();
  //             setState(() {});
  //           },
  //           backgroundColor: CupertinoTheme.of(context).primaryColor,
  //           child: Text(
  //             'Request Access',
  //             style: TextStyle(color: Colors.white),
  //           ),
  //         );
  //         return Container();
  //     }
  //   }
  // }

  setPageView(int initPage) {
    this.setState(() {
      this.initPage = initPage;
      gridViewOn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (spaceType) {
      case 0:
        return OpenSpace(
          space: widget.rid,
        );
      case 1:
        return GridSpaceView(
          rid: widget.rid,
        );
      case 2:
        return GridSpaceView(
          rid: widget.rid,
        );
      case 3:
        return SecretSpace(
          space: widget.rid,
        );
    }

    if (spaceType == 3) {
      return SecretSpace(
        space: widget.rid,
      );
    }
    return Scaffold(
        backgroundColor: Colors.indigo[100],
        //floatingActionButton: gridViewOn ? getFloatingButton() : Container(),
        body: CupertinoPageScaffold(
            backgroundColor: Colors.indigo[100],
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
                            space: widget.rid,
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
                      rid: widget.rid,
                      setPageView: setPageView,
                    )
                  : Theatre(
                      initpage: initPage,
                      rid: widget.rid,
                    ),
            )));
  }
}
