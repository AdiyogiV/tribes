import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:adiHouse/widgets/Dailogs/postDailog.dart';
import 'package:adiHouse/widgets/mainPlayer.dart';

typedef ReplyCallback = void Function(
  String post,
);

class Post extends StatefulWidget {
  final String post;
  final int itemIndex;
  final int itemDepth;
  final ReplyCallback onReplySelected;

  Post(
      {this.post,
      this.itemIndex,
      this.itemDepth,
      this.onReplySelected,
      Key key})
      : super(key: key);

  @override
  _PostState createState() => _PostState();
}

class _PostState extends State<Post> {
  String author;
  String space;
  bool dataloaded = false;
  String video;
  int replyCount;
  bool isReply;
  String replyToUid;
  int replyToPN;
  var replies;
  int upVoteCount;
  int downVoteCount;
  Map upVotes;
  Map downVotes;
  String title;

  final CollectionReference postCollection =
      FirebaseFirestore.instance.collection('posts');
  final CollectionReference votesCollection =
      FirebaseFirestore.instance.collection('votes');

  getPostData() async {
    await postCollection.doc(widget.post).get().then((snapshot) => {
          if (snapshot.exists)
            {
              author = snapshot['author'],
              video = snapshot['video'],
              title = snapshot['title'],
              space = snapshot['space'],
            },
        });
    await votesCollection.doc(widget.post).get().then((snapshot) => {
          if (snapshot.exists)
            {
              upVoteCount = snapshot['upVoteCount'],
              downVoteCount = snapshot['downVoteCount'],
              upVotes = snapshot['upVotes'],
              downVotes = snapshot['downVotes'],
            },
        });

    this.setState(() {
      dataloaded = true;
    });
  }

  @override
  void initState() {
    super.initState();
    getPostData();
  }

  @override
  Widget build(BuildContext context) {
    return _buildpostitem();
  }

  Widget _buildpostitem() {
    return dataloaded
        ? CustomPaint(
            painter: MyPainter(),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Column(
                children: [
                  GestureDetector(
                    onLongPress: () {
                      showCupertinoModalPopup(
                          context: context,
                          builder: (BuildContext context) => PostDailog(
                                post: widget.post,
                                author: author,
                              ));
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10.0),
                      child: Material(
                        elevation: 5,
                        child: MainPlayer(
                          postId: widget.post,
                          space: space,
                          author: author,
                          videoUrl: video,
                          title: title,
                          pageIndex: widget.itemIndex,
                          pageDepth: widget.itemDepth,
                          upVoteCount: upVoteCount,
                          downVoteCount: downVoteCount,
                          upVotes: upVotes,
                          downVotes: downVotes,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: Container()),
                ],
              ),
            ),
          )
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(100.0),
              child: CircularProgressIndicator(),
            ),
          );
  }
}

class MyPainter extends CustomPainter {
  //         <-- CustomPainter class
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Offset(30, 5);
    final p4 = Offset(30, size.height + 100);

    final paint = Paint()
      ..color = Colors.amber[700]
      ..strokeWidth = 1;
    canvas.drawLine(p1, p4, paint);
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return false;
  }
}
