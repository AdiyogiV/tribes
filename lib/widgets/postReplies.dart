import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/pages/login/login.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/previewBoxes/previewBox.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/theme_helper.dart';

typedef ReplyCallback = void Function(String postId);

class PostReplies extends StatefulWidget {
  final String? post;
  final String? space;
  final ReplyCallback? onReplySelected;

  const PostReplies({Key? key, this.post, this.onReplySelected, this.space})
      : super(key: key);

  @override
  _PostRepliesState createState() => _PostRepliesState();
}

class _PostRepliesState extends State<PostReplies> {
  List<Widget> replies = <Widget>[];
  User? user = FirebaseAuth.instance.currentUser;
  final CollectionReference postRepliesCollection =
      FirebaseFirestore.instance.collection('postReplies');
  final CollectionReference votesCollection =
      FirebaseFirestore.instance.collection('votes');

  @override
  Widget build(BuildContext context) {
    return _buildReply(context);
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> requestLogin() async {
    await showCupertinoDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            content: Text("Please Login to Continue"),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context)
                        .push(CupertinoPageRoute(builder: (context) {
                      return LoginPage();
                    }));
                  },
                  child: Text(
                    'Login',
                    style: TextStyle(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w400),
                  )),
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w400),
                  ))
            ],
          );
        });
  }

  Widget _buildReply(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
            future: postRepliesCollection
                .doc(widget.post)
                .collection('replies')
                .orderBy('timestamp', descending: true)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: 3,
                    itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SkeletonBox(width: 160, height: 100, borderRadius: 12),
                    ),
                  ),
                );
              }
              replies = snapshot.data!.docs
                  .asMap()
                  .map((index, documents) => MapEntry(
                      index,
                      GestureDetector(
                        key: UniqueKey(),
                        onTap: () {
                          widget.onReplySelected!(documents.id);
                        },
                        child: Container(
                          width: () {
                            final screenWidth =
                                MediaQuery.of(context).size.width;
                            if (ThemeHelper.isLargeTablet(context)) {
                              return screenWidth / 6;
                            }
                            if (ThemeHelper.isTablet(context)) {
                              return screenWidth / 5;
                            }
                            return screenWidth / 4;
                          }(),
                          margin: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: PreviewBox(
                                key: UniqueKey(),
                                previewUrl: (documents.data() as Map<String,
                                            dynamic>?)?['thumbnail']
                                        as String? ??
                                    '',
                                title: (documents.data()
                                        as Map<String, dynamic>?)?['title']
                                    as String?,
                                author: (documents.data()
                                        as Map<String, dynamic>?)?['author']
                                    as String?,
                                content: (documents.data() as Map<String,
                                    dynamic>?)?['content'] as String?,
                                postType: (documents.data() as Map<String,
                                    dynamic>?)?['postType'] as String?,
                                compact: true,
                                hideWhileLoading: false,
                                skipIfMissing: false,
                              ),
                            ),
                          ),
                        ),
                      )))
                  .values
                  .toList();

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: replies,
                ),
              );
            });
  }
}
