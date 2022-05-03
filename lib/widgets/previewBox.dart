import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class PreviewBox extends StatefulWidget {
  final String previewUrl;
  final String author;
  final String username;
  final String title;

  PreviewBox(
      {this.username,
        @required this.author,
        @required this.previewUrl,
        this.title,
        Key key})
      : super(key: key);

  @override
  _PreviewBoxState createState() => _PreviewBoxState();
}

class _PreviewBoxState extends State<PreviewBox> {
  File preview;
  File authorPicture;
  final CollectionReference spacesCollection =
  FirebaseFirestore.instance.collection('spaces');

  @override
  void initState() {
    super.initState();
    initializePreview();
  }

  initializePreview() async {
    if (widget.author != null) {
      DocumentSnapshot authorDoc =
      await spacesCollection.doc(widget.author).get();
      String authordp = authorDoc['displayPicture'];

      if (authordp != '')
        authorPicture = await DefaultCacheManager().getSingleFile(authordp);
    }
    if (widget.previewUrl != '')
      preview = await DefaultCacheManager().getSingleFile(widget.previewUrl);
    if (this.mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(2),
      child: Material(
        elevation: 5,
        shadowColor: Colors.black,
        borderRadius: BorderRadius.circular(5),
        borderOnForeground: true,
        clipBehavior: Clip.antiAlias,
        child: Container(
          child: AspectRatio(
              aspectRatio: 0.8,
              child: Stack(
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 0.8,
                    child: (preview != null)
                        ? Image.file(
                      preview,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      child: Image.asset(
                        'assets/images/noise.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start ,
                    children: <Widget>[
                      (authorPicture != null)
                          ? Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: Container(
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(blurRadius: 1),
                              ]),
                          child: Material(
                            shape: CircleBorder(),
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            child: Container(
                              width: 30,
                              height: 30,
                              child: Image.file(
                                authorPicture,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      )
                          : Container(),
                      (widget.title != null)
                          ? Container(
                        decoration: BoxDecoration(
                          gradient: new LinearGradient(
                              colors: [
                                Colors.black,
                                Colors.transparent,
                              ],
                              begin: const FractionalOffset(0.0, 1.0),
                              end: const FractionalOffset(0.0, 0.0),
                              stops: [0.0, 1.0],
                              tileMode: TileMode.clamp),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: CupertinoColors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 5,
                                  color: Colors.black,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                          : Expanded(child: Container()),
                    ],
                  )
                ],
              )),
        ),
      ),
    );
  }
}
