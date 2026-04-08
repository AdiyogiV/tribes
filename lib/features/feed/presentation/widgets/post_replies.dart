import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/features/auth/login.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/preview_box.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

typedef ReplyCallback = void Function(String postId);

class PostReplies extends StatefulWidget {
  final String? post;
  final String? space;
  final ReplyCallback? onReplySelected;

  /// When non-null, use this instead of fetching replies (avoids duplicate fetch).
  final QuerySnapshot? initialReplies;

  const PostReplies({
    super.key,
    this.post,
    this.onReplySelected,
    this.space,
    this.initialReplies,
  });

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
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(PostReplies oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL: Prevent rebuilds when parent rebuilds but our post hasn't changed
    if (oldWidget.post == widget.post &&
        oldWidget.initialReplies == widget.initialReplies) {
      // Same post, same replies - no rebuild needed
      return;
    }

    // Post changed or replies updated - let build() handle it
  }

  /// Thumbnail width from content/card width (same as reply indicator & main app).
  static double _thumbnailWidthFromContent(double contentWidth) {
    return (contentWidth / 5).clamp(72.0, 160.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return _buildReply(context, contentWidth);
      },
    );
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

  Widget _buildThumbnailsFromDocs(
      List<QueryDocumentSnapshot> docs, double contentWidth) {
    final thumbWidth = _thumbnailWidthFromContent(contentWidth);
    replies = docs
        .asMap()
        .map((index, documents) => MapEntry(
            index,
            GestureDetector(
              key: UniqueKey(),
              onTap: () {
                widget.onReplySelected!(documents.id);
              },
              child: Container(
                width: thumbWidth,
                margin: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: PreviewBox(
                      key: UniqueKey(),
                      previewUrl: (documents.data()
                                  as Map<String, dynamic>?)?['thumbnail']
                              as String? ??
                          '',
                      title: (documents.data()
                          as Map<String, dynamic>?)?['title'] as String?,
                      author: (documents.data()
                          as Map<String, dynamic>?)?['author'] as String?,
                      content: (documents.data()
                          as Map<String, dynamic>?)?['content'] as String?,
                      postType: (documents.data()
                          as Map<String, dynamic>?)?['postType'] as String?,
                      compact: true,
                      showAuthorPicture: false,
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
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
      child: Row(
        children: replies,
      ),
    );
  }

  Widget _buildReply(BuildContext context, double contentWidth) {
    if (widget.initialReplies != null) {
      final docs = widget.initialReplies!.docs;
      if (docs.isEmpty) return const SizedBox.shrink();
      return _buildThumbnailsFromDocs(docs, contentWidth);
    }

    final thumbWidth = _thumbnailWidthFromContent(contentWidth);
    return FutureBuilder<QuerySnapshot>(
      future: postRepliesCollection
          .doc(widget.post)
          .collection('replies')
          .orderBy('timestamp', descending: true)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: thumbWidth + 20,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
              itemCount: 3,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SkeletonBox(
                    width: thumbWidth, height: thumbWidth, borderRadius: 12),
              ),
            ),
          );
        }
        return _buildThumbnailsFromDocs(snapshot.data!.docs, contentWidth);
      },
    );
  }
}
