import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flappy_search_bar/flappy_search_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adiHouse/pages/userProfile.dart';
import 'package:adiHouse/widgets/previewBoxes/userPreviewBox.dart';

class StageCrew extends StatefulWidget {
  final String title;
  final List guestList;
  StageCrew({this.title, this.guestList});

  @override
  _StageCrewState createState() => _StageCrewState();
}

class _StageCrewState extends State<StageCrew> {
  final CollectionReference userCollection =
      FirebaseFirestore.instance.collection('users');

  List<Map> data = [];

  @override
  void initState() {
    super.initState();
    getData();
  }

  getData() async {
    widget.guestList.forEach((key) async {
      await userCollection.doc(key).get().then((snapshot) => {
            if (snapshot.exists)
              {
                data.add({
                  'nickname': snapshot['nickname'],
                  'previewUrl': snapshot['displayPicture'],
                  'name': snapshot['name'],
                  'uid': key
                })
              }
          });
      setState(() {});
    });
  }

  Future<List<Post>> search(String search) async {
    List<Map> searchResult = [];
    data.forEach((element) {
      if (element['nickname'].toLowerCase().contains(search.toLowerCase())) {
        searchResult.add(element);
      }
    });
    return List.generate(searchResult.length, (int index) {
      return Post(
        searchResult[index]['previewUrl'],
        searchResult[index]['nickname'],
        searchResult[index]['uid'],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.title,
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
        trailing: GestureDetector(
          child: Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: Material(
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: SearchBar(
            crossAxisCount: 3,
            onSearch: search,
            suggestions: List.generate(data.length, (int index) {
              return Post(data[index]['previewUrl'], data[index]['nickname'],
                  data[index]['uid']);
            }),
            onItemFound: (Post post, int index) {
              return Padding(
                padding: const EdgeInsets.all(1.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context)
                        .push(CupertinoPageRoute(builder: (context) {
                      return UserProfilePage(uid: post.uid);
                    }));
                  },
                  child: UserPreview(
                    uid: post.uid,
                    showName: true,
                  ),
                ),
              );
            },
          ),
        )),
      ),
    );
  }
}

class Post {
  final String url;
  final String nickname;
  final String uid;

  Post(this.url, this.nickname, this.uid);
}
