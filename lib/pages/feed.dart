import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:tribes/services/algoliaService.dart';

class Feed extends StatefulWidget {
  @override
  _FeedState createState() => _FeedState();
}

class _FeedState extends State<Feed> {
  final CollectionReference feedCollection =
      FirebaseFirestore.instance.collection('feed');
  final CollectionReference postCollection =
      FirebaseFirestore.instance.collection('posts');
  final CollectionReference votesCollection =
      FirebaseFirestore.instance.collection('votes');
  User? user = FirebaseAuth.instance.currentUser;
  List<Widget> postView = <Widget>[];
  RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
  }

  onRefresh() async {
    _refreshController.refreshCompleted();
    setState(() {});
  }

  feedPosts() {
    return FutureBuilder(
        future: AlgoliaService().getPosts(''),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          return Container();
        });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(child: SafeArea(child: feedPosts()));
  }
}
