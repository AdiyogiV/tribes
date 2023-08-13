import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:tribes/widgets/notifications/followRequestTile.dart';

class Requests extends StatefulWidget {
  final String? space; // Made nullable
  const Requests({Key? key, this.space}) : super(key: key);
  @override
  _RequestsState createState() => _RequestsState();
}

class _RequestsState extends State<Requests> {
  User? user = FirebaseAuth.instance.currentUser; // Made nullable

  RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  final Map<int, Widget> spaceTypes = {
    0: Padding(
      padding: const EdgeInsets.all(5.0),
      child: Icon(
        Icons.people,
      ),
    ),
    1: Padding(
      padding: const EdgeInsets.all(5.0),
      child: Icon(
        Icons.blur_on_rounded,
      ),
    ),
  };

  void _onRefresh() async {
    setState(() {});
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    _refreshController.loadComplete();
  }

  String getTitle() {
    return 'Requests';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('spaceRoles')
            .doc(widget.space)
            .collection('roles')
            .where('role', isEqualTo: 'requested')
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          var requests = snapshot.data!.docs // Added ! for null safety
              .asMap()
              .map((index, documents) => MapEntry(
                    index,
                    GestureDetector(
                      key: UniqueKey(),
                      onTap: () {
                        setState(() {});
                      },
                      child: Container(
                          width: MediaQuery.of(context).size.width,
                          child: FollowRequestTile(
                            space: widget.space!,
                            uid: documents.id,
                            onRefresh: _onRefresh,
                          )),
                    ),
                  ))
              .values
              .toList();
          return Scaffold(
            backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
            body: SmartRefresher(
              onRefresh: _onRefresh,
              onLoading: _onLoading,
              enablePullDown: true,
              controller: _refreshController,
              header: WaterDropMaterialHeader(
                color: Colors.white,
                distance: 100,
              ),
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: Text(
                      getTitle(),
                      style: TextStyle(
                        color: CupertinoTheme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    iconTheme: IconThemeData(
                        color: CupertinoTheme.of(context).primaryColor),
                  ),
                  SliverToBoxAdapter(
                    child: Wrap(
                      children: requests,
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }
}
