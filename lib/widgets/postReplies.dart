import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adiHouse/pages/login.dart';
import 'package:adiHouse/widgets/previewBox.dart';

typedef ReplyCallback = void Function(String postId);

class PostReplies extends StatefulWidget {
  final String post;
  final String space;
  final ReplyCallback onReplySelected;

  PostReplies({this.post, this.onReplySelected, this.space});

  @override
  _PostRepliesState createState() => _PostRepliesState();
}

class _PostRepliesState extends State<PostReplies> {
  List<Widget> replies = <Widget>[];
  User user = FirebaseAuth.instance.currentUser;
  final CollectionReference postRepliesCollection =
      FirebaseFirestore.instance.collection('postReplies');
  final CollectionReference votesCollection =
      FirebaseFirestore.instance.collection('votes');

  @override
  Widget build(BuildContext context) {
    return _buildReply(context);
  }

  @override
  void initState() {
    super.initState();
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

  Widget _buildReply(BuildContext context) {
    return Container(
        child: FutureBuilder<QuerySnapshot>(
            future: postRepliesCollection
                .doc(widget.post)
                .collection('replies')
                .orderBy('timestamp', descending: true)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container();
              }
              replies = snapshot.data.docs
                  .asMap()
                  .map((index, doc) => MapEntry(
                      index,
                      Container(
                          child: GestureDetector(
                        key: UniqueKey(),
                        onTap: () {
                          widget.onReplySelected(doc.id);
                        },
                        child: Container(
                          width: MediaQuery.of(context).size.width / 4,
                          child: CustomPaint(
                            painter: MyPainter(),
                            child: PreviewBox(
                              key: UniqueKey(),
                              previewUrl: doc['thumbnail'],
                              title: doc['title'],
                              author: doc['author'],
                            ),
                          ),
                        ),
                      ))))
                  .values
                  .toList();

              return Container(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: replies,
                  ),
                ),
              );
            }));
  }
}

class MyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Offset(size.width / 2, 0);
    final p2 = Offset(size.width / 2, 5);

    final paint = Paint()
      ..color = Colors.blue[600]
      ..strokeWidth = 1;
    canvas.drawLine(p1, p2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return false;
  }
}
