import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:adiHouse/pages/requests.dart';
import 'package:adiHouse/widgets/notifications/followTile.dart';
import 'package:adiHouse/widgets/notifications/replyTile.dart';

class Notifications extends StatefulWidget {
  @override
  _NotificationsState createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  final CollectionReference notificationsCollection =
      FirebaseFirestore.instance.collection('notifications');
  User user = FirebaseAuth.instance.currentUser;
  Map notifics;
  int count;
  RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  List<Widget> itemList = <Widget>[];

  @override
  void initState() {
    super.initState();
    getNotifications();
  }

  getLogo() {
    return Image.asset(
      'assets/images/adidaslogo.png',
      fit: BoxFit.contain,
    );
  }

  getNotifications() async {
    List<Widget> _itemView = <Widget>[];
    await notificationsCollection.doc(user.uid).get().then((value) => {
          notifics = value['notifications'],
          count = value['count'],
          for (int i = notifics.length; i > 0; i--)
            {
              if (notifics['$i']['type'] == 'reply')
                {
                  _itemView.add(ReplyTile(
                    data: notifics['$i'],
                  ))
                }
              // else if (notifics['$i']['type'] == 'follow')
              //   {_itemView.add(FollowTile())}
            },
          setState(() {
            itemList = _itemView;
          })
        });
  }

  void _onRefresh() async {
    getNotifications();
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    _refreshController.loadComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SmartRefresher(
            onRefresh: _onRefresh,
            onLoading: _onLoading,
            enablePullDown: true,
            controller: _refreshController,
            header: WaterDropHeader(),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(1),
                          bottomRight: Radius.circular(1))),
                  title: Container(height: 90, child: getLogo()),
                  backgroundColor: Colors.transparent,
                  floating: true,
                  stretch: true,
                  expandedHeight: 120,
                  collapsedHeight: 100,
                  elevation: 4,
                  forceElevated: true,
                  flexibleSpace: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(1),
                          bottomRight: Radius.circular(1)),
                      gradient: new LinearGradient(
                          colors: [
                            Colors.black,
                            Colors.black54,
                          ],
                          begin: const FractionalOffset(0.0, 0.0),
                          end: const FractionalOffset(0.0, 1),
                          stops: [0.0, 1],
                          tileMode: TileMode.mirror),
                    ),
                    child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Text(
                          'notifications',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w200),
                          textAlign: TextAlign.center,
                        )),
                  ),
                  iconTheme: IconThemeData(
                      color: CupertinoTheme.of(context).primaryColor),
                ),
                SliverToBoxAdapter(
                    child: Wrap(
                  children: itemList,
                ))
              ],
            ),
          ),
        ));
  }
}
