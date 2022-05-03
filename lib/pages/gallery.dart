import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:yantra/pages/spaces/space.dart';
import 'package:yantra/widgets/Dailogs/spaceCreationDailog.dart';
import 'package:yantra/widgets/previewBoxes/spacePreviewBox.dart';

class Gallery extends StatefulWidget {
  @override
  _GalleryState createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  User user = FirebaseAuth.instance.currentUser;
  final CollectionReference userSpacesCollection =
      FirebaseFirestore.instance.collection('userSpaces');

  RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  FocusNode focusNode = FocusNode();
  List<Widget> tribes = [];
  int selectedSpaceType = 0;
  final Map<int, Widget> spaceTypes = <int, Widget>{
    0: Icon(
      Icons.blur_on,
      size: 20,
    ),
    1: Icon(
      Icons.public,
      size: 20,
    ),
    2: Icon(
      Icons.hide_source,
      size: 20,
    ),
    3: Icon(
      Icons.lock,
      size: 20,
    ),
  };
  @override
  void initState() {
    super.initState();
  }

  onRefresh() async {
    setState(() {});
    _refreshController.refreshCompleted();
  }

  String getTitle() {
    switch (selectedSpaceType) {
      case 0:
        {
          return 'open tribes';
        }
        break;
      case 1:
        {
          return 'public tribes';
        }
        break;

      case 2:
        {
          return 'private tribes';
        }
        break;
      default:
        {
          return 'secret tribes';
        }
        break;
    }
  }

  getTribes() {
    return FutureBuilder<QuerySnapshot>(
        future: userSpacesCollection
            .doc(user.uid)
            .collection('spaces')
            .where('role', whereIn: ['member', 'owner'])
            .where('spaceType', isEqualTo: this.selectedSpaceType)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          List spaceList = snapshot.data.docs
              .asMap()
              .map((index, doc) => MapEntry(
                    index,
                    GestureDetector(
                      key: UniqueKey(),
                      onTap: () {
                        Navigator.of(context, rootNavigator: true)
                            .push(CupertinoPageRoute(builder: (context) {
                          return SpaceBox(
                            rid: doc.id,
                          );
                        }));
                      },
                      child: Container(
                        height: 100,
                        padding: EdgeInsets.only(top: 5, left: 5, right: 5),
                        child: SpacePreviewBox(
                          key: UniqueKey(),
                          space: doc.id,
                        ),
                      ),
                    ),
                  ))
              .values
              .toList();
          return Container(
            child: Wrap(
              children: spaceList,
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBody: true,
        backgroundColor: Colors.indigo[100],
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return SpaceCreationDailog(
                    selectedSpaceType: this.selectedSpaceType,
                  );
                });
          },
          backgroundColor: CupertinoTheme.of(context).primaryColor,
          child: Icon(Icons.add),
        ),
        body: SmartRefresher(
            onRefresh: onRefresh,
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
                  shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(1),
                          bottomRight: Radius.circular(1))),
                  title: Text(
                    getTitle(),
                    style: TextStyle(
                      color: CupertinoTheme.of(context).primaryColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  floating: true,
                  stretch: true,
                  expandedHeight: 110,
                  collapsedHeight: 100,
                  elevation: 4,
                  forceElevated: true,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.all(7.0),
                      child: CupertinoSlidingSegmentedControl(
                        padding: EdgeInsets.all(4),
                        onValueChanged: (value) {
                          selectedSpaceType = value;
                          focusNode.unfocus();
                          setState(() {});
                        },
                        groupValue: selectedSpaceType,
                        children: spaceTypes,
                        backgroundColor: Colors.black12,
                        thumbColor: Colors.white,
                      ),
                    ),
                  ],
                  flexibleSpace: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(1),
                          bottomRight: Radius.circular(1)),
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
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80.0),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(7.0),
                          child: Material(
                            elevation: 2,
                            borderRadius: BorderRadius.circular(10),
                            child: CupertinoSearchTextField(
                              backgroundColor: Colors.white,
                              itemColor: Colors.black54,
                              style: TextStyle(
                                  color:
                                      CupertinoTheme.of(context).primaryColor),
                              placeholderStyle:
                                  TextStyle(color: Colors.black54),
                              focusNode: focusNode,
                              onChanged: (query) {
                                //getSuggestions(query);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  iconTheme: IconThemeData(
                      color: CupertinoTheme.of(context).primaryColor),
                ),
                SliverToBoxAdapter(child: getTribes()),
              ],
            )));
  }
}
