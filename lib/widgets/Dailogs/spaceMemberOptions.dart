import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yantra/pages/editUserProfile.dart';
import 'package:yantra/services/authService.dart';

class SpaceMemberOptions extends StatefulWidget {
  final String space;
  final String uid;
  SpaceMemberOptions({this.space, this.uid,});

  @override
  _SpaceMemberOptionsState createState() => _SpaceMemberOptionsState();
}

class _SpaceMemberOptionsState extends State<SpaceMemberOptions> {
  @override
  Widget build(BuildContext context) {

    return CupertinoActionSheet(
        actions: <Widget>[
          CupertinoActionSheetAction(
            child: Text(
              "Make an owner",
              style: TextStyle(color: CupertinoColors.activeBlue),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();

            },
          ),

        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(
            'Remove from space',
            style: TextStyle(color: CupertinoColors.destructiveRed),
          ),
          onPressed: () {
            Provider.of<AuthService>(context, listen: false).signOut();
            Navigator.of(context).pop();
          },
        ));
  }
}
