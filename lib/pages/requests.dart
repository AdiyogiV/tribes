import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:yantra/widgets/notifications/followRequestTile.dart';
import 'package:yantra/widgets/previewBoxes/userPicture.dart';
import 'package:yantra/widgets/previewBoxes/userPreviewBox.dart';

class Requests extends StatefulWidget {
  const Requests({Key key}) : super(key: key);
  @override
  _RequestsState createState() => _RequestsState();
}

class _RequestsState extends State<Requests> {
  User user = FirebaseAuth.instance.currentUser;


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
  int gp = 0;

  void _onRefresh() async {
    setState(() {

    });
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    _refreshController.loadComplete();
  }



  String getTitle() {
    switch (gp) {
      case 0:
        {
          return 'FOLLOW REQUESTS';
        }
        break;

      case 1:
        {
          return 'SPACE REQUESTS';
        }
        break;

      default:
        {
          return 'PEOPLE';
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('spaceRoles')
            .doc(user.uid)
            .collection('roles')
            .where('role', isEqualTo: 'requested')
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          var requests = snapshot.data.docs
              .asMap()
              .map((index, doc) => MapEntry(
                    index,
                    GestureDetector(
                      key: UniqueKey(),
                      onTap: () {
                        setState(() {

                        });
                      },
                      child: Container(
                          width: MediaQuery.of(context).size.width,
                          child: FollowRequestTile(
                            uid: doc.id,
                          )),
                    ),
                  ))
              .values
              .toList();
          return Scaffold(
            body: SmartRefresher(
              onRefresh: _onRefresh,
              onLoading: _onLoading,
              enablePullDown: true,
              controller: _refreshController,
              header: WaterDropMaterialHeader(
                color: Colors.white,
                backgroundColor: CupertinoTheme.of(context).primaryColor,
                distance: 100,
              ),
              child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      shape: ContinuousRectangleBorder(
                          borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(1),
                              bottomRight: Radius.circular(1))),
                      title: Text(
                        getTitle(),
                        style: TextStyle(
                          color: CupertinoTheme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      floating: true,
                      stretch: true,
                      elevation: 4,
                      forceElevated: true,
                      flexibleSpace: Container(
                        decoration: BoxDecoration(
                          gradient: new LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white70,
                              ],
                              begin: const FractionalOffset(0.0, 0.0),
                              end: const FractionalOffset(0.0, 1),
                              stops: [0.0, 1],
                              tileMode: TileMode.mirror),
                        ),
                      ),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.all(7.0),
                          child: CupertinoSlidingSegmentedControl(
                            padding: EdgeInsets.all(4),
                            onValueChanged: (value) {
                              gp = value;
                              setState(() {});
                            },
                            groupValue: gp,
                            children: spaceTypes,
                            backgroundColor: Colors.black12,
                            thumbColor: Colors.white,
                          ),
                        ),
                      ],
                      iconTheme: IconThemeData(color: CupertinoTheme.of(context).primaryColor),
                    ),
                  SliverToBoxAdapter(
                    child: (gp==0)? Wrap(
                      children: requests,
                    ): Container(),
                  ),
                ],
              ),
            ),
          );
        });
  }
}
