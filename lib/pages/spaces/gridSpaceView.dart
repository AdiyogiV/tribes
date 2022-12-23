import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:adiHouse/pages/theatre.dart';
import 'package:adiHouse/widgets/previewBox.dart';

class GridSpaceView extends StatefulWidget {
  final String rid;
  final Function setPageView;
  const GridSpaceView({this.rid, this.setPageView, Key key}) : super(key: key);

  @override
  _GridSpaceViewState createState() => _GridSpaceViewState();
}

class _GridSpaceViewState extends State<GridSpaceView> {
  final CollectionReference spacePostsCollection =
      FirebaseFirestore.instance.collection('spacePosts');
  List<Widget> spacePosts = [];

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
    return Expanded(
        child: SmartRefresher(
      onRefresh: _onRefresh,
      onLoading: _onLoading,
      scrollDirection: Axis.vertical,
      controller: _refreshController,
      header: WaterDropHeader(),
      child: StreamBuilder<QuerySnapshot>(
          stream: spacePostsCollection
              .doc(widget.rid)
              .collection('posts')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }
            spacePosts = snapshot.data.docs
                .asMap()
                .map((index, doc) => MapEntry(
                      index,
                      GestureDetector(
                        key: UniqueKey(),
                        onTap: () {
                          widget.setPageView(index);
                          // Navigator.of(context)
                          //     .push(CupertinoPageRoute(builder: (context) {
                          //   return Theatre(
                          //     initpage: index,
                          //     rid: widget.rid,
                          //   );
                          // }));
                        },
                        child: Container(
                          padding: EdgeInsets.all(5),
                          width: MediaQuery.of(context).size.width / 2,
                          child: PreviewBox(
                            key: UniqueKey(),
                            previewUrl: doc['thumbnail'],
                            title: doc['title'],
                            author: doc['author'],
                          ),
                        ),
                      ),
                    ))
                .values
                .toList();
            return SingleChildScrollView(
                child: Wrap(
              runAlignment: WrapAlignment.end,
              children: spacePosts,
            ));
          }),
    ));
  }
}
