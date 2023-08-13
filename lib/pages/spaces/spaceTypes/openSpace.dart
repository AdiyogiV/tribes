import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tribes/pages/spaces/spaceTypes/baseSpace.dart';

class OpenSpace extends StatefulWidget {
  final String? space;
  const OpenSpace({this.space, Key? key}) : super(key: key);

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
