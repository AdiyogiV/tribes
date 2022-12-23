import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adiHouse/pages/editUserProfile.dart';
import 'package:adiHouse/services/authService.dart';

class ProfileOptions extends StatefulWidget {
  final String uid;
  ProfileOptions({
    this.uid,
  });

  @override
  _ProfileOptionsState createState() => _ProfileOptionsState();
}

class _ProfileOptionsState extends State<ProfileOptions> {
  @override
  Widget build(BuildContext context) {
    return CupertinoActionSheet(
        actions: <Widget>[
          CupertinoActionSheetAction(
            child: Text(
              "Edit Profile",
              style: TextStyle(color: CupertinoColors.activeBlue),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(
                context,
                rootNavigator: true,
              ).push(CupertinoPageRoute(builder: (context) {
                return EditProfile(
                  uid: widget.uid,
                );
              }));
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(
            'Log Out',
            style: TextStyle(color: CupertinoColors.destructiveRed),
          ),
          onPressed: () {
            Provider.of<AuthService>(context, listen: false).signOut();
            Navigator.of(context).pop();
          },
        ));
  }
}
