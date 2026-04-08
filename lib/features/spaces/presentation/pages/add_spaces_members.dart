import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drag_select_grid_view/drag_select_grid_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:aurogram/shared/services/search_service.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/crew_preview.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class AddSpacesMember extends StatefulWidget {
  final String? space;
  final spaceMembers;
  const AddSpacesMember({super.key, required this.space, this.spaceMembers});

  @override
  AddSpacesMemberState createState() => AddSpacesMemberState();
}

class AddSpacesMemberState extends State<AddSpacesMember> {
  User? user = FirebaseAuth.instance.currentUser;
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  final controller = DragSelectGridViewController();
  List<Widget> suggestions = [];
  final SearchService _searchService = SearchService();
  TextEditingController? _textController;
  String? link;
  late String space;
  String? userName;
  String? spaceName;
  File? spacePicture;

  @override
  void initState() {
    super.initState();
    getData();
    controller.addListener(rebuild);
  }

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    controller.removeListener(rebuild);
    _focusNode.dispose();
    super.dispose();
  }

  void rebuild() => {if (mounted) setState(() {})};
  void _onRefresh() async {
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    _refreshController.loadComplete();
  }

  Future<void> getData() async {
    try {
      DocumentSnapshot authordocuments =
          await DatabaseService().getUser(user!.uid);
      if (authordocuments.exists) {
        userName = authordocuments['name'] as String?;
      }
      DocumentSnapshot spacedocuments =
          await DatabaseService().getSpace(widget.space!);
      if (spacedocuments.exists) {
        spaceName = spacedocuments['name'] as String?;
        if ((spacedocuments['displayPicture'] as String?) != '') {
          final cacheService = locator<CacheService>();
          spacePicture = await cacheService
              .getFile(spacedocuments['displayPicture'] as String);
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.e('Error loading data',
          category: LogCategory.general, error: e);
    }
  }

  // getFloatingButton() {
  //   return FloatingActionButton.extended(
  //     onPressed: () {
  //       spacePicture != null
  //           ? Share.shareFiles(
  //               [
  //                 spacePicture!.path
  //               ], // Ensure spacePicture is not null before accessing path
  //               text: link!,
  //               subject:
  //                   '$userName invited to join the $spaceName space on Aurogram',
  //             )
  //           : Share.share(
  //               link!,
  //               subject:
  //                   '$userName invited to join the $spaceName space on Aurogram',
  //             );
  //     },
  //     backgroundColor: CupertinoTheme.of(context).primaryColor,
  //     icon: Icon(Icons.share),
  //     label: Text('Share Link'),
  //   );
  // }

  Future<void> getUsers(String input) async {
    if (input.trim().isEmpty) {
      // Do not show any users by default; only show when searching
      suggestions = [];
      if (mounted) setState(() {});
      return;
    }
    try {
      // Use centralized search service
      final results = await _searchService.searchUsers(input, limit: 50);

      suggestions = results
          .asMap()
          .map(
            (index, doc) => MapEntry(
              index,
              CrewPreview(
                key: UniqueKey(),
                user: doc.id,
                space: widget.space,
              ),
            ),
          )
          .values
          .toList();
    } catch (e) {
      AppLogger.e('Error in add spaces members',
          category: LogCategory.general, data: {'error': e.toString()});
    }
    if (mounted) setState(() {});
  }

  SliverAppBar _getAppBar(BuildContext context) {
    return SliverAppBar(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16))),
      title: Text('Add Members',
          style: TextStyle(
              color: CupertinoTheme.of(context).textTheme.textStyle.color,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3)),
      backgroundColor: Colors.white,
      floating: true,
      stretch: true,
      expandedHeight: 120,
      collapsedHeight: 100,
      elevation: 0,
      flexibleSpace: _getFlexibleSpace(context),
      iconTheme: IconThemeData(color: CupertinoTheme.of(context).primaryColor),
    );
  }

  Container _getFlexibleSpace(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 95.0),
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: CupertinoSearchTextField(
                backgroundColor: Colors.transparent,
                itemColor:
                    CupertinoTheme.of(context).textTheme.textStyle.color!,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                placeholder: 'Search members...',
                placeholderStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                ),
                focusNode: _focusNode,
                onChanged: (query) {
                  if (query.trim().isEmpty) {
                    suggestions = [];
                    if (mounted) setState(() {});
                  } else {
                    getUsers(query);
                  }
                },
                controller: _textController,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: SmartRefresher(
        controller: _refreshController,
        onLoading: _onLoading,
        onRefresh: _onRefresh,
        header: WaterDropMaterialHeader(
          color: Colors.white,
          backgroundColor: CupertinoTheme.of(context).primaryColor,
          distance: 100,
        ),
        child: CustomScrollView(
          slivers: [
            _getAppBar(context),
            if (suggestions.isEmpty && _textController?.text.isEmpty == true)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: AppDimensions.spacingLg),
                        Text(
                          'Search for members to add',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: AppDimensions.spacingSm),
                        Text(
                          'Type a name in the search box above',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (suggestions.isEmpty &&
                _textController?.text.isNotEmpty == true)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: AppDimensions.spacingLg),
                        Text(
                          'No members found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: AppDimensions.spacingSm),
                        Text(
                          'Try a different search term',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => suggestions[index],
                  childCount: suggestions.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
