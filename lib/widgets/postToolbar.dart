import 'package:tribes/pages/recorder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PostToolbar extends StatefulWidget {
  final String? postId;

  PostToolbar({
    this.postId,
  });

  @override
  _PostToolbarState createState() => _PostToolbarState();
}

class _PostToolbarState extends State<PostToolbar> {
  User? user = FirebaseAuth.instance.currentUser;
  var inactiveColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: GestureDetector(
            child: Icon(Icons.reply),
            onTap: () {
              {
                Navigator.of(context)
                    .push(CupertinoPageRoute(builder: (builder) {
                  return Recorder(
                    replyTo: widget.postId,
                  );
                }));
              }
            }));
  }
}
