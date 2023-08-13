import 'dart:io';

import 'package:tribes/modal/SpaceRoles.dart';
import 'package:tribes/pages/requests.dart';
import 'package:tribes/pages/stageCrew.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' as FCM;
import 'package:image_picker/image_picker.dart';
import 'package:tribes/services/databaseService.dart';
import 'package:tribes/widgets/previewBoxes/crewPreview.dart';
import 'package:share/share.dart';

class EditSpace extends StatefulWidget {
  final String? space;
  EditSpace({this.space});
  @override
  MapScreenState createState() => MapScreenState();
}

enum StatusEnums { follower, requested, member, owner, none }

class MapScreenState extends State<EditSpace>
    with SingleTickerProviderStateMixin {
  User? user = FirebaseAuth.instance.currentUser;
  bool isOwner = false;
  final FocusNode myFocusNode = FocusNode();
  String? spaceName;
  String? userName;
  File? _imageFile;
  String? _imageFilePath;
  String? admin;
  bool isPublic = false;
  int? selectedIndex;
  bool isMember = false;
  roles? role = null;
  String? link;

  TextEditingController _nameController = TextEditingController();
  TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getSpaceBox();
    getInviteLink();
  }

  getSpaceBox() async {
    isOwner = await DatabaseService().isUserSpaceOwner(widget.space!);
    isMember = await DatabaseService().isMember(widget.space!);
    role = await DatabaseService().getSpaceRole(widget.space!);

    setState(() {});
    DocumentSnapshot spacedocuments =
        await DatabaseService().getSpace(widget.space!);
    spaceName = spacedocuments['name'];
    DocumentSnapshot authordocuments =
        await DatabaseService().getUser(user!.uid);
    userName = authordocuments['name'];
    _nameController.text = spacedocuments['name'];
    var _imagePath = spacedocuments['displayPicture'];
    if (_imagePath != null) {
      _imageFile = await FCM.DefaultCacheManager().getSingleFile(_imagePath);
    }
    _bioController.text = spacedocuments['description'];
    setState(() {});
  }

  void _onImageButtonPressed() async {
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);

      _imageFilePath = pickedFile!.path;
      _imageFile = File(_imageFilePath!);

      setState(() {});
    } catch (e) {
      setState(() {});
    }
  }

  void onSavePressed() async {
    await DatabaseService().updateSpace(widget.space!, _nameController.text,
        _bioController.text, _imageFilePath!, isPublic);
    Navigator.of(context).pop();
  }

  getFloatingButton() {
    if (role == roles.creator || role == roles.admin)
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          getRequestsPageButton(),
          getMembersPageButton(),
          getExitButton(),
        ],
      );
    if (role == roles.requested) return getRequestedButton();
    if (role == roles.member)
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          getInviteButton(),
          getMembersPageButton(),
          getExitButton(),
        ],
      );
    if (role == roles.none) return getJoinButton();
  }

  getInviteLink() async {
    String space = widget.space!;

    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://canay.page.link',
      link: Uri.parse('https://canay.page.link/spaceInvite-$space-${user!.uid}'),
      androidParameters: AndroidParameters(
        packageName: 'com.canay.tribes',
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
  }

  getInviteButton() {
    return Container(
        padding: EdgeInsets.all(5),
        child: FloatingActionButton.extended(
          onPressed: () {
            _imageFile != null
                ? Share.shareFiles(
                    [_imageFilePath!],
                    text: link,
                    subject:
                        '$userName invited to join the $spaceName space on tribes',
                  )
                : Share.share(
                    link!,
                    subject:
                        '$userName invited to join the $spaceName space on tribes',
                  );
          },
          backgroundColor: Colors.red,
          icon: Icon(Icons.share),
          label: Text('Invite'),
        ));
  }

  getRequestsPageButton() {
    return Container(
        padding: EdgeInsets.all(5),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context, rootNavigator: true)
                .push(CupertinoPageRoute(builder: (context) {
              return Requests(
                space: widget.space!,
              );
            }));
          },
          backgroundColor: CupertinoTheme.of(context).primaryContrastingColor,
          icon: Icon(Icons.exit_to_app_rounded),
          label: Text('Requests'),
        ));
  }

  getMembersPageButton() {
    return Container(
        padding: EdgeInsets.all(5),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context, rootNavigator: true)
                .push(CupertinoPageRoute(builder: (context) {
              return StageCrew(
                space: widget.space!,
              );
            }));
          },
          backgroundColor: Colors.lightGreen,
          icon: Icon(Icons.group),
          label: Text('Members'),
        ));
  }

  getExitButton() {
    return Container(
        padding: EdgeInsets.all(5),
        child: FloatingActionButton.extended(
          onPressed: () {
            DatabaseService().removeSpaceMember(widget.space!, user!.uid);
            getSpaceBox();
          },
          backgroundColor: Colors.grey,
          icon: Icon(Icons.exit_to_app_rounded),
          label: Text('Leave'),
        ));
  }

  getJoinButton() {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: FloatingActionButton.extended(
        onPressed: () {
          DatabaseService().addSpaceMember(widget.space!, user!.uid);
          getSpaceBox();
        },
        backgroundColor: CupertinoTheme.of(context).primaryColor,
        icon: Icon(Icons.add),
        label: Text('Join'),
      ),
    );
  }

  getRequestedButton() {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: FloatingActionButton.extended(
        onPressed: () {
          DatabaseService().removeSpaceMember(widget.space!, user!.uid);
          getSpaceBox();
        },
        backgroundColor: CupertinoTheme.of(context).primaryContrastingColor,
        icon: Icon(Icons.arrow_circle_right),
        label: Text('Requested'),
      ),
    );
  }

  getCrew() {
    return FutureBuilder<QuerySnapshot>(
        future: DatabaseService().getAllSpaceRoles(widget.space!),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          List<Widget> members = snapshot.data!.docs
              .map((documents) => Container(
                    height: 80,
                    child: CrewPreview(
                      role: documents['role'],
                      user: documents.id,
                    ),
                  ))
              .toList();
          return Wrap(
            children: members,
          );
        });
    //   List spaceList = snapshot.data.docs
    //       .asMap()
    //       .map((index, documents) => MapEntry(
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
    //                   user: documents.id,
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
                                        _imageFile!,
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
// Expanded(
//                       child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: getCrew())),