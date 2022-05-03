import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yantra/pages/spaces/space.dart';
import 'package:yantra/pages/userProfile.dart';
import 'package:yantra/widgets/previewBoxes/userPreviewBox.dart';
import 'package:yantra/widgets/previewBoxes/spacePreviewBox.dart';

typedef ReplyCallback = void Function(String uid, int PN);

class PostHeader extends StatefulWidget {
  final String uid;
  final String space;
  PostHeader({this.uid, this.space});

  @override
  _PostHeaderState createState() => _PostHeaderState();
}

class _PostHeaderState extends State<PostHeader> {
  @override
  void initState() {
    super.initState();
    print(widget.space);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0, top: 4.0),
      child: Column(
        children: [
          // if (widget.space != null && widget.uid != widget.space)
          //   GestureDetector(
          //     onTap: () {
          //       Navigator.of(context)
          //           .push(CupertinoPageRoute(builder: (context) {
          //         return SpaceBox(
          //           rid: widget.space,
          //         );
          //       }));
          //     },
          //     child: Padding(
          //       padding: const EdgeInsets.only(top: 0.0),
          //       child: Container(
          //           width: 40,
          //           child: SpacePreviewBox(
          //             space: widget.space,
          //           )),
          //     ),
          //   ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(CupertinoPageRoute(builder: (context) {
                return UserProfilePage(
                  uid: widget.uid,
                );
              }));
            },
            child: Padding(
              padding: const EdgeInsets.all(0.0),
              child: Container(
                  width: 40,
                  child: UserPreview(
                    uid: widget.uid,
                    showName: false,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}
