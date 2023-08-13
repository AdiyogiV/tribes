import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class UserPicture extends StatefulWidget {
  final String? displayPicture;
  UserPicture({@required this.displayPicture});
  @override
  _UserPictureState createState() => _UserPictureState();
}

class _UserPictureState extends State<UserPicture> {
  File? userPicture;

  @override
  void initState() {
    super.initState();
    getData();
  }

  getData() async {
    print(widget.displayPicture);
    userPicture =
        await DefaultCacheManager().getSingleFile(widget.displayPicture!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Material(
        elevation: 2,
        shape: CircleBorder(),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: AspectRatio(
          aspectRatio: 1,
          child: (userPicture != null)
              ? Image.file(
                  userPicture!,
                  fit: BoxFit.cover,
                )
              : Image.asset(
                  'assets/images/space.jpg',
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }
}
