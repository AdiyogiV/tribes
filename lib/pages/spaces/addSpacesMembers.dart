import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drag_select_grid_view/drag_select_grid_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:adiHouse/pages/spaces/editSpace.dart';
import 'package:adiHouse/pages/spaces/inviteToSpace.dart';

import 'package:adiHouse/services/databaseService.dart';
import 'package:adiHouse/widgets/previewBoxes/followersPreview.dart';

class AddSpacesMember extends StatefulWidget {
  final String space;
  final spaceMembers;
  AddSpacesMember({Key key, @required this.space, this.spaceMembers})
      : super(key: key);

  @override
  _AddSpacesMemberState createState() => _AddSpacesMemberState();
}

class _AddSpacesMemberState extends State<AddSpacesMember> {
  User user = FirebaseAuth.instance.currentUser;
  RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  final controller = DragSelectGridViewController();
  var _followerList;
  bool _isSearching = false;
  bool _isLoading = false;
  void initState() {
    super.initState();
    controller.addListener(rebuild);
  }

  FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    controller.removeListener(rebuild);
    _focusNode.dispose();
    super.dispose();
  }

  void rebuild() => setState(() {});
  void _onRefresh() async {
    // monitor network fetch\
    // if failed,use refreshFailed()

    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    // monitor network fetch
    // if failed,use loadFailed(),if no data return,use LoadNodata()
    _refreshController.loadComplete();
  }

  // Future<bool> isMembersExist(String element) async {
  //   if (widget.spaceMembers.contains(element)) {
  //     return true;
  //   } else {
  //     return false;
  //   }
  // }

  getFloatingButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(context).push(CupertinoPageRoute(
            builder: (BuildContext context) => InviteToSpace(
                  space: widget.space,
                )));
      },
      backgroundColor: CupertinoTheme.of(context).primaryColor,
      icon: Icon(Icons.share),
      label: Text('Share Link'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = controller.value.isSelecting;
    final _header = isSelected
        ? "${controller.value.amount} Member Selected"
        : " Add Members";
    Future _followrs = DatabaseService().getSpaceFollower(user.uid);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: CupertinoNavigationBar(
          leading: isSelected ? CloseButton() : null,
          middle: _isSearching
              ? CupertinoTextField(
                  placeholder: "Search",
                  autofocus: true,
                  cursorColor: CupertinoTheme.of(context).primaryColor,
                  decoration:
                      BoxDecoration(border: null, color: Colors.transparent),
                )
              : Text(_header),
          trailing: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearching = !_isSearching;
                });
              },
              child: Icon(
                CupertinoIcons.search,
                size: 25,
                color: Colors.black87,
              ))),
      body: SmartRefresher(
        controller: _refreshController,
        onLoading: _onLoading,
        onRefresh: _onRefresh,
        header: WaterDropMaterialHeader(
          color: Colors.white,
          backgroundColor: CupertinoTheme.of(context).primaryColor,
          distance: 100,
        ),
        child: FutureBuilder<QuerySnapshot>(
            future: _followrs,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (!snapshot.hasData) {
                return Expanded(
                    child: Center(child: CircularProgressIndicator()));
              }
              _followerList = snapshot.data.docs;
              return Expanded(
                child: DragSelectGridView(
                  gridController: controller,
                  padding: const EdgeInsets.only(top: 10, left: 5, right: 5),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: _followerList.length,
                  itemBuilder: (BuildContext context, int index, isSelected) {
                    return Container(
                        key: UniqueKey(),
                        width: MediaQuery.of(context).size.width / 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: FollowersPreview(
                            key: UniqueKey(),
                            uid: _followerList[index].id,
                            showName: true,
                            isSelected: isSelected));
                  },
                ),
              );
            }),
      ),
      floatingActionButton: isSelected
          ? FloatingActionButton(
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                });
                controller.value.selectedIndexes.forEach((element) {
                  print(widget.space);
                  print(_followerList[element].id);
                  return DatabaseService()
                      .addSpaceMember(widget.space, _followerList[element].id);
                });

                setState(() {
                  _isLoading = false;
                });
                Navigator.of(context).push(CupertinoPageRoute(
                    builder: (BuildContext context) =>
                        EditSpace(space: widget.space)));
              },
              backgroundColor: CupertinoTheme.of(context).primaryColor,
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                        backgroundColor: Colors.white,
                      ),
                    )
                  : Icon(Icons.check_sharp),
            )
          : getFloatingButton(),
    );
  }
}


// AnimatedContainer(
//                   duration: Duration(milliseconds: 500),
//                   curve: Curves.easeInCirc,
//                   child: CupertinoSearchTextField(
//                     backgroundColor: Colors.transparent,
//                     itemColor: Colors.black54,
//                     style: TextStyle(
//                         color: CupertinoTheme.of(context).primaryColor),
//                     placeholderStyle: TextStyle(color: Colors.black54),
//                     onChanged: (query) {},
//                     itemSize: 0,
//                     focusNode: _focusNode,
//                   ),
//                 )