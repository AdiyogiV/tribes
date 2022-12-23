import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:adiHouse/services/databaseService.dart';
import 'package:adiHouse/widgets/mainPlayer.dart';
import 'package:adiHouse/widgets/postReplies.dart';

typedef ReplyCallback = void Function(
  String postId,
);

class Reply extends StatefulWidget {
  final String post;
  final ReplyCallback onReplySelected;

  Reply({this.post, this.onReplySelected, Key key}) : super(key: key);

  @override
  _ReplyState createState() => _ReplyState();
}

class _ReplyState extends State<Reply> {
  String author;
  String space;
  bool dataloaded = false;
  String video;
  String title;

  getReplyData() async {
    DocumentSnapshot replyDoc = await DatabaseService().getPost(widget.post);
    author = replyDoc['author'];
    video = replyDoc['video'];
    title = replyDoc['title'];
    space = replyDoc['space'];
    this.setState(() {
      dataloaded = true;
    });
  }

  @override
  void initState() {
    super.initState();
    getReplyData();
  }

  @override
  Widget build(BuildContext context) {
    return _buildpostitem();
  }

  Widget _buildpostitem() {
    return CustomPaint(
      painter: MyPainter(),
      child: dataloaded
          ? Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  Expanded(flex: 1, child: Container()),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            widget.onReplySelected(widget.post);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.0),
                            child: MainPlayer(
                              postId: widget.post,
                              space: space,
                              author: author,
                              videoUrl: video,
                              title: title,
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: PostReplies(
                            onReplySelected: widget.onReplySelected,
                            post: widget.post,
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Container(),
    );
  }
}

class MyPainter extends CustomPainter {
  //         <-- CustomPainter class
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Offset(30, 0);
    final p2 = Offset(30, 35);
    final p3 = Offset(size.width / 2, 35);
    final p4 = Offset(30, size.height + 100);

    final paint = Paint()
      ..color = Colors.amber[700]
      ..strokeWidth = 1;
    canvas.drawLine(p3, p2, paint);
    canvas.drawLine(p1, p4, paint);
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return false;
  }
}
