import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:tribes/pages/editUserProfile.dart';
import 'package:tribes/services/databaseService.dart';
import 'package:tribes/widgets/Dailogs/loginDailog.dart';

class PostDailog extends StatefulWidget {
  final String? post;
  final String? author;
  PostDailog({this.post, this.author});

  @override
  _PostDailogState createState() => _PostDailogState();
}

class _PostDailogState extends State<PostDailog> {
  User? user = FirebaseAuth.instance.currentUser;

  Widget CancelButton() {
    if (widget.author == user!.uid) {
      return CupertinoActionSheetAction(
        child: Text(
          'Delete',
          style: TextStyle(color: CupertinoColors.destructiveRed),
        ),
        onPressed: () {
          DatabaseService().deleteSpacePost(widget.post!);
          Navigator.of(context).pop();
        },
      );
    }
    return CupertinoActionSheetAction(
      child: Text(
        'Report',
        style: TextStyle(color: CupertinoColors.destructiveRed),
      ),
      onPressed: () {
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return LoginDailog();
    return CupertinoActionSheet(actions: <Widget>[
      CupertinoActionSheetAction(
        child: Text(
          "Share",
          style: TextStyle(color: CupertinoColors.activeBlue),
        ),
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.of(
            context,
            rootNavigator: true,
          ).push(CupertinoPageRoute(builder: (context) {
            return EditProfile(
              uid: widget.post,
            );
          }));
        },
      ),
    ], cancelButton: CancelButton());
  }
}
