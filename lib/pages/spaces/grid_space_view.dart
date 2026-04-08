import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:aurogram/utils/theme/theme_helper.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/widgets/preview_boxes/preview_box.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

class GridSpaceView extends StatefulWidget {
  final String? rid;
  final Function? setPageView;
  const GridSpaceView({this.rid, this.setPageView, super.key});

  @override
  GridSpaceViewState createState() => GridSpaceViewState();
}

class GridSpaceViewState extends State<GridSpaceView> {
  final CollectionReference postsCollection =
      FirebaseFirestore.instance.collection('posts');
  List<Widget> spacePosts = [];

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
      onRefresh: _onRefresh,
      onLoading: _onLoading,
      scrollDirection: Axis.vertical,
      controller: _refreshController,
      header: ThemeHelper.refreshHeader,
      child: StreamBuilder<QuerySnapshot>(
          stream: postsCollection
              .where('space', isEqualTo: widget.rid)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return GridView.builder(
                padding: const EdgeInsets.all(AppDimensions.paddingSm),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: 9,
                itemBuilder: (_, __) => SkeletonGridItem(),
              );
            }
            spacePosts = snapshot.data!.docs
                .asMap()
                .map((index, documents) => MapEntry(
                      index,
                      GestureDetector(
                        key: UniqueKey(),
                        onTap: () {
                          widget.setPageView!(index);
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
                            previewUrl: (documents.data()
                                        as Map<String, dynamic>?)?['thumbnail']
                                    as String? ??
                                '',
                            title: (documents.data()
                                as Map<String, dynamic>?)?['title'] as String?,
                            author: (documents.data()
                                as Map<String, dynamic>?)?['author'] as String?,
                            content: (documents.data()
                                    as Map<String, dynamic>?)?['content']
                                as String?,
                            postType: (documents.data()
                                    as Map<String, dynamic>?)?['postType']
                                as String?,
                            uploading: (documents.data()
                                    as Map<String, dynamic>?)?['uploading']
                                as bool? ?? false,
                            audioUrl: (documents.data()
                                    as Map<String, dynamic>?)?['audioUrl']
                                as String?,
                            durationInSeconds: (documents.data()
                                    as Map<String, dynamic>?)?['duration']
                                as int?,
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
    );
  }
}
