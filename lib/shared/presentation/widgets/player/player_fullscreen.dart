import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:aurogram/shared/services/media/global_audio_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/player/player_controls.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Fullscreen video page
class FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final bool wasPlaying;
  final GlobalAudioService globalAudioService;

  const FullscreenVideoPage({
    super.key,
    required this.controller,
    required this.wasPlaying,
    required this.globalAudioService,
  });

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage> {
  bool _showControls = true;
  Timer? _hideControlsTimer;

  bool get _isControllerValid {
    try {
      return widget.controller.value.isInitialized;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    if (_isControllerValid) {
      widget.controller.addListener(_onVideoUpdate);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isControllerValid) {
          widget.controller.play();
          _startHideControlsTimer();
        }
      });
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    if (_isControllerValid) {
      try {
        widget.controller.removeListener(_onVideoUpdate);
      } catch (e) {
        // Ignore
      }
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isControllerValid && widget.controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideControlsTimer();
  }

  void _togglePlayPause() {
    if (!_isControllerValid) {
      Navigator.of(context).pop();
      return;
    }
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
      setState(() => _showControls = true);
    } else {
      widget.controller.play();
      _startHideControlsTimer();
    }
    setState(() {});
  }

  void _toggleMute() {
    widget.globalAudioService.toggleGlobalMute();
    setState(() {});
  }

  void _seekRelative(Duration offset) {
    if (!_isControllerValid) return;
    final current = widget.controller.value.position;
    widget.controller.seekTo(current + offset);
    _startHideControlsTimer();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isControllerValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    final value = widget.controller.value;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),

            // Controls overlay
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0.0, 0.2, 0.8, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingLg),
                        child: Row(
                          children: [
                            FullscreenButton(
                              icon: CupertinoIcons.xmark,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            const Spacer(),
                            FullscreenButton(
                              icon: widget.globalAudioService.isGloballyMuted
                                  ? CupertinoIcons.speaker_slash_fill
                                  : CupertinoIcons.speaker_2_fill,
                              onTap: _toggleMute,
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Center controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FullscreenButton(
                            icon: CupertinoIcons.gobackward_10,
                            onTap: () =>
                                _seekRelative(const Duration(seconds: -10)),
                            size: 48,
                          ),
                          const SizedBox(width: 40),
                          FullscreenButton(
                            icon: value.isPlaying
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            onTap: _togglePlayPause,
                            size: 72,
                            isPrimary: true,
                          ),
                          const SizedBox(width: 40),
                          FullscreenButton(
                            icon: CupertinoIcons.goforward_10,
                            onTap: () =>
                                _seekRelative(const Duration(seconds: 10)),
                            size: 48,
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Bottom bar with progress
                      Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingLg),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 20,
                              child: VideoProgressIndicator(
                                widget.controller,
                                allowScrubbing: true,
                                padding:
                                    const EdgeInsets.symmetric(vertical: AppDimensions.paddingSm),
                                colors: VideoProgressColors(
                                  playedColor: AppTheme.primaryColor,
                                  bufferedColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.3),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingSm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(value.position),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                                Text(
                                  _formatDuration(value.duration),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
