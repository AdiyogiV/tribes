import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:adiHouse/pages/houseMarket.dart';
import 'package:adiHouse/pages/spaces/space.dart';
import 'package:adiHouse/widgets/Dailogs/spaceCreationDailog.dart';
import 'package:adiHouse/widgets/previewBoxes/spacePreviewBox.dart';

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

  @override
  void initState() {
    super.initState();
  }

  onRefresh() async {
    setState(() {});
    _refreshController.refreshCompleted();
  }

  getLogo() {
    return Image.asset(
      'assets/images/adidaslogo.png',
      fit: BoxFit.contain,
    );
  }

  getTribes() {
    return FutureBuilder<QuerySnapshot>(
        future: userSpacesCollection
            .doc(user.uid)
            .collection('spaces')
            .where('role', whereIn: ['member', 'owner']).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          List spaceList = snapshot.data.docs
              .toList()
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
                        padding: EdgeInsets.only(top: 7, left: 7, right: 7),
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
        backgroundColor: Colors.black38,
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
              backgroundColor: Colors.black,
              distance: 100,
            ),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(1),
                          bottomRight: Radius.circular(1))),
                  title: Container(height: 90, child: getLogo()),
                  backgroundColor: Colors.transparent,
                  floating: true,
                  stretch: true,
                  expandedHeight: 160,
                  collapsedHeight: 140,
                  elevation: 4,
                  forceElevated: true,
                  flexibleSpace: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(1),
                          bottomRight: Radius.circular(1)),
                      gradient: new LinearGradient(
                          colors: [
                            Colors.black,
                            Colors.black54,
                          ],
                          begin: const FractionalOffset(0.0, 0.0),
                          end: const FractionalOffset(0.0, 1),
                          stops: [0.1, 1],
                          tileMode: TileMode.mirror),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 100.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(
                            'own houses',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w200),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(10),
                                child: CupertinoSearchTextField(
                                  backgroundColor: Colors.white,
                                  itemColor: Colors.black54,
                                  style: TextStyle(
                                      color: CupertinoTheme.of(context)
                                          .primaryColor),
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
                        ],
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
