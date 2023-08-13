import 'package:flutter/cupertino.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tribes/pages/spaces/addSpacesMembers.dart';

class CollapsingList extends StatefulWidget {
  CollapsingList({Key? key}) : super(key: key);

  @override
  _CollapsingListState createState() => _CollapsingListState();
}

class _CollapsingListState extends State<CollapsingList> {
  bool isOwner = true;
  final _imageFile = null;
  SliverPersistentHeader makeHeader(
      Widget child, double maxHeight, double minHeight) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        minHeight: minHeight,
        maxHeight: maxHeight,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double p_width = MediaQuery.of(context).size.width * 0.4;
    double maxHeight = MediaQuery.of(context).size.height / 1.48;
    double minHeight = MediaQuery.of(context).size.height / 1.48;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
            middle: Text('Space Details'),
            trailing: GestureDetector(
                onTap: () {
                  // onSavePressed();
                },
                child: Text(
                  'Save',
                  style: TextStyle(color: CupertinoColors.activeBlue),
                ))),
        child: CustomScrollView(
          slivers: <Widget>[
            makeHeader(
                Column(
                  children: <Widget>[
                    Container(
                      margin: EdgeInsets.only(top: 80),
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child:
                            new Stack(fit: StackFit.loose, children: <Widget>[
                          new Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(5.0),
                                clipBehavior: Clip.antiAlias,
                                child: new Container(
                                  width: p_width,
                                  height: p_width,
                                  child: (_imageFile != null)
                                      ? Image.file(
                                          _imageFile,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.asset(
                                          'assets/images/noise.jpg',
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            ],
                          ),
                          if (isOwner)
                            Padding(
                                padding: EdgeInsets.only(right: 60.0, top: 10),
                                child: new Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    GestureDetector(
                                      onTap: () {
                                        // _onImageButtonPressed();
                                      },
                                      child: new CircleAvatar(
                                          backgroundColor: Colors.red,
                                          radius: 25.0,
                                          child: Icon(
                                            Icons.edit,
                                            color: CupertinoColors.white,
                                          )),
                                    )
                                  ],
                                )),
                        ]),
                      ),
                    ),
                    new Container(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 25.0),
                        child: new Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                                padding: EdgeInsets.only(
                                    left: 15.0, right: 15.0, top: 10.0),
                                child: new Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: <Widget>[
                                    new Flexible(
                                      child: new CupertinoTextField(
                                        padding: EdgeInsets.all(10),
                                        // controller: _nameController,
                                        placeholder: 'Space Name',
                                        // enabled: isOwner,
                                      ),
                                    ),
                                  ],
                                )),
                            Padding(
                                padding: EdgeInsets.only(
                                    left: 15.0, right: 15.0, top: 10.0),
                                child: new Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: <Widget>[
                                    new Flexible(
                                      child: new CupertinoTextField(
                                        padding: EdgeInsets.all(10),
                                        // controller: _bioController,
                                        style: TextStyle(fontSize: 14),
                                        placeholder: 'Description',
                                        // enabled: isOwner,
                                      ),
                                    ),
                                  ],
                                )),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Text('Members',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w300,
                              color: CupertinoColors.black,
                              shadows: [
                                Shadow(
                                  blurRadius: 2,
                                  color: Colors.white,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            )),
                      ),
                    ),
                  ],
                ),
                maxHeight,
                minHeight),
            SliverGrid.count(
              crossAxisCount: 3,
              children: [
                Container(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.only(bottom: 0, top: 0, left: 16),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              shape: CircleBorder(), backgroundColor: Colors.indigo[700],
                              padding: EdgeInsets.all(30)),
                          child: Icon(
                            Icons.add,
                            size: 20,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(CupertinoPageRoute(
                                builder: (BuildContext context) =>
                                    AddSpacesMember(space: null)));
                          },
                        ),
                      ),
                    ),
                    Container(
                        padding: EdgeInsets.only(
                            top: 0, bottom: 0, left: 16, right: 16),
                        margin: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "    Space",
                        )),
                  ],
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });
  final double minHeight;
  final double maxHeight;
  final Widget child;
  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => math.max(maxHeight, minHeight);
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return new SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
