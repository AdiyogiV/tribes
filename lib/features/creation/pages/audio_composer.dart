import 'dart:io';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/feed/data/datasources/firebase_post_repository.dart';
import 'package:path/path.dart' as path;
import 'package:aurogram/core/theme/app_dimensions.dart';

enum RecordingState {
  idle,
  recording,
  stopped,
}

class AudioComposer extends StatefulWidget {
  final String space;
  final String? replyTo;
  final VoidCallback? onUploadStarted;
  final bool isProfilePost;

  const AudioComposer({
    super.key,
    required this.space,
    this.replyTo,
    this.onUploadStarted,
    this.isProfilePost = false,
  });

  @override
  AudioComposerState createState() => AudioComposerState();
}

class AudioComposerState extends State<AudioComposer>
    with TickerProviderStateMixin {
  final FlutterSoundRecorder _recorder =
      FlutterSoundRecorder(logLevel: kDebugMode ? Level.debug : Level.off);
  final FlutterSoundPlayer _player =
      FlutterSoundPlayer(logLevel: kDebugMode ? Level.debug : Level.off);

  RecordingState _recordingState = RecordingState.idle;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  Timer? _playbackTimer;

  bool _isPosting = false;
  bool addToSpaceFeed = true;
  bool canAddToSpaceFeed = false;
  String? title;
  bool _showTitleInput = false;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  // Waveform visualization
  final List<double> _waveformBars = List.generate(40, (_) => 0.15);
  Timer? _waveformTimer;

  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _initializeSpaceFeedSettings();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeRecorder() async {
    try {
      await _recorder.openRecorder();
      await _player.openPlayer();

      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission denied');
      }

      AppLogger.i('Audio recorder initialized', category: LogCategory.voice);
    } catch (e) {
      AppLogger.e('Failed to initialize audio recorder',
          category: LogCategory.voice, error: e);
      if (mounted) {
        showCustomSnackBar(
          context,
          message: 'Failed to initialize audio recorder',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  Future<void> _initializeSpaceFeedSettings() async {
    if (widget.replyTo == null) {
      addToSpaceFeed = true;
    }

    if (widget.replyTo != null) {
      canAddToSpaceFeed = await DatabaseService()
          .checkSpaceFeedPostingPermissions(widget.space);
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    _waveformTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _scaleController.dispose();
    _titleController.dispose();
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  void _startWaveformAnimation() {
    _waveformTimer?.cancel();
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (mounted && _recordingState == RecordingState.recording) {
        setState(() {
          for (int i = 0; i < _waveformBars.length; i++) {
            _waveformBars[i] = 0.15 + math.Random().nextDouble() * 0.85;
          }
        });
      }
    });
  }

  void _stopWaveformAnimation() {
    _waveformTimer?.cancel();
    setState(() {
      for (int i = 0; i < _waveformBars.length; i++) {
        _waveformBars[i] = 0.15;
      }
    });
  }

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'voice_note_${DateTime.now().millisecondsSinceEpoch}.wav';
      _recordingPath = path.join(tempDir.path, fileName);

      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
      );

      setState(() {
        _recordingState = RecordingState.recording;
        _recordingDuration = Duration.zero;
        _showTitleInput = false;
      });

      _pulseController.repeat(reverse: true);
      _startWaveformAnimation();

      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (mounted && _recordingState == RecordingState.recording) {
          setState(() {
            _recordingDuration = Duration(milliseconds: timer.tick * 100);
          });
        }
      });

      AppLogger.i('Started recording voice note',
          category: LogCategory.voice, data: {'path': _recordingPath});
    } catch (e) {
      AppLogger.e('Failed to start recording',
          category: LogCategory.voice, error: e);
      _showError('Failed to start recording');
    }
  }

  Future<void> _stopRecording() async {
    HapticFeedback.lightImpact();

    try {
      await _recorder.stopRecorder();
      _recordingTimer?.cancel();
      _pulseController.stop();
      _pulseController.reset();
      _stopWaveformAnimation();

      setState(() {
        _recordingState = RecordingState.stopped;
        _showTitleInput = true;
      });

      AppLogger.i('Stopped recording voice note',
          category: LogCategory.voice,
          data: {'duration': _recordingDuration.inSeconds});
    } catch (e) {
      AppLogger.e('Failed to stop recording',
          category: LogCategory.voice, error: e);
      _showError('Failed to stop recording');
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
      _showError('No recording to play');
      return;
    }

    HapticFeedback.selectionClick();

    try {
      await _player.startPlayer(
        fromURI: _recordingPath!,
        codec: Codec.pcm16WAV,
        whenFinished: () {
          if (mounted) {
            setState(() {});
            _stopWaveformAnimation();
          }
        },
      );

      _startWaveformAnimation();
      setState(() {});
    } catch (e) {
      AppLogger.e('Failed to play recording',
          category: LogCategory.voice, error: e);
      _showError('Failed to play recording');
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _player.stopPlayer();
      _stopWaveformAnimation();
      setState(() {});
    } catch (e) {
      AppLogger.e('Failed to stop playback',
          category: LogCategory.voice, error: e);
    }
  }

  void _deleteRecording() {
    HapticFeedback.mediumImpact();

    if (_recordingPath != null) {
      try {
        File(_recordingPath!).deleteSync();
        setState(() {
          _recordingPath = null;
          _recordingState = RecordingState.idle;
          _recordingDuration = Duration.zero;
          _showTitleInput = false;
        });
        _titleController.clear();
        AppLogger.i('Deleted voice recording', category: LogCategory.voice);
      } catch (e) {
        AppLogger.e('Failed to delete recording',
            category: LogCategory.voice, error: e);
      }
    }
  }

  Future<void> _handlePost() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('You need to be signed in to post');
      return;
    }

    if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
      _showError('No voice note to post');
      return;
    }

    if (_recordingDuration.inSeconds < 1) {
      _showError('Voice note too short');
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _isPosting = true;
    });

    try {
      widget.onUploadStarted?.call();

      final repository = FirebasePostRepository();
      String? postId = await repository.addAudioPost(
        widget.space,
        _recordingPath!,
        _recordingDuration,
        title,
        widget.replyTo,
        addToSpaceFeed,
        isProfilePost: widget.isProfilePost,
      );

      if (postId != null && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);

        showCustomSnackBar(
          context,
          message: widget.replyTo == null
              ? 'Voice note posted!'
              : 'Voice reply posted!',
          backgroundColor: AppTheme.successColor,
        );
      } else {
        throw Exception('Failed to create post');
      }
    } catch (e) {
      AppLogger.e('Failed to post voice note',
          category: LogCategory.voice, error: e);
      _showError('Failed to post. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      showCustomSnackBar(
        context,
        message: message,
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final tenths = (duration.inMilliseconds ~/ 100) % 10;

    if (_recordingState == RecordingState.recording) {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$tenths';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.scaffoldDarkColor : const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Minimal header
                _buildHeader(isDark),

                // Center content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Waveform visualization
                          _buildWaveform(isDark),

                          const SizedBox(height: AppDimensions.spacingLargeSection),

                          // Duration display
                          _buildDurationDisplay(isDark),

                          const SizedBox(height: AppDimensions.spacingMd),

                          // Status text
                          _buildStatusText(isDark),

                          const SizedBox(height: 48),

                          // Main control button
                          _buildMainButton(isDark, size),

                          const SizedBox(height: AppDimensions.spacingSection),

                          // Secondary controls (appear after recording)
                          if (_recordingState == RecordingState.stopped) ...[
                            _buildSecondaryControls(isDark),
                            const SizedBox(height: AppDimensions.spacingXxl),
                          ],

                          // Title input (appears after recording)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _showTitleInput ? 1.0 : 0.0,
                            child: AnimatedSlide(
                              duration: const Duration(milliseconds: 300),
                              offset: _showTitleInput ? Offset.zero : const Offset(0, 0.3),
                              child: _buildTitleInput(isDark),
                            ),
                          ),

                          // Space feed toggle (for replies)
                          if (_recordingState == RecordingState.stopped &&
                              widget.replyTo != null &&
                              canAddToSpaceFeed)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _buildSpaceFeedToggle(isDark),
                            ),

                          const SizedBox(height: 100), // Space for bottom button
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Post button (fixed at bottom)
            if (_recordingState == RecordingState.stopped)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: _buildPostButton(isDark),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Close button
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            icon: Icon(
              CupertinoIcons.xmark,
              color: isDark ? Colors.white70 : Colors.black54,
              size: 22,
            ),
          ),

          const Spacer(),

          // Title
          Text(
            widget.replyTo == null ? 'Voice Note' : 'Voice Reply',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
              letterSpacing: 0.5,
            ),
          ),

          const Spacer(),

          // Placeholder for symmetry
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildWaveform(bool isDark) {
    final primaryColor = AppTheme.primaryColor;
    final isActive = _recordingState == RecordingState.recording ||
        (_recordingState == RecordingState.stopped && _player.isPlaying);

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_waveformBars.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 4,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            height: 20 + (_waveformBars[index] * 60),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isActive
                  ? primaryColor.withValues(alpha: 0.4 + _waveformBars[index] * 0.6)
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDurationDisplay(bool isDark) {
    final isRecording = _recordingState == RecordingState.recording;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isRecording)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.errorColor,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.errorColor.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        Text(
          _formatDuration(_recordingDuration),
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w200,
            color: isDark ? Colors.white : Colors.black87,
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusText(bool isDark) {
    String text;
    switch (_recordingState) {
      case RecordingState.recording:
        text = 'Recording';
        break;
      case RecordingState.stopped:
        text = _player.isPlaying ? 'Playing' : 'Ready to post';
        break;
      default:
        text = 'Tap to record';
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white38 : Colors.black38,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildMainButton(bool isDark, Size size) {
    final isRecording = _recordingState == RecordingState.recording;
    final buttonSize = isRecording ? 88.0 : 80.0;

    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) => _scaleController.reverse(),
      onTapCancel: () => _scaleController.reverse(),
      onTap: () {
        if (_recordingState == RecordingState.recording) {
          _stopRecording();
        } else if (_recordingState == RecordingState.idle) {
          _startRecording();
        } else {
          // If stopped, tapping main button starts a new recording
          _deleteRecording();
          Future.delayed(const Duration(milliseconds: 100), _startRecording);
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value *
                (isRecording ? _pulseAnimation.value : 1.0),
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording
                    ? AppTheme.errorColor
                    : AppTheme.primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: (isRecording
                            ? AppTheme.errorColor
                            : AppTheme.primaryColor)
                        .withValues(alpha: 0.3),
                    blurRadius: isRecording ? 24 : 16,
                    spreadRadius: isRecording ? 4 : 0,
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isRecording
                        ? CupertinoIcons.stop_fill
                        : CupertinoIcons.mic_fill,
                    key: ValueKey(isRecording),
                    color: Colors.white,
                    size: isRecording ? 32 : 36,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSecondaryControls(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Delete button
        _buildSecondaryButton(
          icon: CupertinoIcons.trash,
          label: 'Delete',
          onTap: _deleteRecording,
          isDark: isDark,
          isDestructive: true,
        ),

        const SizedBox(width: 48),

        // Play/Pause button
        _buildSecondaryButton(
          icon: _player.isPlaying
              ? CupertinoIcons.pause_fill
              : CupertinoIcons.play_fill,
          label: _player.isPlaying ? 'Pause' : 'Play',
          onTap: _player.isPlaying ? _stopPlayback : _playRecording,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? AppTheme.errorColor
        : (isDark ? Colors.white70 : Colors.black54);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: TextField(
        controller: _titleController,
        onChanged: (value) => title = value.trim().isEmpty ? null : value,
        maxLength: 80,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'Add title (optional)',
          hintStyle: TextStyle(
            color: isDark ? Colors.white30 : Colors.black26,
            fontWeight: FontWeight.w400,
          ),
          counterText: '',
          border: InputBorder.none,
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
        ),
      ),
    );
  }

  Widget _buildSpaceFeedToggle(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => addToSpaceFeed = !addToSpaceFeed);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              addToSpaceFeed
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: addToSpaceFeed
                  ? AppTheme.primaryColor
                  : (isDark ? Colors.white38 : Colors.black26),
              size: 20,
            ),
            const SizedBox(width: AppDimensions.spacingMdSm),
            Text(
              'Add to space feed',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostButton(bool isDark) {
    final canPost = _recordingState == RecordingState.stopped &&
        _recordingPath != null &&
        !_isPosting;

    return GestureDetector(
      onTap: canPost ? _handlePost : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: canPost
              ? AppTheme.primaryColor
              : (isDark ? Colors.white12 : Colors.black12),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: canPost
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: _isPosting
              ? const AppLoadingIndicator(
                  color: Colors.white,
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.arrow_up_circle_fill,
                      color: canPost ? Colors.white : Colors.white38,
                      size: 22,
                    ),
                    const SizedBox(width: AppDimensions.spacingMdSm),
                    Text(
                      widget.replyTo == null ? 'Post' : 'Reply',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: canPost ? Colors.white : Colors.white38,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
