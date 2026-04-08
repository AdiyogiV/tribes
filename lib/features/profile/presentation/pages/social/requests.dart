import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:aurogram/core/theme/theme_helper.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/features/notifications/presentation/widgets/space_member_request_tile.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class Requests extends StatefulWidget {
  final String? space; // Made nullable
  const Requests({super.key, this.space});
  @override
  RequestsState createState() => RequestsState();
}

class RequestsState extends State<Requests> {
  User? user = FirebaseAuth.instance.currentUser; // Made nullable

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  void _onRefresh() async {
    if (mounted) setState(() {});
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
            return Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingLg),
              child: Column(
                children: List.generate(5, (_) => const Padding(
                  padding: EdgeInsets.only(bottom: AppDimensions.paddingMd),
                  child: SkeletonListItem(),
                )),
              ),
            );
          }
          var requests = snapshot.data!.docs // Added ! for null safety
              .asMap()
              .map((index, documents) => MapEntry(
                    index,
                    GestureDetector(
                      key: UniqueKey(),
                      onTap: () {
                        if (mounted) setState(() {});
                      },
                      child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          child: SpaceMemberRequestTile(
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
              header: ThemeHelper.refreshHeader,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: Text(
                      getTitle(),
                      style: TextStyle(
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
