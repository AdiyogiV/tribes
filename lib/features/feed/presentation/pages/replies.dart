import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:aurogram/core/theme/theme_helper.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/features/feed/presentation/pages/theatre.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class Replies extends StatefulWidget {
  const Replies({super.key});

  @override
  RepliesState createState() => RepliesState();
}

class RepliesState extends State<Replies> {
  User? user = FirebaseAuth.instance.currentUser;
  final CollectionReference userRepliesCollection =
      FirebaseFirestore.instance.collection('userReplies');

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  void _onRefresh() async {
    // monitor network fetch\
    // if failed,use refreshFailed()
    if (mounted) setState(() {});
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
      header: ThemeHelper.refreshHeader,
      child: StreamBuilder<QuerySnapshot>(
          stream: userRepliesCollection
              .doc(user!.uid)
              .collection('replies')
              .orderBy(
                'timestamp',
              )
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingLg),
                child: Column(
                  children: List.generate(3, (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: SkeletonCard(),
                  )),
                ),
              );
            }
            return Theatre(
              initpage: 0,
              rid: user!.uid,
            );
          }),
    );
  }
}
