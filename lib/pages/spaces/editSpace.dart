import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' as FCM;
import 'package:image_picker/image_picker.dart';
import 'package:adiHouse/pages/spaces/addSpacesMembers.dart';
import 'package:adiHouse/pages/spaces/inviteToSpace.dart';
import 'package:adiHouse/pages/userProfile.dart';
import 'package:adiHouse/services/databaseService.dart';
import 'package:adiHouse/widgets/Dailogs/spaceMemberOptions.dart';
import 'package:adiHouse/widgets/previewBoxes/crewPreview.dart';
import 'package:adiHouse/widgets/previewBoxes/followersPreview.dart';
import 'package:adiHouse/widgets/previewBoxes/spacePreviewBox.dart';

class EditSpace extends StatefulWidget {
  final String space;
  EditSpace({this.space});
  @override
  MapScreenState createState() => MapScreenState();
}

enum StatusEnums { follower, requested, member, owner, none }

class MapScreenState extends State<EditSpace>
    with SingleTickerProviderStateMixin {
  User user = FirebaseAuth.instance.currentUser;
  bool isOwner = false;
  final FocusNode myFocusNode = FocusNode();
  File _imageFile;
  String _imageFilePath;
  String admin;
  bool isPublic = false;
  int selectedIndex;
  var file = File('file.txt');
  bool isMember = false;

  TextEditingController _nameController = TextEditingController();
  TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getSpaceBox();
  }

  getSpaceBox() async {
    isOwner = await DatabaseService().isUserSpaceOwner(widget.space);
    isMember = await DatabaseService().isMember(widget.space);
    setState(() {});
    DocumentSnapshot spaceDoc = await DatabaseService().getSpace(widget.space);

    _nameController.text = spaceDoc['name'];
    var _imagePath = spaceDoc['displayPicture'];
    if (_imagePath != null) {
      _imageFile = await FCM.DefaultCacheManager().getSingleFile(_imagePath);
    }
    _bioController.text = spaceDoc['description'];
    setState(() {});
  }

  void _onImageButtonPressed() async {
    try {
      final pickedFile =
          await ImagePicker().getImage(source: ImageSource.gallery);

      _imageFilePath = pickedFile.path;
      _imageFile = File(_imageFilePath);

      setState(() {});
    } catch (e) {
      setState(() {});
    }
  }

  void onSavePressed() async {
    await DatabaseService().updateSpace(widget.space, _nameController.text,
        _bioController.text, _imageFilePath, isPublic);
    Navigator.of(context).pop();
  }

  getFloatingButton() {
    if (isMember)
      return getExitButton();
    else
      return getJoinButton();
  }

  getExitButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        DatabaseService().removeSpaceMember(widget.space, user.uid);
        getSpaceBox();
      },
      backgroundColor: CupertinoTheme.of(context).primaryColor,
      icon: Icon(Icons.exit_to_app_rounded),
      label: Text('Leave'),
    );
  }

  getJoinButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        DatabaseService().addSpaceMember(widget.space, user.uid);
        getSpaceBox();
      },
      backgroundColor: CupertinoTheme.of(context).primaryColor,
      icon: Icon(Icons.add),
      label: Text('Join'),
    );
  }

  getCrew() {
    return FutureBuilder<QuerySnapshot>(
        future: DatabaseService().getAllSpaceRoles(widget.space),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          List members = snapshot.data.docs
              .map((doc) => Container(
                    height: 80,
                    child: CrewPreview(
                      role: doc['role'],
                      user: doc.id,
                    ),
                  ))
              .toList();
          return Wrap(
            children: members,
          );
        });
    //   List spaceList = snapshot.data.docs
    //       .asMap()
    //       .map((index, doc) => MapEntry(
    //             index,
    //             GestureDetector(
    //               key: UniqueKey(),
    //               onTap: () {
    //                 Navigator.of(context)
    //                     .push(CupertinoPageRoute(builder: (context) {
    //                   return UserProfilePage(
    //                     uid: _spaceMembers[index].id,
    //                   );
    //                 }));
    //               },
    //               onLongPress: () {
    //                 selectedIndex = index;
    //                 setState(() {});
    //                 showCupertinoModalPopup(
    //                     context: context,
    //                     builder: (BuildContext context) =>
    //                         SpaceMemberOptions(
    //                           uid: _spaceMembers[index].id,
    //                           space: widget.space,
    //                         ));
    //               },
    //               child: Container(
    //                 height: 100,
    //                 padding: EdgeInsets.only(top: 5, left: 5, right: 5),
    //                 child: CrewPreview(
    //                   key: UniqueKey(),
    //                   user: doc.id,
    //                 ),
    //               ),
    //             ),
    //           ))
    //       .values
    //       .toList();
    //   return Container(
    //     child: Wrap(
    //       children: spaceList,
    //     ),
    //   );
    // });
  }

  @override
  Widget build(BuildContext context) {
    double p_width = MediaQuery.of(context).size.width * 0.4;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      floatingActionButton: getFloatingButton(),
      backgroundColor: Colors.black54,
      body: CupertinoPageScaffold(
          resizeToAvoidBottomInset: false,
          navigationBar: CupertinoNavigationBar(
            middle: Text('Space Details'),
            trailing: (isOwner)
                ? GestureDetector(
                    onTap: () {
                      onSavePressed();
                    },
                    child: Text(
                      'Save',
                      style: TextStyle(color: CupertinoColors.activeBlue),
                    ))
                : Container(),
          ),
          child: SafeArea(
            child: Form(
              child: Column(
                children: <Widget>[
                  Container(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: new Stack(fit: StackFit.loose, children: <Widget>[
                        new Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(5.0),
                              clipBehavior: Clip.antiAlias,
                              child: new Container(
                                width: p_width,
                                height: p_width,
                                child: (_imageFile != null)
                                    ? Image.file(
                                        _imageFile,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.asset(
                                        'assets/images/noise.jpg',
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        if (isOwner)
                          Padding(
                              padding: EdgeInsets.only(right: 60.0, top: 10),
                              child: new Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: <Widget>[
                                  GestureDetector(
                                    onTap: () {
                                      _onImageButtonPressed();
                                    },
                                    child: new CircleAvatar(
                                        backgroundColor: Colors.red,
                                        radius: 25.0,
                                        child: Icon(
                                          Icons.edit,
                                          color: CupertinoColors.white,
                                        )),
                                  )
                                ],
                              )),
                      ]),
                    ),
                  ),
                  new Container(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 25.0),
                      child: new Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                              padding: EdgeInsets.only(
                                  left: 15.0, right: 15.0, top: 10.0),
                              child: new Row(
                                mainAxisSize: MainAxisSize.max,
                                children: <Widget>[
                                  new Flexible(
                                    child: new CupertinoTextField(
                                      padding: EdgeInsets.all(10),
                                      controller: _nameController,
                                      placeholder: 'Space Name',
                                      enabled: isOwner,
                                    ),
                                  ),
                                ],
                              )),
                          Padding(
                              padding: EdgeInsets.only(
                                  left: 15.0, right: 15.0, top: 10.0),
                              child: new Row(
                                mainAxisSize: MainAxisSize.max,
                                children: <Widget>[
                                  new Flexible(
                                    child: new CupertinoTextField(
                                      padding: EdgeInsets.all(10),
                                      controller: _bioController,
                                      style: TextStyle(fontSize: 14),
                                      placeholder: 'Description',
                                      enabled: isOwner,
                                    ),
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text('Members',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 2,
                                color: Colors.white,
                                offset: Offset(0, 0),
                              ),
                            ],
                          )),
                    ),
                  ),
                  Expanded(
                      child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: getCrew())),
                ],
              ),
            ),
          )),
    );
  }

  @override
  void dispose() {
    // Clean up the controller when the Widget is disposed
    myFocusNode.dispose();
    super.dispose();
  }
}
