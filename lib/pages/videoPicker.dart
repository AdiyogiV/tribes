import 'dart:io';
import 'dart:isolate';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import 'package:yantra/services/databaseService.dart';

class VideoPicker extends StatefulWidget {
  final String space;
  final int sourceItem;
  final String videoPath;
  final String replyTo;

  VideoPicker({
    this.space,
    this.videoPath,
    this.sourceItem,
    this.replyTo,
  });
  @override
  _VideoPickerState createState() => _VideoPickerState();
}

class _VideoPickerState extends State<VideoPicker> {
  File mainVideo;
  final picker = ImagePicker();
  VideoPlayerController _controller;
  User user = FirebaseAuth.instance.currentUser;
  bool isPlaying = false;

  String mainVideoPath;
  String thumbnailPath;
  String title;
  bool thumbnailReady = false;
  int status = -1;
  bool addToSpaceFeed = false;
  bool canAddToSpaceFeed = false;

  final snackBar = SnackBar(
    content: Text('Yay! A SnackBar!'),
    action: SnackBarAction(
      label: 'Undo',
      onPressed: () {
        // Some code to undo the change.
      },
    ),
  );

  @override
  void initState() {
    super.initState();
    if (widget.videoPath == null) {
      getItem();
    } else {
      setItem(File(widget.videoPath));
    }
    getInfo();
  }

  @override
  void dispose() {
    super.dispose();
    _controller?.dispose();
  }

  getInfo() async {
    if (widget.replyTo != null) {
      String space = await DatabaseService().getPostSpace(widget.replyTo);
      canAddToSpaceFeed =
          await DatabaseService().checkSpaceFeedPostingPermissions(space);
      setState(() {});
    }
  }

  Future getItem() async {
    var pickedFile;
    if (widget.sourceItem == 1) {
      pickedFile = await picker.getVideo(source: ImageSource.gallery);
    } else {
      pickedFile = await picker.getVideo(source: ImageSource.camera);
    }
    if (pickedFile == null) {
      Navigator.pop(context);
    } else {
      //await compressVideo(pickedFile.path);
      setItem(File(pickedFile.path));
    }
  }

  setItem(File _file) {
    _controller = VideoPlayerController.file(_file)
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {
          mainVideo = _file;
          mainVideoPath = _file.path;
          _controller.setLooping(true);
        });
      });
  }

  createThumbnail(String _path) async {
    final thumbnailFile = await VideoCompress.getFileThumbnail(_path,
        quality: 50, // default(100)
        position: -1 // default(-1)
        );
    setState(() {
      thumbnailPath = thumbnailFile.path;
      thumbnailReady = true;
    });
  }

  compressVideo(String _path) async {
    final info = await VideoCompress.compressVideo(_path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 100);
    return info.path;
  }

  addToDatabase() async {
    setState(() {
      status = 0;
    });
    await createThumbnail(mainVideoPath);
    //var video = await compressVideo(mainVideoPath);
    bool res = await DatabaseService(uid: user.uid).addSpacePost(widget.space,
        mainVideoPath, thumbnailPath, title, widget.replyTo, addToSpaceFeed);
    if (res)
      setState(() {
        status = 1;
      });
    return res;
  }

  Widget postButton() {
    if (status == -1) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "Post",
          style: TextStyle(fontSize: 15, color: CupertinoColors.white),
        ),
      );
    }
    if (status == 0) {
      return Padding(
        padding: const EdgeInsets.all(2.0),
        child: RefreshProgressIndicator(),
      );
    }
    if (status == 1) {
      return Icon(
        CupertinoIcons.check_mark,
        color: CupertinoColors.activeGreen,
      );
    }
    if (status == 2) {
      return Text(
        "Try Again",
        style: TextStyle(fontSize: 15, color: CupertinoColors.destructiveRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (mainVideoPath == null)
      return Container(
        color: CupertinoColors.white,
        padding: EdgeInsets.only(top: 300),
        child: Container(
            child: new Column(
          children: [
            Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
            new Text(
              "Processing video..",
              style: TextStyle(
                fontSize: 6,
              ),
            ),
          ],
        )),
      );
    if (mainVideo.lengthSync() > 1073741824) {
      return CupertinoAlertDialog(
        title: Text(
          "Size Limit Exceeded",
          style: TextStyle(color: CupertinoColors.destructiveRed),
        ),
        content: Text('Video size should be less than 1 GB'),
        actions: <Widget>[
          FlatButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Go Back',
              )),
          FlatButton(
              onPressed: () {
                getItem();
              },
              child: Text(
                'Try Again',
                style: TextStyle(color: CupertinoColors.activeBlue),
              ))
        ],
      );
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (status == -1 || status == 2) {
            if (await addToDatabase()) Navigator.of(context).pop();
          }
        },
        backgroundColor: CupertinoTheme.of(context).primaryColor,
        label: postButton(),
      ),
      body: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: GestureDetector(
              onTap: () {
                if (!isPlaying) {
                  setState(() {
                    isPlaying = true;
                    _controller.play();
                  });
                } else {
                  setState(() {
                    isPlaying = false;
                    _controller.pause();
                  });
                }
              },
              child: Icon(isPlaying
                  ? CupertinoIcons.pause_solid
                  : CupertinoIcons.play_arrow_solid)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                if (canAddToSpaceFeed)
                  Container(
                    padding: EdgeInsets.all(15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add To Space Feed',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: CupertinoTheme.of(context).primaryColor),
                        ),
                        CupertinoSwitch(
                            value: addToSpaceFeed,
                            onChanged: (onChanged) {
                              setState(() {
                                addToSpaceFeed = onChanged;
                              });
                            })
                      ],
                    ),
                  ),
                AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller)),
                VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                      playedColor: CupertinoTheme.of(context).primaryColor),
                ),
                // CupertinoTextField(
                //   inputFormatters: [
                //     LengthLimitingTextInputFormatter(30),
                //   ],
                //   padding: EdgeInsets.all(15),
                //   placeholder: 'Add a title to your post (< 30 letters)',
                //   onChanged: (val) {
                //     setState(() {
                //       title = val;
                //     });
                //   },
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
