import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:yantra/pages/editUserProfile.dart';
import 'package:yantra/pages/login.dart';
import 'package:yantra/pages/recorder.dart';
import 'package:yantra/pages/stageCrew.dart';
import 'package:yantra/pages/theatre.dart';
import 'package:yantra/services/authService.dart';
import 'package:yantra/services/databaseService.dart';
import 'package:yantra/services/functionsService.dart';
import 'package:yantra/widgets/Dailogs/profileDailog.dart';
import 'package:yantra/widgets/previewBox.dart';
import 'package:yantra/widgets/previewBoxes/userPicture.dart';
import 'package:yantra/widgets/previewBoxes/userPreviewBox.dart';

class UserProfilePage extends StatefulWidget {
  final String uid;
  UserProfilePage({Key key, this.uid}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

enum StatusEnums { follower, requested, owner, none }

class _UserProfilePageState extends State<UserProfilePage> {
  String name = '';
  String nickname = '';
  String bio = '';
  List following = [];
  User user = FirebaseAuth.instance.currentUser;
  bool isProfileSelf = false;
  List followers = [];
  List requests = [];
  List<Widget> postView = <Widget>[];
  int personal = 0;
  StatusEnums followingStatus = StatusEnums.none;
  Color textColor = Colors.black87;
  List<Widget> spacePosts = [];
  String displayPicture;
  File userPicture;
  bool isPublic = false;

  final CollectionReference spacesCollection =
      FirebaseFirestore.instance.collection('spaces');
  final CollectionReference userCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference postCollection =
      FirebaseFirestore.instance.collection('posts');
  final CollectionReference votesCollection =
      FirebaseFirestore.instance.collection('votes');
  final CollectionReference spaceRolesCollection =
      FirebaseFirestore.instance.collection('spaceRoles');
  final CollectionReference userSpacesCollection =
      FirebaseFirestore.instance.collection('userSpaces');

  final CollectionReference spacePostsCollection =
      FirebaseFirestore.instance.collection('spacePosts');

  RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    checkStatus();
    getProfile();
  }

  checkStatus() async {
    if (widget.uid == user.uid) {
      followingStatus = StatusEnums.owner;
      setState(() {});
      return;
    }
    if (user != null) {
      String role = await DatabaseService().getSpaceRole(widget.uid);
      if (role == 'follower') followingStatus = StatusEnums.follower;
      if (role == 'requested') followingStatus = StatusEnums.requested;
      if (role == 'owner') followingStatus = StatusEnums.owner;
      setState(() {});
    }
  }

  requestLogin() async {
    await showCupertinoDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            content: Text("Please Login to Continue"),
            actions: <Widget>[
              FlatButton(
                  onPressed: () {
                    Navigator.of(context)
                        .push(CupertinoPageRoute(builder: (context) {
                      return LoginPage();
                    }));
                  },
                  child: Text(
                    'Login',
                    style: TextStyle(
                        color: CupertinoColors.destructiveRed,
                        fontWeight: FontWeight.w400),
                  )),
              FlatButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: CupertinoColors.activeBlue,
                        fontWeight: FontWeight.w400),
                  ))
            ],
          );
        });
  }

  getProfile() async {
    DocumentSnapshot spaceDoc = await spacesCollection.doc(widget.uid).get();
    isPublic = spaceDoc['public'];
    name = spaceDoc['name'];
    nickname = spaceDoc['nickname'];
    bio = spaceDoc['description'];
    displayPicture = spaceDoc['displayPicture'];

    if (followingStatus == StatusEnums.follower)
      following = (await userSpacesCollection
              .doc(widget.uid)
              .collection('spaces')
              .where('role', isEqualTo: 'follower')
              .get())
          .docs;
    if (mounted) {
      setState(() {});
    }
  }

  void _onRefresh() async {
    // monitor network fetch\
    // if failed,use refreshFailed()
    getProfile();
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    // monitor network fetch
    // if failed,use loadFailed(),if no data return,use LoadNodata()
    _refreshController.loadComplete();
  }

  userPosts() {
    return FutureBuilder<QuerySnapshot>(
        future: spacePostsCollection
            .doc(widget.uid)
            .collection('posts')
            .orderBy('timestamp', descending: true)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (!isPublic && followingStatus != StatusEnums.follower) {
              return Container(
                height: 200,
                child: Center(
                  child: Text(
                    '$name`s account is private. \nFollow $name to view their posts.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(50.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          spacePosts = snapshot.data.docs
              .asMap()
              .map((index, doc) => MapEntry(
                    index,
                    GestureDetector(
                      key: UniqueKey(),
                      onTap: () {
                        Navigator.of(context, rootNavigator: true)
                            .push(CupertinoPageRoute(builder: (context) {
                          return Theatre(
                            initpage: index,
                            rid: widget.uid,
                          );
                        }));
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width / 4,
                        child: PreviewBox(
                          author: null,
                          key: UniqueKey(),
                          previewUrl: doc['thumbnail'],
                          title: doc['title'],
                        ),
                      ),
                    ),
                  ))
              .values
              .toList();
          return Wrap(
            children: spacePosts,
          );
        });
  }

  getFloatingButton() {
    if (followingStatus == StatusEnums.owner) {
      return FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(CupertinoPageRoute(builder: (builder) {
            return Recorder();
          }));
        },
        backgroundColor: CupertinoTheme.of(context).primaryColor,
        child: Icon(Icons.add),
      );
    }
    if (followingStatus == StatusEnums.follower) {
      return FloatingActionButton.extended(
        key: UniqueKey(),
        onPressed: () async {
          await DatabaseService().unfollow(widget.uid);
          checkStatus();
        },
        backgroundColor: CupertinoColors.activeBlue,
        icon: Icon(Icons.check),
        label: Text('FOLLOWING'),
      );
    }
    if (followingStatus == StatusEnums.requested) {
      return FloatingActionButton.extended(
        key: UniqueKey(),
        onPressed: () async {
          await DatabaseService().unfollow(widget.uid);
          checkStatus();
        },
        backgroundColor: CupertinoColors.activeOrange,
        icon: Icon(Icons.pending),
        label: Text('REQUESTED'),
      );
    }
    return FloatingActionButton.extended(
      key: UniqueKey(),
      onPressed: () async {
        if (user == null) {
          requestLogin();
          return;
        }

        await DatabaseService().addFollower(widget.uid);
        checkStatus();
      },
      backgroundColor: CupertinoColors.activeGreen,
      icon: Icon(Icons.person_add_rounded),
      label: Text('FOLLOW'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: getFloatingButton(),
      body: SafeArea(
        child: SmartRefresher(
          controller: _refreshController,
          onLoading: _onLoading,
          onRefresh: _onRefresh,
          header: WaterDropMaterialHeader(
            backgroundColor: CupertinoTheme.of(context).primaryColor,
            distance: 100,
          ),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                stretch: true,
                floating: true,
                expandedHeight: 350,
                collapsedHeight: 300,
                elevation: 5,
                forceElevated: true,
                backgroundColor: Colors.white,
                flexibleSpace: headerSection(context),
                iconTheme: IconThemeData(
                    color: CupertinoTheme.of(context).primaryColor),
                title: Text(
                  nickname,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: CupertinoTheme.of(context).primaryColor,
                  ),
                ),
                actions: [
                  if (followingStatus == StatusEnums.owner)
                    GestureDetector(
                      onTap: () {
                        showCupertinoModalPopup(
                            context: context,
                            builder: (BuildContext context) => ProfileOptions(
                                  uid: widget.uid,
                                ));
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Icon(
                          Icons.more_horiz,
                        ),
                      ),
                    )
                ],
              ),
              SliverToBoxAdapter(
                child: Container(
                  height: 5,
                ),
              ),
              SliverToBoxAdapter(
                child: userPosts(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget headerSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: AspectRatio(
                      aspectRatio: 1,
                      child: (displayPicture != null)
                          ? UserPreview(
                              uid: widget.uid,
                              showName: false,
                            )
                          : Container()),
                ),
                flex: 2),
            Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(left: 5.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.black87,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      if (bio.isNotEmpty)
                        Text(
                          bio,
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w300,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                )),
            Divider(),
            Expanded(
              flex: 1,
              child: Padding(
                padding: EdgeInsets.only(left: 00, right: 00),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Text(
                            spacePosts.length.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          Text('posts',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                                color: textColor,
                              ))
                        ],
                      ),
                    ),
                    // Expanded(
                    //   flex: 3,
                    //   child: Column(
                    //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    //     children: <Widget>[
                    //       Text(
                    //         spacePosts.length.toString(),
                    //         style: TextStyle(
                    //           fontSize: 16,
                    //           color: textColor,
                    //         ),
                    //       ),
                    //       Text('reactions',
                    //           style: TextStyle(
                    //             fontWeight: FontWeight.w400,
                    //             fontSize: 12,
                    //             color: textColor,
                    //           ))
                    //     ],
                    //   ),
                    // ),
                    // Expanded(
                    //   flex: 3,
                    //   child: Column(
                    //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    //     children: <Widget>[
                    //       Text(
                    //         '55',
                    //         style: TextStyle(
                    //           fontSize: 16,
                    //           color: textColor,
                    //         ),
                    //       ),
                    //       Text('upvotes',
                    //           style: TextStyle(
                    //             fontWeight: FontWeight.w400,
                    //             fontSize: 12,
                    //             color: textColor,
                    //           ))
                    //     ],
                    //   ),
                    // ),
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context)
                              .push(CupertinoPageRoute(builder: (context) {
                            return StageCrew(
                              title: '$nickname`s followers',
                              guestList: followers,
                            );
                          }));
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            Text(
                              '${followers.length}',
                              style: TextStyle(
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'followers',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                                color: textColor,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () {
                          //   Navigator.of(context)
                          //       .push(CupertinoPageRoute(builder: (context) {
                          //     return StageCrew(
                          //       title: '$nickname is following',
                          //       guestList: following,
                          //     );
                          //   }));
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            Text(
                              '${following.length}',
                              style: TextStyle(
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'following',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                                color: textColor,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    // Expanded(
                    //   flex: 3,
                    //   child: Column(
                    //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    //     children: <Widget>[
                    //       Text(
                    //         spacePosts.length.toString(),
                    //         style: TextStyle(
                    //           fontSize: 16,
                    //           color: textColor,
                    //         ),
                    //       ),
                    //       Text('reacted',
                    //           style: TextStyle(
                    //             fontWeight: FontWeight.w400,
                    //             fontSize: 12,
                    //             color: textColor,
                    //           ))
                    //     ],
                    //   ),
                    // ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
