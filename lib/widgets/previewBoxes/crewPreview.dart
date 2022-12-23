import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:adiHouse/pages/userProfile.dart';

class CrewPreview extends StatefulWidget {
  final String user;
  final String role;
  const CrewPreview({this.user, this.role, key}) : super(key: key);

  @override
  _CrewPreviewState createState() => _CrewPreviewState();
}

class _CrewPreviewState extends State<CrewPreview> {
  String name;
  File picture;
  final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('users');

  @override
  void initState() {
    super.initState();
    initializePreview();
  }

  initializePreview() async {
    DocumentSnapshot doc = await usersCollection.doc(widget.user).get();
    name = doc['name'];
    if (this.mounted) {
      setState(() {});
    }
    if (doc['displayPicture'] != '') {
      picture =
          await DefaultCacheManager().getSingleFile(doc['displayPicture']);

      if (this.mounted) {
        setState(() {});
      }
    }
  }

  getPicture() {
    if (picture != null) {
      return Image.file(
        picture,
        fit: BoxFit.cover,
      );
    } else {
      return Image.asset(
        'assets/images/space.jpg',
        fit: BoxFit.cover,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => UserProfilePage(
                uid: widget.user,
              ),
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.all(7),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7.0),
            child: Material(
              elevation: 1,
              color: Colors.transparent,
              child: Container(
                child: Row(
                  children: <Widget>[
                    Material(
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                            child: AspectRatio(
                                aspectRatio: 1, child: getPicture()))),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          (name != null)
                              ? Text(
                                  name,
                                  style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w300),
                                )
                              : Container(),
                          (widget.role != null)
                              ? Text(
                                  widget.role,
                                  style: TextStyle(
                                      fontSize: 15, color: Colors.grey),
                                )
                              : Container()
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}
