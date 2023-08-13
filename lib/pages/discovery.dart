
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:algolia/algolia.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:tribes/pages/spaces/space.dart';
import 'package:tribes/pages/userProfile.dart';
import 'package:tribes/services/algoliaService.dart';
import 'package:tribes/services/databaseService.dart';
import 'package:tribes/widgets/previewBox.dart';
import 'package:tribes/widgets/previewBoxes/crewPreview.dart';
import 'package:tribes/widgets/previewBoxes/spacePreviewBox.dart';

class Discovery extends StatefulWidget {
  @override
  _DiscoveryState createState() => _DiscoveryState();
}

class _DiscoveryState extends State<Discovery> {
  final Algolia _algoliaApp = AlgoliaService.algolia;
  List<Widget> res = [];
  final CollectionReference spacesCollection =
      FirebaseFirestore.instance.collection('spaces');
  final CollectionReference postCollection =
      FirebaseFirestore.instance.collection('posts');
  final CollectionReference userCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference votesCollection =
      FirebaseFirestore.instance.collection('votes');
  RefreshController _refreshController =
      RefreshController(initialRefresh: false);

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
      Icons.people,
      size: 20,
    ),
  };
  bool public = false;
  int selectedSpaceType = 0;
  TextEditingController? _textController;
  int searchPost = 1;
  List<Widget> suggestions = [];
  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    getSuggestions('');
  }

  getSuggestions(String input) async {
    suggestions = [];
    switch (selectedSpaceType) {
      case 0:
        {
          getSpaces(input);
        }
        break;

      default:
        {
          getUsers(input);
        }
        break;
    }
  }

  getSpaces(String input) async {
    try {
      QuerySnapshot results = await DatabaseService().getSpaces(input);
      suggestions = results.docs
          .toList()
          .asMap()
          .map(
            (index, documents) => MapEntry(
              index,
              GestureDetector(
                key: UniqueKey(),
                onTap: () {
                  Navigator.of(context, rootNavigator: true)
                      .push(CupertinoPageRoute(builder: (context) {
                    return SpaceBox(
                      rid: documents.id,
                    );
                  }));
                },
                child: Container(
                  height: 70,
                  padding: EdgeInsets.only(top: 7, left: 7, right: 7),
                  child: SpacePreviewBox(
                    key: UniqueKey(),
                    space: documents.id,
                  ),
                ),
              ),
            ),
          )
          .values
          .toList();
    } catch (e) {
      print(e);
    }
    setState(() {});
  }

  getUsers(String input) async {
    AlgoliaQuerySnapshot _querySnap =
        await _algoliaApp.instance.index('users').query(input).getObjects();
    List<AlgoliaObjectSnapshot> results = _querySnap.hits;
    try {
      suggestions = results
          .asMap()
          .map(
            (index, documents) => MapEntry(
              index,
              GestureDetector(
                key: UniqueKey(),
                onTap: () {
                  Navigator.of(context)
                      .push(CupertinoPageRoute(builder: (context) {
                    return UserProfilePage(
                      uid: documents.objectID,
                    );
                  }));
                },
                child: Container(
                  height: 70,
                  padding: EdgeInsets.only(top: 7, left: 7, right: 7),
                  child: CrewPreview(
                    key: UniqueKey(),
                    user: documents.objectID,
                  ),
                ),
              ),
            ),
          )
          .values
          .toList();
    } catch (e) {
      print(e);
    }
    setState(() {});
  }

  getPosts(String input) async {
    AlgoliaQuerySnapshot _querySnap = await _algoliaApp.instance
        .index('posts')
        .query(input)
        .setHitsPerPage(40)
        .getObjects();
    List<AlgoliaObjectSnapshot> results = _querySnap.hits;
    print(results.length);
    try {
      suggestions = results
          .asMap()
          .map(
            (index, documents) => MapEntry(
              index,
              GestureDetector(
                key: UniqueKey(),
                onTap: () {},
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  child: PreviewBox(
                    key: UniqueKey(),
                    title: documents.data['title'],
                    author: documents.data['author'],
                    previewUrl: documents.data['thumbnail'],
                  ),
                ),
              ),
            ),
          )
          .values
          .toList();
    } catch (e) {
      print(e);
    }
    setState(() {});
  }

  void _onRefresh() async {
    // monitor network fetch\
    // if failed,use refreshFailed()
    await getSuggestions('');
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    // monitor network fetch
    // if failed,use loadFailed(),if no data return,use LoadNodata()
    _refreshController.loadComplete();
  }

  @override
  void dispose() {
    focusNode.dispose();
    _textController!.dispose();
    super.dispose();
  }

  getLogo() {
    return Container(
        padding: EdgeInsets.all(20),
        child: Image.asset(
          'assets/images/icon.png',
          fit: BoxFit.contain,
        ));
  }

  Widget getResponsiveView() {
    return ScreenTypeLayout.builder(
      mobile: (BuildContext context) => Container(color: Colors.blue),
      tablet: (BuildContext context) => Container(color: Colors.yellow),
      desktop: (BuildContext context) => Container(color: Colors.red),
      watch: (BuildContext context) => Container(color: Colors.purple),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
            SliverAppBar(
              shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(1),
                      bottomRight: Radius.circular(1))),
              title: Container(height: 90, child: getLogo()),
              backgroundColor: Colors.transparent,
              floating: true,
              stretch: true,
              expandedHeight: 120,
              collapsedHeight: 100,
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
                      stops: [0.0, 1],
                      tileMode: TileMode.mirror),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 80.0),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(10),
                        child: CupertinoSearchTextField(
                          backgroundColor: Colors.white,
                          itemColor: Colors.black54,
                          style: TextStyle(
                              color: CupertinoTheme.of(context).primaryColor),
                          placeholderStyle: TextStyle(color: Colors.black54),
                          focusNode: focusNode,
                          onChanged: (query) {
                            getSuggestions(query);
                          },
                          controller: _textController,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              iconTheme:
                  IconThemeData(color: CupertinoTheme.of(context).primaryColor),
            ),
            SliverToBoxAdapter(
              child: (suggestions != null)
                  ? Wrap(
                      children: suggestions,
                    )
                  : Center(
                      child: CircularProgressIndicator(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
