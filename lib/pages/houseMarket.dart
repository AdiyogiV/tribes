import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:yantra/pages/spaces/space.dart';

class HouseMarket extends StatefulWidget {
  final String house;
  const HouseMarket({this.house, Key key}) : super(key: key);

  @override
  State<HouseMarket> createState() => _HouseMarketState();
}

class _HouseMarketState extends State<HouseMarket> {
  RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  FocusNode focusNode = FocusNode();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBody: true,
        backgroundColor: Colors.white,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return SpaceBox(
                    rid: widget.house,
                  );
                });
          },
          backgroundColor: CupertinoTheme.of(context).primaryColor,
          label: Text('ROOM'),
          icon: Icon(Icons.arrow_forward_ios),
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
                  title: Container(height: 30, child: getLogo()),
                  backgroundColor: Colors.white,
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
                  ),
                  iconTheme: IconThemeData(
                      color: CupertinoTheme.of(context).primaryColor),
                ),
                SliverToBoxAdapter(child: Container()),
              ],
            )));
  }
}
