import 'package:cloud_firestore/cloud_firestore.dart' show QuerySnapshot;
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/theme/theme_helper.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/preview_box.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class GridSpaceView extends StatefulWidget {
  final String? rid;
  final Function? setPageView;
  const GridSpaceView({this.rid, this.setPageView, super.key});

  @override
  GridSpaceViewState createState() => GridSpaceViewState();
}

class GridSpaceViewState extends State<GridSpaceView> {
  List<Widget> spacePosts = [];
  late Stream<QuerySnapshot> _postsStream;

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    _postsStream = locator<PostDbService>()
        .streamPostsBySpace(widget.rid ?? '');
  }

  @override
  void didUpdateWidget(GridSpaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rid != widget.rid) {
      _postsStream = locator<PostDbService>()
          .streamPostsBySpace(widget.rid ?? '');
    }
  }

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
          stream: _postsStream,
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
