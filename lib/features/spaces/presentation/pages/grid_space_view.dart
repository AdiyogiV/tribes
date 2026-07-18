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
  late Stream<QuerySnapshot> _postsStream;

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    _postsStream =
        locator<PostDbService>().streamPostsBySpace(widget.rid ?? '');
  }

  @override
  void didUpdateWidget(GridSpaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rid != widget.rid) {
      _postsStream =
          locator<PostDbService>().streamPostsBySpace(widget.rid ?? '');
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
  void dispose() {
    _refreshController.dispose();
    super.dispose();
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
            final documents = snapshot.data!.docs;
            return GridView.builder(
              padding: const EdgeInsets.all(AppDimensions.paddingSm),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final document = documents[index];
                final data =
                    document.data() as Map<String, dynamic>? ?? const {};
                return GestureDetector(
                  key: ValueKey(document.id),
                  onTap: () => widget.setPageView?.call(index),
                  child: PreviewBox(
                    key: ValueKey('preview-${document.id}'),
                    previewUrl: data['thumbnail'] as String? ?? '',
                    title: data['title'] as String?,
                    author: data['author'] as String?,
                    content: data['content'] as String?,
                    postType: data['postType'] as String?,
                    uploading: data['uploading'] as bool? ?? false,
                    audioUrl: data['audioUrl'] as String?,
                    durationInSeconds: data['duration'] as int?,
                  ),
                );
              },
            );
          }),
    );
  }
}
