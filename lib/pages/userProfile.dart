import 'dart:io';

import 'package:tribes/modal/SpaceRoles.dart';
import 'package:tribes/widgets/Dailogs/tokenDialog.dart';
import 'package:tribes/widgets/previewBoxes/tokenPreview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:tribes/pages/login.dart';
import 'package:tribes/pages/recorder.dart';
import 'package:tribes/services/databaseService.dart';
import 'package:tribes/widgets/Dailogs/profileDailog.dart';
import 'package:tribes/widgets/previewBoxes/userPreviewBox.dart';

class UserProfilePage extends StatefulWidget {
  final String? uid;
  UserProfilePage({Key? key, required this.uid}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

enum StatusEnums { follower, requested, owner, none }

class _UserProfilePageState extends State<UserProfilePage> {
  String name = '';
  String nickname = '';
  String bio = '';
  User? user = FirebaseAuth.instance.currentUser;
  bool isProfileSelf = false;
  List requests = [];
  List<Widget> postView = <Widget>[];
  int personal = 0;
  StatusEnums followingStatus = StatusEnums.none;
  Color textColor = Colors.black87;
  List<Widget> spacePosts = [];
  String? displayPicture;
  File? userPicture;
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

  final CollectionReference userItemsCollection =
      FirebaseFirestore.instance.collection('userItems');

  RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    checkStatus();
    getProfile();
  }

  checkStatus() async {
    if (widget.uid == user!.uid) {
      followingStatus = StatusEnums.owner;
      setState(() {});
      return;
    }
    roles role = await DatabaseService().getSpaceRole(widget.uid);
    if (role == roles.follower) followingStatus = StatusEnums.follower;
    if (role == roles.requested) followingStatus = StatusEnums.requested;
    if (role == roles.owner) followingStatus = StatusEnums.owner;
    setState(() {});
  }

  requestLogin() async {
    await showCupertinoDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            content: Text("Please Login to Continue"),
            actions: <Widget>[
              TextButton(
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
              TextButton(
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
    DocumentSnapshot spacedocuments =
        await userCollection.doc(widget.uid).get();
    name = spacedocuments['name'];
    nickname = spacedocuments['nickname'];
    displayPicture = spacedocuments['displayPicture'];

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

  userItems() {
    return FutureBuilder<QuerySnapshot>(
        future: userItemsCollection.doc(widget.uid).collection('items').get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.all(50.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          spacePosts = snapshot.data!.docs
              .asMap()
              .map((index, documents) => MapEntry(
                    index,
                    GestureDetector(
                      key: UniqueKey(),
                      onTap: () {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return TokenDialog(
                                item: documents.id,
                              );
                            });
                      },
                      child: Container(
                          width: MediaQuery.of(context).size.width / 6,
                          child: UserToken(
                            token: documents.id,
                          )),
                    ),
                  ))
              .values
              .toList();
          return Wrap(
            children: spacePosts,
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      //floatingActionButton: getFloatingButton(),
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
                elevation: 1,
                forceElevated: true,
                backgroundColor: Colors.transparent,
                flexibleSpace: headerSection(context),
                title: Text(
                  nickname,
                  style: TextStyle(
                    fontWeight: FontWeight.w200,
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
                                  uid: widget.uid!,
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
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Your Collection',
                    style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w200,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: userItems(),
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
                          fontSize: 30,
                          color: Colors.white,
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
            //   Expanded(
            //     flex: 1,
            //     child: Padding(
            //       padding: EdgeInsets.only(left: 00, right: 00),
            //       child: Row(
            //         mainAxisAlignment: MainAxisAlignment.spaceAround,
            //         crossAxisAlignment: CrossAxisAlignment.center,
            //         children: [
            //           // Expanded(
            //           //   flex: 3,
            //           //   child: Column(
            //           //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //           //     children: <Widget>[
            //           //       Text(
            //           //         spacePosts.length.toString(),
            //           //         style: TextStyle(
            //           //           fontSize: 16,
            //           //           color: textColor,
            //           //         ),
            //           //       ),
            //           //       Text('posts',
            //           //           style: TextStyle(
            //           //             fontWeight: FontWeight.w400,
            //           //             fontSize: 12,
            //           //             color: textColor,
            //           //           ))
            //           //     ],
            //           //   ),
            //           // ),
            //           // // Expanded(
            //           //   flex: 3,
            //           //   child: Column(
            //           //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //           //     children: <Widget>[
            //           //       Text(
            //           //         spacePosts.length.toString(),
            //           //         style: TextStyle(
            //           //           fontSize: 16,
            //           //           color: textColor,
            //           //         ),
            //           //       ),
            //           //       Text('reactions',
            //           //           style: TextStyle(
            //           //             fontWeight: FontWeight.w400,
            //           //             fontSize: 12,
            //           //             color: textColor,
            //           //           ))
            //           //     ],
            //           //   ),
            //           // ),
            //           // Expanded(
            //           //   flex: 3,
            //           //   child: Column(
            //           //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //           //     children: <Widget>[
            //           //       Text(
            //           //         '55',
            //           //         style: TextStyle(
            //           //           fontSize: 16,
            //           //           color: textColor,
            //           //         ),
            //           //       ),
            //           //       Text('upvotes',
            //           //           style: TextStyle(
            //           //             fontWeight: FontWeight.w400,
            //           //             fontSize: 12,
            //           //             color: textColor,
            //           //           ))
            //           //     ],
            //           //   ),
            //           // ),
            //           Expanded(
            //             flex: 3,
            //             child: GestureDetector(
            //               onTap: () {
            //                 Navigator.of(context)
            //                     .push(CupertinoPageRoute(builder: (context) {
            //                   return StageCrew(
            //                     title: '$nickname`s followers',
            //                     guestList: followers,
            //                   );
            //                 }));
            //               },
            //               child: Column(
            //                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //                 children: <Widget>[
            //                   Text(
            //                     '${followers.length}',
            //                     style: TextStyle(
            //                       fontSize: 16,
            //                       color: textColor,
            //                     ),
            //                   ),
            //                   Text(
            //                     'followers',
            //                     style: TextStyle(
            //                       fontWeight: FontWeight.w400,
            //                       fontSize: 12,
            //                       color: textColor,
            //                     ),
            //                   )
            //                 ],
            //               ),
            //             ),
            //           ),
            //           Expanded(
            //             flex: 3,
            //             child: GestureDetector(
            //               onTap: () {
            //                 //   Navigator.of(context)
            //                 //       .push(CupertinoPageRoute(builder: (context) {
            //                 //     return StageCrew(
            //                 //       title: '$nickname is following',
            //                 //       guestList: following,
            //                 //     );
            //                 //   }));
            //               },
            //               child: Column(
            //                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //                 children: <Widget>[
            //                   Text(
            //                     '${following.length}',
            //                     style: TextStyle(
            //                       fontSize: 16,
            //                       color: textColor,
            //                     ),
            //                   ),
            //                   Text(
            //                     'following',
            //                     style: TextStyle(
            //                       fontWeight: FontWeight.w400,
            //                       fontSize: 12,
            //                       color: textColor,
            //                     ),
            //                   )
            //                 ],
            //               ),
            //             ),
            //           ),
            //           // Expanded(
            //           //   flex: 3,
            //           //   child: Column(
            //           //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //           //     children: <Widget>[
            //           //       Text(
            //           //         spacePosts.length.toString(),
            //           //         style: TextStyle(
            //           //           fontSize: 16,
            //           //           color: textColor,
            //           //         ),
            //           //       ),
            //           //       Text('reacted',
            //           //           style: TextStyle(
            //           //             fontWeight: FontWeight.w400,
            //           //             fontSize: 12,
            //           //             color: textColor,
            //           //           ))
            //           //     ],
            //           //   ),
            //           // ),
            //         ],
            //       ),
            //     ),
            //   )
          ],
        ),
      ),
    );
  }
}
