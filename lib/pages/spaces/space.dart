import 'dart:io';
import 'dart:math';
import 'package:adiHouse/pages/houseMarket.dart';
import 'package:adiHouse/widgets/Dailogs/joinHouseDailog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:adiHouse/modal/spaceTypes.dart';
import 'package:adiHouse/pages/login.dart';
import 'package:adiHouse/pages/recorder.dart';
import 'package:adiHouse/pages/spaces/createRoom.dart';
import 'package:adiHouse/pages/spaces/editSpace.dart';
import 'package:adiHouse/pages/spaces/gridSpaceView.dart';
import 'package:adiHouse/pages/spaces/spaceTypes/openSpace.dart';
import 'package:adiHouse/pages/spaces/spaceTypes/secretSpace.dart';
import 'package:adiHouse/pages/theatre.dart';
import 'package:adiHouse/services/databaseService.dart';
import 'package:adiHouse/widgets/Dailogs/loginDailog.dart';
import 'package:adiHouse/widgets/previewBox.dart';

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
  bool isPublic = true;
  bool gridViewOn = true;
  int initPage = 0;
  int spaceType;
  bool isMember = false;
  User user = FirebaseAuth.instance.currentUser;
  bool authorized = false;

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
    isMember = await DatabaseService().isMember(widget.rid);
    DocumentSnapshot space = await DatabaseService().getSpace(widget.rid);
    spaceType = space['spaceType'];
    if ((isMember == false) && (spaceType == 2 || spaceType == 3)) {
      Navigator.of(context).pop();
      Navigator.of(context).push(CupertinoPageRoute(builder: (context) {
        return EditSpace(
          space: widget.rid,
        );
      }));
      return;
    }
    name = space['name'];
    displayPicture = space['displayPicture'];
    setState(() {
      authorized = true;
    });
    if (displayPicture != null) {
      displayPicFile =
          await DefaultCacheManager().getSingleFile(displayPicture);
    }
    setState(() {});
  }

  getFloatingButton() {
    return (isMember)
        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                padding: EdgeInsets.only(left: 30),
                child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FloatingActionButton(
                      backgroundColor: Colors.blue[300],
                      foregroundColor: Colors.amber,
                      splashColor: Colors.redAccent,
                      focusColor: Colors.black,
                      hoverColor: Colors.blue,
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => Recorder(
                                      space: widget.rid,
                                    )));
                      },
                      child: Icon(
                        Icons.add,
                        size: 30,
                      ),
                    ))),
            // Container(
            //     padding: EdgeInsets.all(5),
            //     child: Align(
            //       alignment: Alignment.bottomRight,
            //       child: FloatingActionButton.extended(
            //         backgroundColor: Colors.black,
            //         onPressed: () {
            //           Navigator.of(context, rootNavigator: true)
            //               .push(CupertinoPageRoute(builder: (context) {
            //             return HouseMarket(
            //               house: widget.rid,
            //             );
            //           }));
            //         },
            //         icon: Icon(Icons.arrow_forward_ios),
            //         label: Text('Market'),
            //       ),
            //     )),
          ])
        : Container(
            padding: EdgeInsets.only(left: 30),
            child: Align(
                alignment: Alignment.bottomCenter, child: getJoinButton()));
  }

  getJoinButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        DatabaseService().addSpaceMember(widget.rid, user.uid);
        getSpaceBox();
      },
      backgroundColor: CupertinoTheme.of(context).primaryColor,
      icon: Icon(Icons.add),
      label: Text('Join'),
    );
  }

  setPageView(int initPage) {
    this.setState(() {
      this.initPage = initPage;
      if (isMember) gridViewOn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!authorized) return Container();
    return Scaffold(
        backgroundColor: Colors.indigo[100],
        floatingActionButton: getFloatingButton(),
        body: CupertinoPageScaffold(
            backgroundColor: Colors.white24,
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
                        if (isMember) gridViewOn = !gridViewOn;
                        setState(() {});
                      },
                      child: gridViewOn
                          ? Icon(
                              Icons.grid_view_outlined,
                              size: 25,
                              color: CupertinoTheme.of(context).primaryColor,
                            )
                          : Icon(
                              Icons.view_carousel,
                              size: 25,
                              color: CupertinoTheme.of(context).primaryColor,
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
                        color: CupertinoTheme.of(context).primaryColor,
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
