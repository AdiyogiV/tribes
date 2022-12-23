import 'package:adiHouse/services/databaseService.dart';
import 'package:adiHouse/widgets/Dailogs/buyItemDailog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:adiHouse/pages/spaces/space.dart';
import 'package:adiHouse/widgets/Dailogs/itemCreationDailog.dart';
import 'package:adiHouse/widgets/previewBoxes/itemPreview.dart';

class HouseMarket extends StatefulWidget {
  final String house;
  const HouseMarket({this.house, Key key}) : super(key: key);

  @override
  State<HouseMarket> createState() => _HouseMarketState();
}

class _HouseMarketState extends State<HouseMarket> {
  RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  String name = '';
  FocusNode focusNode = FocusNode();
  final CollectionReference spaceItemsCollection =
      FirebaseFirestore.instance.collection('spaceItems');

  @override
  void initState() {
    super.initState();
    getSpace();
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

  getSpace() async {
    final doc = await DatabaseService().getSpace(widget.house);
    name = doc['name'];
    this.setState(() {});
  }

  getItems() {
    return FutureBuilder<QuerySnapshot>(
        future:
            spaceItemsCollection.doc(widget.house).collection('items').get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          List spaceList = snapshot.data.docs.reversed
              .toList()
              .asMap()
              .map((index, doc) => MapEntry(
                    index,
                    GestureDetector(
                      key: UniqueKey(),
                      onTap: () {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return BuyItemDailog(
                                house: widget.house,
                                item: doc.id,
                              );
                            });

                        //   Navigator.of(context, rootNavigator: true)
                        //       .push(CupertinoPageRoute(builder: (context) {
                        //     return HouseMarket(
                        //       house: doc.id,
                        //     );
                        //   }));
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width / 2,
                        padding: EdgeInsets.all(10),
                        child: ItemPreview(
                          key: UniqueKey(),
                          item: doc.id,
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
        backgroundColor: Colors.white,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).pop();
          },
          backgroundColor: CupertinoTheme.of(context).primaryColor,
          label: Text('House'),
          icon: Icon(Icons.arrow_back_ios),
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
                  title: GestureDetector(
                      onTap: () {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return ItemCreationDailog(
                                space: widget.house,
                              );
                            });
                      },
                      child: Container(height: 90, child: getLogo())),
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
                            stops: [0.1, 1],
                            tileMode: TileMode.mirror),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 100.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w200),
                            ),
                          ],
                        ),
                      )),
                  iconTheme: IconThemeData(
                      color: CupertinoTheme.of(context).primaryColor),
                ),
                SliverToBoxAdapter(child: getItems()),
              ],
            )));
  }
}
