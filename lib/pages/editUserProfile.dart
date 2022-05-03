import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yantra/services/databaseService.dart';
import 'package:yantra/widgets/previewBoxes/userPicture.dart';

class EditProfile extends StatefulWidget {
  final String uid;
  EditProfile({
    this.uid,
  });
  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<EditProfile> {
  final FocusNode myFocusNode = FocusNode();

  String displayPicture;
  String updatedDpPath;
  bool check = true;
  bool isPublic = false;
  TextEditingController _nameController = TextEditingController();
  TextEditingController _bioController = TextEditingController();
  final CollectionReference spacesCollection =
      FirebaseFirestore.instance.collection('spaces');
  final CollectionReference userCollection =
      FirebaseFirestore.instance.collection('users');

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getProfile();
  }

  getProfile() async {
    DocumentSnapshot spaceDoc = await spacesCollection.doc(widget.uid).get();
    isPublic = spaceDoc['public'];
    _nameController.text = spaceDoc['name'];
    _bioController.text = spaceDoc['description'];
    displayPicture = spaceDoc['displayPicture'];
    setState(() {
    });
  }

  void _onImageButtonPressed() async {
    PickedFile pickedFile = await ImagePicker().getImage(source: ImageSource.gallery);
    setState(() {
      updatedDpPath = pickedFile.path;
    });

  }

  void onSavePressed() {
    DatabaseService(uid: widget.uid).updateSpace(widget.uid,
        _nameController.text, _bioController.text, updatedDpPath, isPublic);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(
            'Edit Profile',
            style: TextStyle(color: CupertinoTheme.of(context).primaryColor),
          ),
          backgroundColor: Colors.white,
          iconTheme:
              IconThemeData(color: CupertinoTheme.of(context).primaryColor),
        ),
        floatingActionButton: FloatingActionButton(
          key: UniqueKey(),
          onPressed: () {
            onSavePressed();
          },
          backgroundColor: CupertinoTheme.of(context).primaryColor,
          child: Icon(Icons.check),
        ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Material(
                  elevation: 2,
                  shape: CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: GestureDetector(
                    onTap: () {
                      print('okay');
                      _onImageButtonPressed();
                    },
                    child: Container(
                        width: MediaQuery.of(context).size.width / 2,
                        height: MediaQuery.of(context).size.width / 2,
                        child: (updatedDpPath == null)
                            ? (displayPicture != null)
                                ? UserPicture(displayPicture: displayPicture)
                                : Container()
                            : Image.file(File(updatedDpPath))),
                  ),
                ),
              ),
              new Container(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 25.0),
                  child: new Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Container(
                          padding: EdgeInsets.only(top: 5),
                          child: CupertinoTextField(
                            style: TextStyle(fontSize: 20),
                            padding: EdgeInsets.all(15),
                            controller: _nameController,
                            placeholder: 'Name',
                          )),
                      Container(
                          padding: EdgeInsets.only(top: 10),
                          child: CupertinoTextField(
                            padding: EdgeInsets.all(15),
                            controller: _bioController,
                            style: TextStyle(fontSize: 14),
                            placeholder: 'Bio',
                          )),
                    ],
                  ),
                ),
              ),
              // Container(
              //   padding: EdgeInsets.all(10),
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //     children: [
              //       Text('Account Public'),
              //       CupertinoSwitch(
              //           value: isPublic,
              //           onChanged: (onChanged) {
              //             setState(() {
              //               isPublic = onChanged;
              //             });
              //           })
              //     ],
              //   ),
              // ),
              Divider(),
            ],
          ),
        ));
  }

  @override
  void dispose() {
    // Clean up the controller when the Widget is disposed
    myFocusNode.dispose();
    super.dispose();
  }
}
