import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:yantra/pages/spaces/editSpace.dart';
import 'package:yantra/pages/spaces/gridSpaceView.dart';
import 'package:yantra/pages/spaces/spaceTypes/baseSpace.dart';
import 'package:yantra/pages/theatre.dart';

class OpenSpace extends StatefulWidget {
  final String space;
  const OpenSpace({this.space, Key key}) : super(key: key);

  @override
  _OpenSpaceState createState() => _OpenSpaceState();
}

class _OpenSpaceState extends State<OpenSpace> {
  @override
  Widget build(BuildContext context) {
    return BaseSpace(
      space: widget.space,
    );
  }
}
