import 'package:flutter/material.dart';
import 'package:yantra/pages/theatre.dart';
import 'package:yantra/services/databaseService.dart';
import 'package:yantra/widgets/orignal.dart';
import 'package:yantra/widgets/post.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yantra/widgets/reply.dart';

class PostSwitcher extends StatefulWidget {
  final String postId;
  final int itemIndex;

  final CollectionReference postCollection =
      FirebaseFirestore.instance.collection('posts');

  final CollectionReference postRepliesCollection =
      FirebaseFirestore.instance.collection('postReplies');
  PostSwitcher({this.postId, this.itemIndex});

  @override
  _PostSwitcherState createState() => _PostSwitcherState();
}

class _PostSwitcherState extends State<PostSwitcher> {
  bool isReply;
  int depth;
  var replyTo;
  QuerySnapshot repliesDoc;
  int replyCount = 0;

  List<Widget> pages = <Widget>[];
  @override
  void initState() {
    super.initState();
    getStuff(widget.postId);
  }

  getStuff(String post) async {
    List<Widget> _pages = <Widget>[];
    repliesDoc = null;
    repliesDoc = await widget.postRepliesCollection
        .doc(post)
        .collection('replies')
        .orderBy('timestamp', descending: false)
        .get();
    replyCount = repliesDoc.docs.length;
    repliesDoc.docs.forEach((element) {
      _pages.insert(
          0,
          Reply(
              post: element.id,
              onReplySelected: onReplySelected,
              key: UniqueKey()));
    });
    _pages.add(Post(
        post: post,
        itemIndex: widget.itemIndex,
        itemDepth: depth,
        onReplySelected: onReplySelected,
        key: UniqueKey()));
    await getTree(post, 0, _pages);
    setState(() {
      pages = _pages;
    });
  }

  getTree(String postId, int depth, List<Widget> _pages) async {
    DocumentSnapshot postDoc = await DatabaseService().getPost(postId);
    String replyTo = postDoc['replyTo'];
    if (replyTo == null || replyTo.isEmpty) {
      return;
    }
    _pages.add(Orignal(
        post: replyTo, onReplySelected: onReplySelected, key: UniqueKey()));

    await getTree(replyTo, depth + 1, _pages);
  }

  onReplySelected(String postId) async {
    await getStuff(postId);
    Provider.of<PageIndexHolder>(context, listen: false).setPost(postId);
  }

  currentStack() {
    return Container(
      child: PageView(
          key: ObjectKey(pages),
          scrollDirection: Axis.vertical,
          controller:
              PageController(viewportFraction: 0.8, initialPage: replyCount),
          reverse: true,
          onPageChanged: (page) {
            setState(() {
              Provider.of<PageIndexHolder>(context, listen: false)
                  .setDepth(page);
            });
          },
          children: pages),
    );
  }

  @override
  Widget build(BuildContext context) {
    return currentStack();
  }
}
