import 'dart:io';

import 'package:tribes/services/databaseService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class UserToken extends StatefulWidget {
  final String? token;
  UserToken({@required this.token});
  @override
  _UserTokenState createState() => _UserTokenState();
}

class _UserTokenState extends State<UserToken> {
  File? Picture;

  @override
  void initState() {
    super.initState();
    getData();
  }

  getData() async {
    final itemdocuments = await DatabaseService().getItem(widget.token!);
    Picture = await DefaultCacheManager().getSingleFile(itemdocuments['image']);
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
          child: (Picture != null)
              ? Image.file(
                  Picture!,
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
