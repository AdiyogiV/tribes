import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class SpacePreviewBox extends StatefulWidget {
  final String? space;

  SpacePreviewBox({this.space, Key? key}) : super(key: key);

  @override
  _SpacePreviewBoxState createState() => _SpacePreviewBoxState();
}

class _SpacePreviewBoxState extends State<SpacePreviewBox> {
  String? spaceName;
  File? spacePicture;
  final CollectionReference spacesCollection =
      FirebaseFirestore.instance.collection('spaces');

  @override
  void initState() {
    super.initState();
    initializePreview();
  }

  initializePreview() async {
    DocumentSnapshot spacedocuments =
        await spacesCollection.doc(widget.space).get();
    spaceName = spacedocuments.data().toString().contains('name')
        ? spacedocuments['name']
        : '';
    if (this.mounted) {
      setState(() {});
    }
    spacePicture = spacedocuments.data().toString().contains('displayPicture')
        ? await DefaultCacheManager()
            .getSingleFile(spacedocuments['displayPicture'])
        : null;
    if (this.mounted) {
      setState(() {});
    }
  }

  getSpacePicture() {
    return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5.0),
            border: Border.all(
                width: 0.5, color: CupertinoTheme.of(context).primaryColor)),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(5.0),
            child: Container(
                height: 30,
                child: (spacePicture == null)
                    ? Container(
                        width: 30,
                        height: 30,
                        color: Colors.yellow,
                      )
                    : AspectRatio(
                        aspectRatio: 1,
                        child: Image.asset(
                          spacePicture!.path,
                          fit: BoxFit.cover,
                        )))));
  }

  getSpaceName() {
    return Container(
        padding: EdgeInsets.all(5),
        child: Text(
          spaceName!,
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
              getSpacePicture(),
              if (spaceName != null) getSpaceName()
            ],
          ),
        ),
      ),
    );
  }
}
