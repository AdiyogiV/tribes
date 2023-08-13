import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ReplyTile extends StatefulWidget {
  final Map? data;
  ReplyTile({this.data});
  @override
  _ReplyTileState createState() => _ReplyTileState();
}

class _ReplyTileState extends State<ReplyTile> {
  String? nickname;
  File? replyThumbnail;
  File? replyToThumbnail;
  final CollectionReference postCollection =
      FirebaseFirestore.instance.collection('posts');
  @override
  void initState() {
    super.initState();
    parseData();
  }

  parseData() async {
    nickname = widget.data!['author_nickname'];
    DefaultCacheManager()
        .getSingleFile(widget.data!['thumbnail'])
        .then((value) => {
              setState(() {
                replyThumbnail = value;
              })
            });
    await postCollection.doc(widget.data!['replyToPost']).get().then((value) => {
          print(value.data()),
          DefaultCacheManager()
              .getSingleFile(value['thumbnail'])
              .then((value2) => {
                    setState(() {
                      replyToThumbnail = value2;
                    })
                  })
        });
  }

  @override
  Widget build(BuildContext context) {
    return (replyToThumbnail != null)
        ? Container(
            child: ListTile(
              contentPadding: EdgeInsets.only(top: 10, right: 10, left: 10),
              trailing: ClipRRect(
                borderRadius: BorderRadius.circular(0.0),
                child: Container(
                    width: 50,
                    height: 100,
                    child: Image.file(
                      replyThumbnail!,
                      fit: BoxFit.cover,
                    )),
              ),
              title: Text(
                  "$nickname posted a reply to your "
                  "post",
                  style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      color: CupertinoTheme.of(context).primaryColor),
                  textAlign: TextAlign.center),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(0.0),
                child: Container(
                    width: 50,
                    height: 100,
                    child: Image.file(
                      replyToThumbnail!,
                      fit: BoxFit.cover,
                    )),
              ),
              onTap: () {
                Navigator.of(context)
                    .push(CupertinoPageRoute(builder: (context) {
                  return Container();
                }));
              },
            ),
          )
        : Container();
  }
}
