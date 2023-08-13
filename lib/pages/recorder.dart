import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:tribes/pages/videoPicker.dart';

List<CameraDescription> cameras = [];

class Recorder extends StatefulWidget {
  final String? space;
  final String? replyTo;

  const Recorder({this.replyTo, this.space}) : super();

  @override
  _CameraExampleHomeState createState() => _CameraExampleHomeState();
}

class _CameraExampleHomeState extends State<Recorder>
    with WidgetsBindingObserver {
  CameraController? controller;
  String? videoPath;
  VideoPlayerController? videoController;
  VoidCallback? videoPlayerListener;
  bool enableAudio = true;
  double? vidSize;
  bool processingVideo = false;
  bool frontCam = true;
  bool isRecording = false;
  bool isPaused = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: (widget.replyTo == null) ? Text('Add Post') : Text('Add Reply'),
      ),
      key: _scaffoldKey,
      child: SafeArea(
        child: (controller == null)
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    Container(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Material(
                            elevation: 5,
                            borderRadius: BorderRadius.circular(10),
                            clipBehavior: Clip.antiAlias,
                            child: CameraPreview(controller!)),
                      ), // this is my CameraPreview
                    ),
                    controlWidget(),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    prepareCam();
  }

  void prepareCam() async {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
    print(cameras.length);
    controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
    );
    controller!.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  Widget controlWidget() {
    return Container(
      child: Padding(
        padding: EdgeInsets.only(top: 20),
        child: (isRecording)
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  CupertinoButton(
                    onPressed: () {},
                    child: Container(
                      width: 30,
                    ),
                  ),
                  CupertinoButton(
                      child: Icon(
                        Icons.stop,
                        size: 60,
                        color: CupertinoColors.destructiveRed,
                      ),
                      onPressed: () {
                        setState(() {
                          isRecording = false;
                          isPaused = false;
                        });
                        onStopButtonPressed();
                      }),
                  CupertinoButton(
                      child: (isPaused)
                          ? Icon(
                              CupertinoIcons.play_arrow_solid,
                              size: 30,
                              color: Colors.black45,
                            )
                          : Icon(
                              CupertinoIcons.pause_solid,
                              size: 30,
                              color: Colors.black45,
                            ),
                      onPressed: () {
                        if (isPaused)
                          onResumeButtonPressed();
                        else
                          onPauseButtonPressed();
                        setState(() {
                          isPaused = !isPaused;
                        });
                      }),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  //Container(width: 60,),
                  CupertinoButton(
                      child: Icon(
                        CupertinoIcons.folder,
                        size: 30,
                      ),
                      onPressed: () {
                        final act = CupertinoActionSheet(
                            title: Text('Select Video Source'),
                            actions: <Widget>[
                              CupertinoActionSheetAction(
                                child: Text(
                                  "Pick from Gallery",
                                  style: TextStyle(
                                      color: CupertinoColors.activeBlue),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                      CupertinoPageRoute(builder: (context) {
                                    return VideoPicker(
                                      sourceItem: 1,
                                      replyTo: widget.replyTo,
                                      space: widget.space,
                                    );
                                  })).then((value) => {
                                        print('value: $value'),
                                        Navigator.of(context).pop(),
                                        Navigator.of(context).pop(),
                                      });
                                },
                              ),
                              CupertinoActionSheetAction(
                                child: Text(
                                  "Record with Phone Camera",
                                  style: TextStyle(
                                      color: CupertinoColors.activeBlue),
                                ),
                                onPressed: () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pop();
                                  Navigator.of(context).push(
                                      CupertinoPageRoute(builder: (context) {
                                    return VideoPicker(
                                      sourceItem: 2,
                                      replyTo: widget.replyTo,
                                      space: widget.space,
                                    );
                                  }));
                                },
                              )
                            ],
                            cancelButton: CupertinoActionSheetAction(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                    color: CupertinoColors.destructiveRed),
                              ),
                              onPressed: () {
                                Navigator.of(context, rootNavigator: true)
                                    .pop();
                              },
                            ));
                        showCupertinoModalPopup(
                            context: context,
                            builder: (BuildContext context) => act);
                      }),
                  CupertinoButton(
                      child: Icon(
                        CupertinoIcons.circle_filled,
                        size: 60,
                        color: CupertinoColors.destructiveRed,
                      ),
                      onPressed: () {
                        setState(() {
                          isRecording = true;
                          onVideoRecordButtonPressed();
                        });
                      }),
                  CupertinoButton(
                      child: Icon(
                        CupertinoIcons.switch_camera,
                        size: 30,
                      ),
                      onPressed: () {
                        if (frontCam) {
                          frontCam = false;
                          onNewCameraSelected(cameras[0]);
                        } else {
                          frontCam = true;
                          onNewCameraSelected(cameras[1]);
                        }
                      }),
                ],
              ),
      ),
    );
  }

  /// Display a row of toggle to select the camera (or a message if no camera is available).

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    if (controller == null) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      //controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(controller!.description);
    }
  }

  /// Display the preview from the camera (or a message if the preview is not available).

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    videoController!.dispose();
    controller!.dispose();
    super.dispose();
  }

  /// Display the control bar with buttons to take pictures and record videos.

  void onVideoRecordButtonPressed() {
    startVideoRecording();
    setState(() {});
  }

  void onStopButtonPressed() {
    setState(() {
      processingVideo = true;
    });
    stopVideoRecording();
  }

  void onPauseButtonPressed() {
    pauseVideoRecording().then((_) {
      if (mounted) setState(() {});
      //showInSnackBar('Video recording paused');
    });
  }

  void onResumeButtonPressed() {
    resumeVideoRecording().then((_) {
      if (mounted) setState(() {});
      //showInSnackBar('Video recording resumed');
    });
  }

  Future<void> startVideoRecording() async {
    if (!controller!.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }
    if (controller!.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      return null;
    }
    try {
      await controller!.startVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return;
  }

  Future<void> stopVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      return null;
    }
    try {
      var file = await controller!.stopVideoRecording();
      setState(() {
        processingVideo = false;
      });
      Navigator.of(context).push(CupertinoPageRoute(builder: (context) {
        return VideoPicker(
          videoPath: file.path,
          replyTo: widget.replyTo,
          space: widget.space,
        );
      })).then((value) => {
            Navigator.of(context).pop(),
            Navigator.of(context).pop(),
          });
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  Future<void> pauseVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      return null;
    }

    try {
      await controller!.pauseVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> resumeVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      return null;
    }

    try {
      await controller!.resumeVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    await controller!.dispose();
    controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: enableAudio,
    );

    // If the controller is updated then update the UI.
    controller!.addListener(() {
      if (mounted) setState(() {});
      if (controller!.value.hasError) {
        showInSnackBar('Camera error ${controller!.value.errorDescription}');
      }
    });

    try {
      await controller!.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    // _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCameraException(CameraException e) {
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}

IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
  }
  throw ArgumentError('Unknown lens direction');
}

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');
