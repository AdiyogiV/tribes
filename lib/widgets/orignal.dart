import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yantra/widgets/mainPlayer.dart';
import 'package:yantra/widgets/postReplies.dart';

typedef OrignalCallback = void Function(
  String postId,
);

class Orignal extends StatefulWidget {
  final String post;
  final ReplyCallback onReplySelected;

  Orignal({this.post, this.onReplySelected, Key key}) : super(key: key);

  @override
  _OrignalState createState() => _OrignalState();
}

class _OrignalState extends State<Orignal> {
  String author;
  String space;
  bool dataloaded = false;
  String video;
  String title;

  final CollectionReference postCollection =
      FirebaseFirestore.instance.collection('posts');

  getOrignalData() async {
    await postCollection.doc(widget.post).get().then((snapshot) => {
          if (snapshot.exists)
            {
              author = snapshot['author'],
              video = snapshot['video'],
              title = snapshot['title'],
              space = snapshot['space'],
            },
        });

    this.setState(() {
      dataloaded = true;
    });
  }

  @override
  void initState() {
    super.initState();
    getOrignalData();
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
                        Row(
                          children: [
                            Expanded(flex: 1, child: Container()),
                            Expanded(
                                flex: 6,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: PostReplies(
                                    onReplySelected: widget.onReplySelected,
                                    post: widget.post,
                                  ),
                                )),
                          ],
                        )
                      ],
                    ),
                  ),
                  Expanded(flex: 1, child: Container())
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
    final p1 = Offset(30, -100);
    final p2 = Offset(30, size.height + 2);
    final paint = Paint()
      ..color = Colors.indigo[700]
      ..strokeWidth = 1;
    canvas.drawLine(p1, p2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return false;
  }
}
