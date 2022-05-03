import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:yantra/services/authService.dart';
import 'package:yantra/services/databaseService.dart';

class InitUser extends StatefulWidget {
  @override
  _InitUserState createState() => _InitUserState();
}

class _InitUserState extends State<InitUser> {
  TextEditingController _nameController = TextEditingController();
  TextEditingController _nicknameController = TextEditingController();

  String nickname;
  File displayPicture;
  bool availability = true;
  bool hasSpaces = false;
  String phoneNo;
  User user = FirebaseAuth.instance.currentUser;
  bool check = false;

  final CollectionReference nicknamesCollection =
      FirebaseFirestore.instance.collection('nicknames');
  DocumentSnapshot _snap;

  @override
  void initState() {
    super.initState();
    nicknamesCollection.doc('pairs').get().then((snapshot) => {
          if (snapshot.exists) {_snap = snapshot}
        });
  }


  checkAvailability() async {
    if (_snap.exists) {
      if (_snap[nickname] ?? false ) {
        setState(() {
          availability = false;
        });
      } else {
        setState(() {
          availability = true;
        });
      }
    }
  }

  bool checkDetails() {
    if (displayPicture != null &&
        check &&
        _nameController.text.isNotEmpty &&
        _nicknameController.text.isNotEmpty &&
        !_nicknameController.text.contains(' ')) {
      return true;
    } else
      return false;
  }

  Future<bool> onFinishPressed() async {
    if (checkDetails()) {
      return await DatabaseService(uid: user.uid).registerNewUser(
          _nameController.text, _nicknameController.text, displayPicture.path);
    } else {
      return false;
    }
  }

  @override
  void dispose() {
    super.dispose();
    _nicknameController?.dispose();
    _nameController?.dispose();
  }

  void _onImageButtonPressed() async {
    try {
      final pickedFile =
      await ImagePicker().getImage(source: ImageSource.gallery);
      displayPicture = File(pickedFile.path);
      setState(() {
      });
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      resizeToAvoidBottomInset: false,
      floatingActionButton:
          Consumer<AuthService>(builder: (context, auth, child) {
        return FloatingActionButton.extended(
          onPressed: () async {
            if (await onFinishPressed()) {
              auth.handleStatus(false);
            } else {
              print('unsuccessful');
            }
          },
          backgroundColor: checkDetails()
              ? CupertinoTheme.of(context).primaryColor
              : CupertinoColors.systemGrey,
          icon: Icon(Icons.arrow_right_alt),
          label: Text('WELCOME'),
        );
      }),
      body: SafeArea(
        child: Form(
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Material(
                    elevation: 5,
                    shape: CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: GestureDetector(
                      onTap: () {
                        _onImageButtonPressed();
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width / 2,
                        height: MediaQuery.of(context).size.width / 2,
                        child: (displayPicture != null)
                            ? Image.file(
                                displayPicture,
                                fit: BoxFit.cover,
                              )
                            : Image.asset('assets/images/user.png'),
                      ),
                    ),
                  ),
                ),
                Divider(),
                Container(
                    padding: EdgeInsets.only(top: 5),
                    child: CupertinoTextField(
                      padding: EdgeInsets.all(15),
                      controller: _nameController,
                      placeholder: 'Name',
                    )),
                Container(
                    padding: EdgeInsets.only(top: 10),
                    child: CupertinoTextField(
                      padding: EdgeInsets.all(15),
                      controller: _nicknameController,
                      onChanged: (value) {
                        if (_nicknameController.text.contains(" ")) {
                          setState(() {
                            hasSpaces = true;
                          });
                        } else {
                          setState(() {
                            hasSpaces = false;
                            nickname = value;
                          });
                          checkAvailability();
                        }
                      },
                      placeholder: 'Unique Nickname',
                    )),
                if (_nicknameController.text.isNotEmpty)
                  hasSpaces
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Nickname must not contain spaces',
                            style: TextStyle(
                                color: CupertinoColors.destructiveRed),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(8),
                          child: availability
                              ? Row(
                                  children: <Widget>[
                                    Icon(
                                      CupertinoIcons.check_mark_circled_solid,
                                      color: CupertinoColors.activeGreen,
                                    ),
                                    Container(
                                      width: 5,
                                    ),
                                    Text(
                                      'Available',
                                      style: TextStyle(
                                          color: CupertinoColors.activeGreen),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: <Widget>[
                                    Icon(
                                      CupertinoIcons.clear_circled_solid,
                                      color: CupertinoColors.destructiveRed,
                                      size: 25,
                                    ),
                                    Container(
                                      width: 5,
                                    ),
                                    Text(
                                      'Not Available',
                                      style: TextStyle(
                                          color:
                                              CupertinoColors.destructiveRed),
                                    ),
                                  ],
                                )),
                Divider(),
                Container(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          'I acknowledge that I am 18 years \nor older, and I accept the user agreement.'),
                      CupertinoSwitch(
                          value: check,
                          onChanged: (onChanged) {
                            setState(() {
                              check = onChanged;
                            });
                          })
                    ],
                  ),
                ),
                Divider()
              ],
            ),
          ),
        ),
      ),
    );
  }
}
