import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:yantra/pages/requests.dart';
import 'package:yantra/widgets/notifications/followTile.dart';
import 'package:yantra/widgets/notifications/replyTile.dart';

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

  getNotifications() async {
    List<Widget> _itemView = <Widget>[];
    await notificationsCollection.doc(user.uid).get().then((value) => {
          print(value),
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
              else if (notifics['$i']['type'] == 'follow')
                {_itemView.add(FollowTile())}
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
        body: SafeArea(
      child: SmartRefresher(
          onRefresh: _onRefresh,
          onLoading: _onLoading,
          enablePullDown: true,
          controller: _refreshController,
          header: WaterDropHeader(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context)
                        .push(CupertinoPageRoute(builder: (context) {
                      return Requests();
                    }));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        gradient: new LinearGradient(
                            colors: [
                              const Color(0xFF3366FF),
                              const Color(0xFF00CCFF),
                            ],
                            begin: const FractionalOffset(0.0, 0.0),
                            end: const FractionalOffset(1.0, 0.0),
                            stops: [0.0, 1.0],
                            tileMode: TileMode.clamp),
                        //color: CupertinoTheme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black,
                              offset: Offset(0, 0),
                              blurRadius: 2),
                        ]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_add,
                          color: Colors.white,
                        ),
                        Expanded(
                            child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Text(
                            'Follow Requests',
                            style: TextStyle(color: Colors.white),
                          ),
                        )),
                        Icon(
                          Icons.arrow_right_alt,
                          color: Colors.white,
                          size: 40,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )),
    ));
  }
}
