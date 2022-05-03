import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class SpacePreviewBox extends StatefulWidget {
  final String space;

  SpacePreviewBox({this.space, Key key}) : super(key: key);

  @override
  _SpacePreviewBoxState createState() => _SpacePreviewBoxState();
}

class _SpacePreviewBoxState extends State<SpacePreviewBox> {
  String spaceName;
  File spacePicture;
  final CollectionReference spacesCollection =
      FirebaseFirestore.instance.collection('spaces');

  @override
  void initState() {
    super.initState();
    initializePreview();
  }

  initializePreview() async {
    DocumentSnapshot spaceDoc = await spacesCollection.doc(widget.space).get();
    spaceName = spaceDoc['name'];
    if (this.mounted) {
      setState(() {});
    }
    if (spaceDoc['displayPicture'] != '') {
      spacePicture =
          await DefaultCacheManager().getSingleFile(spaceDoc['displayPicture']);

      if (this.mounted) {
        setState(() {});
      }
    }
  }

  getSpacePicture() {
    if (spacePicture != null) {
      return Image.file(
        spacePicture,
        fit: BoxFit.cover,
      );
    } else {
      return Image.asset(
        'assets/images/space.jpg',
        fit: BoxFit.cover,
      );
    }
  }

  getSpaceName() {
    return Container(
        padding: EdgeInsets.all(10),
        child: Text(
          spaceName,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7.0),
      child: Material(
        elevation: 1,
        color: Colors.white,
        child: Container(
          padding: EdgeInsets.all(7),
          child: Row(
            children: <Widget>[
              Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7.0),
                      border: Border.all(
                          width: 0.5,
                          color: CupertinoTheme.of(context).primaryColor)),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(6.0),
                      child: Container(
                          child: AspectRatio(
                              aspectRatio: 1, child: getSpacePicture())))),
              Column(
                children: [if (spaceName != null) getSpaceName()],
              )
            ],
          ),
        ),
      ),
    );
  }
}
