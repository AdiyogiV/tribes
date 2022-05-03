import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:like_button/like_button.dart';
import 'package:yantra/pages/login.dart';
import 'package:yantra/services/functionsService.dart';

class PostToolbar extends StatefulWidget {
  final String postId;
  final int upVoteCount;
  final int downVoteCount;
  final Map upVotes;
  final Map downVotes;

  PostToolbar({
    this.postId,
    this.upVotes,
    this.downVotes,
    this.upVoteCount,
    this.downVoteCount,
  });

  @override
  _PostToolbarState createState() => _PostToolbarState();
}

class _PostToolbarState extends State<PostToolbar> {
  User user = FirebaseAuth.instance.currentUser;
  var inactiveColor = Colors.white;
  final upVoteColor = CupertinoColors.activeBlue;
  var downVoteColor = CupertinoColors.destructiveRed;
  bool upVoted = false;
  bool downVoted = false;

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

  checkStatus(userID) {
    if (widget.upVotes != null) {
      if (widget.upVotes[userID] == true) {
        setState(() {
          upVoted = true;
        });
      }
    }

    if (widget.downVotes != null) {
      if (widget.downVotes[userID] == true) {
        setState(() {
          downVoted = true;
        });
      }
    }
  }



  onUpVotePressed() async {
    FunctionsService().upVotePressed(widget.postId);
  }

  onDownVotePressed() async {
    FunctionsService().downVotePressed(widget.postId);
  }

  onSharePressed() {}

  onBookmarkPressed() {}

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Row(
          children: <Widget>[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: LikeButton(
                onTap: (isLiked) async {
                  if(user==null){
                    requestLogin();
                    return false;
                  } else {
                    onUpVotePressed();
                    upVoted = !upVoted;
                    return !isLiked;
                  }

                },
                isLiked: upVoted,
                likeCount: widget.upVoteCount,
                likeBuilder: (bool isLiked) {
                  return Icon(
                    Icons.arrow_upward,
                    color: isLiked ? upVoteColor : inactiveColor,
                    size: isLiked ? 32 : 24,
                  );
                },
                countBuilder: (int count, bool isLiked, String text) {
                  var color = isLiked ? upVoteColor : inactiveColor;
                  Widget result;
                  result = Text(
                    text,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: color,
                      shadows: [
                        Shadow(
                          color: isLiked ? inactiveColor : upVoteColor,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  );
                  return result;
                },
              ),
            ),
          ],
        ));
  }
}
