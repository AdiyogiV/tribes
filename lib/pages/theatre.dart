import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:yantra/pages/login.dart';
import 'package:yantra/pages/recorder.dart';
import 'package:yantra/widgets/postSwitcher.dart';

class Theatre extends StatefulWidget {
  final String rid;
  final int initpage;
  Theatre({
    this.rid,
    this.initpage,
  });

  @override
  _TheatreState createState() => _TheatreState();
}

class _TheatreState extends State<Theatre> {
  List<Widget> createdFeed = [];
  User user = FirebaseAuth.instance.currentUser;

  final CollectionReference spacePostsCollection =
      FirebaseFirestore.instance.collection('spacePosts');

  RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  requestLogin() async {
    await showCupertinoDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            content: Text("Please Login to Continue"),
            actions: <Widget>[
              FlatButton(
                  onPressed: () {
                    Navigator.of(context)
                        .push(CupertinoPageRoute(builder: (context) {
                      return LoginPage();
                    }));
                  },
                  child: Text(
                    'Login',
                    style: TextStyle(
                        color: CupertinoColors.destructiveRed,
                        fontWeight: FontWeight.w400),
                  )),
              FlatButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: CupertinoColors.activeBlue,
                        fontWeight: FontWeight.w400),
                  ))
            ],
          );
        });
  }

  void _onRefresh() async {
    // monitor network fetch\
    // if failed,use refreshFailed()
    setState(() {});
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    // monitor network fetch
    // if failed,use loadFailed(),if no data return,use LoadNodata()
    _refreshController.loadComplete();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PageIndexHolder>(
        create: (context) => PageIndexHolder(),
        child:
            Consumer<PageIndexHolder>(builder: (context, indexHolder, child) {
          return _buildCarousel(context);
        }));
  }

  Widget _buildCarousel(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.indigo[100],
        floatingActionButton:
            Consumer<PageIndexHolder>(builder: (context, indexHolder, child) {
          return FloatingActionButton(
            onPressed: () {
              if (user == null) {
                requestLogin();
                return;
              }
              Navigator.of(context).push(CupertinoPageRoute(builder: (builder) {
                return Recorder(
                  space: widget.rid,
                  replyTo: indexHolder.getPost(),
                );
              }));
            },
            backgroundColor: CupertinoTheme.of(context).primaryColor,
            child: Icon(Icons.add),
          );
        }),
        body: Container(
          child: StreamBuilder<QuerySnapshot>(
              stream: spacePostsCollection
                  .doc(widget.rid)
                  .collection('posts')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                List<String> feed =
                    snapshot.data.docs.map((e) => e.id).toList();
                return SmartRefresher(
                    onRefresh: _onRefresh,
                    scrollDirection: Axis.vertical,
                    controller: _refreshController,
                    header: WaterDropHeader(),
                    child: PageView(
                        scrollDirection: Axis.horizontal,
                        controller: PageController(
                            initialPage: widget.initpage,
                            viewportFraction: 0.8),
                        onPageChanged: (page) {
                          setState(() {
                            Provider.of<PageIndexHolder>(context, listen: false)
                                .setPost(feed[page]);
                          });
                        },
                        children: feed
                            .map<Widget>((doc) => PostSwitcher(postId: doc))
                            .toList()));
              }),
        ));
  }
}

class PageIndexHolder extends ChangeNotifier {
  bool enableAudio = true;
  int depth = 0;
  String activePost;

  void toggleAudio() {
    enableAudio = !enableAudio;
    notifyListeners();
  }

  void setPost(String post) {
    activePost = post;
    notifyListeners();
  }

  String getPost() {
    return activePost;
  }

  void setDepth(int page) {
    depth = page;
    notifyListeners();
  }
}
