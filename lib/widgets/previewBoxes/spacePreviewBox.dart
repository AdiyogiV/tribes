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
    spaceName =
        spaceDoc.data().toString().contains('name') ? spaceDoc['name'] : '';
    if (this.mounted) {
      setState(() {});
    }
    spacePicture = spaceDoc.data().toString().contains('displayPicture')
        ? await DefaultCacheManager().getSingleFile(spaceDoc['displayPicture'])
        : null;
    if (this.mounted) {
      setState(() {});
    }
  }

  getSpacePicture() {
    return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7.0),
            border: Border.all(
                width: 0.5, color: CupertinoTheme.of(context).primaryColor)),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: Container(
                child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.file(
                      spacePicture,
                      fit: BoxFit.cover,
                    )))));
  }

  getSpaceName() {
    return Container(
        padding: EdgeInsets.all(10),
        child: Text(
          spaceName,
          textAlign: TextAlign.center,
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
              if (spacePicture != null) getSpacePicture(),
              if (spaceName != null) getSpaceName()
            ],
          ),
        ),
      ),
    );
  }
}
