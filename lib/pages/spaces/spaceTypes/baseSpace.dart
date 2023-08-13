import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:tribes/pages/spaces/editSpace.dart';
import 'package:tribes/pages/spaces/gridSpaceView.dart';
import 'package:tribes/pages/theatre.dart';

class BaseSpace extends StatefulWidget {
  final String? space;
  const BaseSpace({this.space, key}) : super(key: key);

  @override
  State<BaseSpace> createState() => _BaseSpaceState();
}

class _BaseSpaceState extends State<BaseSpace> {
  String displayPicture = "";
  File? displayPicFile;
  bool gridViewOn = false;
  int initPage = 0;
  String name = '';

  getSpaceBox() async {
    displayPicFile =
        await DefaultCacheManager().getSingleFile(displayPicture);
    setState(() {});
  }

  setPageView(int initPage) {
    this.setState(() {
      this.initPage = initPage;
      gridViewOn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: CupertinoPageScaffold(
            backgroundColor: Colors.indigo[100],
            navigationBar: CupertinoNavigationBar(
              middle: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                      height: 30,
                      width: 30,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5.0),
                        child: (displayPicFile != null)
                            ? Image.file(
                                displayPicFile!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                child: Image.asset(
                                  'assets/images/noise.jpg',
                                  fit: BoxFit.cover,
                                ),
                              ),
                      )),
                  Text(
                    name,
                    style: TextStyle(fontWeight: FontWeight.w300),
                  ),
                  GestureDetector(
                      onTap: () {
                        gridViewOn = !gridViewOn;
                        setState(() {});
                      },
                      child: gridViewOn
                          ? Icon(
                              Icons.grid_view_outlined,
                              size: 25,
                              color: Colors.black87,
                            )
                          : Icon(
                              Icons.view_carousel,
                              size: 25,
                              color: Colors.black87,
                            )),
                  GestureDetector(
                      onTap: () {
                        Navigator.of(context)
                            .push(CupertinoPageRoute(builder: (context) {
                          return EditSpace(
                            space: widget.space!,
                          );
                        }));
                      },
                      child: Icon(
                        Icons.info_outline,
                        size: 25,
                        color: Colors.black87,
                      )),
                ],
              ),
            ),
            child: SafeArea(
              child: gridViewOn
                  ? GridSpaceView(
                      rid: widget.space!,
                      setPageView: setPageView,
                    )
                  : Theatre(
                      initpage: initPage,
                      rid: widget.space!,
                    ),
            )));
  }
}
