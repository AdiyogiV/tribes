import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:tribes/pages/theatre.dart';
import 'package:tribes/widgets/postHeader.dart';
import 'package:tribes/widgets/postToolbar.dart';

class MainPlayer extends StatefulWidget {
  final String? author;
  final String? space;
  final String? videoUrl;
  final int? pageIndex;
  final int? pageDepth;
  final String? postId;
  final int? upVoteCount;
  final int? downVoteCount;
  final Map? upVotes;
  final Map? downVotes;
  final String? title;

  MainPlayer(
      {this.postId,
      this.space,
      this.author,
      this.videoUrl,
      this.pageIndex,
      this.pageDepth,
      this.upVotes,
      this.downVotes,
      this.upVoteCount,
      this.downVoteCount,
      this.title});

  @override
  _MainPlayer createState() => _MainPlayer();
}

class _MainPlayer extends State<MainPlayer> with WidgetsBindingObserver {
  bool isPlaying = false;
  VideoPlayerController? _controller;
  bool initialized = false;
  bool gameOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializePlayer();
  }

  // initializePlayer() async {
  //   await DefaultCacheManager().getSingleFile(widget.videoUrl).then((value) => {
  //         _controller = VideoPlayerController.file(value)
  //           ..initialize().then((_) {
  //             setState(() {
  //               initialized = true;
  //             });
  //           })
  //       });
  // }

  initializePlayer() async {
    File video = await DefaultCacheManager().getSingleFile(widget.videoUrl!);
    _controller = VideoPlayerController.file(video);
    await _controller!.initialize();
    await _controller!.setLooping(true);
    if (mounted)
      setState(() {
        initialized = true;
      });
  }

  toggleAudio(bool audio) {
    if (audio)
      _controller!.setVolume(100);
    else
      _controller!.setVolume(0);
  }

  isVisible(double visibility) {
    if (visibility == 1.0) {
      _controller!.play();
      Provider.of<PageIndexHolder>(context, listen: false)
          .setPost(widget.postId!);
    } else {
      _controller!.pause();
    }
  }

  double getRatio() {
    if (_controller!.value.aspectRatio > 1.5) {
      return 1.5;
    }
    if (_controller!.value.aspectRatio < 0.5) {
      return 0.5;
    }
    return _controller!.value.aspectRatio;
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(50.0),
          child: CircularProgressIndicator(
            color: Colors.indigo[700],
          ),
        ),
      );

    return VisibilityDetector(
      key: UniqueKey(),
      onVisibilityChanged: (VisibilityInfo info) {
        isVisible(info.visibleFraction);
        debugPrint("${info.visibleFraction} of my widget is visible");
      },
      child: AspectRatio(
        aspectRatio: getRatio(),
        child: Stack(
          children: <Widget>[
            VideoPlayer(_controller!),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                PostHeader(
                  uid: widget.author!,
                  space: widget.space!,
                ),
                Expanded(
                  child: Container(),
                ),
                if (widget.title != null)
                  Container(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15),
                      child: Text(
                        widget.title!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              blurRadius: 5,
                              color: Colors.black,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(3),
                ),
                PostToolbar(
                  postId: widget.postId!,
                ),
                VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: CupertinoTheme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller!.dispose();
  }
}
