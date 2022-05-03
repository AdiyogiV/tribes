import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:yantra/pages/theatre.dart';
import 'package:yantra/widgets/previewBox.dart';

class Replies extends StatefulWidget {
  @override
  _RepliesState createState() => _RepliesState();
}

class _RepliesState extends State<Replies> {
  User user = FirebaseAuth.instance.currentUser;
  final CollectionReference userRepliesCollection =
      FirebaseFirestore.instance.collection('userReplies');

  RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  void _onRefresh() async {
    // monitor network fetch\
    // if failed,use refreshFailed()
    setState(() {});
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    // monitor network fetch
    // if failed,use loadFailed(),if no data return,use LoadNodata()
    _refreshController.loadComplete();
  }

  @override
  Widget build(BuildContext context) {
    return SmartRefresher(
      reverse: true,
      onRefresh: _onRefresh,
      onLoading: _onLoading,
      enablePullDown: true,
      controller: _refreshController,
      header: WaterDropHeader(),
      child: StreamBuilder<QuerySnapshot>(
          stream: userRepliesCollection
              .doc(user.uid)
              .collection('replies')
              .orderBy(
                'timestamp',
              )
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }
            return Theatre(
              initpage: 0,
              rid: user.uid,
            );
          }),
    );
  }
}
