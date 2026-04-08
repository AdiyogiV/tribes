import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:aurogram/features/calling/presentation/widgets/call_audio_view.dart';
import 'package:aurogram/features/calling/presentation/widgets/call_permission_banner.dart';
import 'package:aurogram/features/calling/presentation/widgets/call_video_layout.dart';
import 'package:aurogram/features/calling/domain/call_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

/// Full-screen call UI for voice and video calls using WebRTC
class CallScreen extends StatefulWidget {
  final String calleeId;
  final String calleeName;
  final String? calleeAvatar;
  final CallType callType;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.calleeId,
    required this.calleeName,
    this.calleeAvatar,
    required this.callType,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final CallService _callService = CallService();

  // WebRTC renderers
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  CallState _callState = CallState.idle;
  bool _isEnding = false;
  bool _isDisposed = false;

  // Control states (tracked locally for UI)
  bool _isMuted = false;
  bool _isCameraOff =
      true; // Start with camera off (will be synced from service)
  bool _isSpeakerOn = true;
  bool _isLocalVideoLarge = false;

  // Local video preview position (for dragging)
  Offset? _localVideoPosition;

  // Timer
  Timer? _callTimer;
  final ValueNotifier<int> _callDuration = ValueNotifier<int>(0);
  Timer? _permissionErrorTimer;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _ringController;
  late AnimationController _dotsController;

  // Track initialization state
  bool _renderersInitialized = false;
  bool _initializationFailed = false;

  // Store streams that arrive before renderers are ready
  MediaStream? _pendingLocalStream;
  MediaStream? _pendingRemoteStream; // ignore: unused_field

  // Only schedule deferred remote attach once per call (avoids multiple setState from repeated build)
  bool _deferredAttachScheduled = false;

  // Permission error banner state
  String? _permissionError;

  @override
  void initState() {
    super.initState();

    AppLogger.d('CallScreen init (incoming: ${widget.isIncoming})',
        category: LogCategory.general);

    // Register lifecycle observer for proper cleanup
    WidgetsBinding.instance.addObserver(this);

    // Enable wakelock on mobile only (web handles this differently)
    if (!kIsWeb) {
      WakelockPlus.enable();
    }
    _setupAnimations();
    _setupCallService();

    // Initialize renderers first, then start call
    _initializeAndStartCall();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle app lifecycle changes to prevent GPU resource conflicts
    if (state == AppLifecycleState.paused) {
      AppLogger.d('CallScreen: App paused, pausing video',
          category: LogCategory.general);
      // Disable video when app is backgrounded to free GPU resources
      if (!_isCameraOff && _callState == CallState.connected) {
        _callService.toggleCamera();
      }
    } else if (state == AppLifecycleState.resumed) {
      AppLogger.d('CallScreen: App resumed', category: LogCategory.general);
      // Re-enable video when app returns to foreground (if video capability exists)
      if (_isCameraOff &&
          _callState == CallState.connected &&
          _callService.hasVideoTrack) {
        _callService.toggleCamera();
      }
    }
  }

  /// Initialize renderers and then start the call
  Future<void> _initializeAndStartCall() async {
    try {
      await _initRenderers();
      _renderersInitialized = true;

      if (!mounted) return;

      if (widget.isIncoming) {
        // Always answer the call - CallScreen handles the full process
        setState(() => _callState = CallState.incoming);
        _answerCall();
      } else {
        _startCall();
      }
    } catch (e) {
      AppLogger.e('Failed to initialize call renderers',
          category: LogCategory.general, error: e);
      _initializationFailed = true;
      if (mounted) {
        _showError('Failed to initialize call. Please try again.');
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _initRenderers() async {
    try {
      _localRenderer = RTCVideoRenderer();
      _remoteRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();
      await _remoteRenderer!.initialize();
      _renderersInitialized = true;

      // Don't attach remote stream here - let build() defer attach after video UI frame
      _pendingRemoteStream = null;

      // Attach pending or existing local stream
      final localStream = _pendingLocalStream ?? _callService.localStream;
      if (localStream != null) {
        final videoTracks = localStream.getVideoTracks();
        if (videoTracks.isNotEmpty) _isCameraOff = !videoTracks[0].enabled;
        setState(() => _localRenderer?.srcObject = localStream);
        _pendingLocalStream = null;
      }
    } catch (e) {
      AppLogger.e('Failed to initialize WebRTC renderers',
          category: LogCategory.general, error: e);
      await _safeDisposeRenderer(_localRenderer);
      await _safeDisposeRenderer(_remoteRenderer);
      _localRenderer = null;
      _remoteRenderer = null;
      rethrow;
    }
  }

  /// Safely dispose a single renderer
  Future<void> _safeDisposeRenderer(RTCVideoRenderer? renderer) async {
    if (renderer == null) return;
    try {
      renderer.srcObject = null;
      // Minimal delay to let the frame complete
      await Future.delayed(const Duration(milliseconds: 16));
      await renderer.dispose();
    } catch (e) {
      AppLogger.w('Error disposing renderer: $e',
          category: LogCategory.general);
    }
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _ringController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  void _setupCallService() {
    _callService.onPermissionError = (error) {
      if (!mounted) return;
      _permissionErrorTimer?.cancel();
      setState(() => _permissionError = error);
      _permissionErrorTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _permissionError = null);
      });
    };

    _callService.onCallStateChanged = (state) {
      if (_isDisposed || !mounted) return;
      if (!_isEnding) setState(() => _callState = state);

      if (state == CallState.connected) {
        _startCallTimer();
        _pulseController.stop();
        _ringController.stop();
        _dotsController.stop();
        if (mounted) {
          setState(() {
            _isCameraOff = _callService.isCameraOff;
            _isMuted = _callService.isMuted;
            _isSpeakerOn = _callService.isSpeakerOn;
          });
        }
      } else if (state == CallState.ended) {
        _callTimer?.cancel();
        if (!_isEnding) {
          _isEnding = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDisposed) Navigator.of(context).pop();
          });
        }
      } else if (state == CallState.idle) {
        if (!_isEnding && _callState != CallState.idle) {
          _isEnding = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDisposed) Navigator.of(context).pop();
          });
        }
      }
    };

    _callService.onLocalStream = (stream) {
      // Sync camera state immediately when stream arrives
      if (mounted && !_isDisposed) {
        final videoTracks = stream.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          setState(() => _isCameraOff = !videoTracks[0].enabled);
        }
      }
      if (!_renderersInitialized || _initializationFailed) {
        _pendingLocalStream = stream;
        return;
      }
      if (mounted && !_isDisposed) {
        setState(() => _localRenderer?.srcObject = stream);
      }
    };

    _callService.onRemoteStream = (stream) {
      if (!_renderersInitialized || _initializationFailed) {
        _pendingRemoteStream = stream;
        return;
      }
      // Attach immediately so RTCVideoView has the stream on the renderer.
      final renderer = _remoteRenderer;
      if (mounted && !_isDisposed && renderer != null) {
        for (final track in stream.getVideoTracks()) {
          if (!track.enabled) track.enabled = true;
        }
        setState(() => renderer.srcObject = stream);
      }
    };

    // Sync initial state from service (handles race on web)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed) return;
      final serviceState = _callService.state;
      if (serviceState != _callState) {
        setState(() => _callState = serviceState);
        if (serviceState == CallState.connected) {
          _startCallTimer();
          _pulseController.stop();
          _ringController.stop();
          _dotsController.stop();
        }
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Clear callbacks FIRST to prevent firing on disposed widget
    _callService.onCallStateChanged = null;
    _callService.onLocalStream = null;
    _callService.onRemoteStream = null;
    _callService.onPermissionError = null;

    // IMPORTANT: End the call if it's still active when screen is disposed
    // This catches edge cases where dispose is called without going through _endCall()
    if (!_isEnding &&
        _callState != CallState.ended &&
        _callState != CallState.idle) {
      AppLogger.w('CallScreen disposed while call still active - ending call',
          category: LogCategory.general);
      _callService.endCall();
    }

    // Disable wakelock on mobile only
    if (!kIsWeb) {
      WakelockPlus.disable();
    }
    _callTimer?.cancel();
    _permissionErrorTimer?.cancel();
    _callDuration.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    _dotsController.dispose();

    // Safely dispose renderers with proper sequencing
    _disposeRenderers();

    super.dispose();
  }

  /// Safely dispose WebRTC renderers with proper cleanup order
  /// This helps prevent GPU resource conflicts and memory leaks
  void _disposeRenderers() {
    // Step 1: Clear srcObject references first (disconnects from WebRTC streams)
    try {
      _localRenderer?.srcObject = null;
      _remoteRenderer?.srcObject = null;
    } catch (e) {
      AppLogger.w('Error clearing renderer srcObject: $e',
          category: LogCategory.general);
    }

    // Step 2: Schedule renderer disposal on next frame to allow GPU cleanup
    // This is critical for preventing Mali GPU driver crashes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Minimal delay - just enough to let the frame complete
        await Future.delayed(const Duration(milliseconds: 16));

        await _localRenderer?.dispose();
        _localRenderer = null;

        await _remoteRenderer?.dispose();
        _remoteRenderer = null;

        AppLogger.d('WebRTC renderers disposed successfully',
            category: LogCategory.general);
      } catch (e) {
        AppLogger.w('Error disposing renderers: $e',
            category: LogCategory.general);
      }
    });
  }

  Future<void> _startCall() async {
    setState(() => _callState = CallState.ringing);

    final success = await _callService.startCall(
      calleeId: widget.calleeId,
      calleeName: widget.calleeName,
      calleeAvatar: widget.calleeAvatar,
      type: widget.callType,
    );

    if (!success && mounted) {
      _showError('Failed to start call');
      Navigator.of(context).pop();
    }
  }

  Future<void> _answerCall() async {
    AppLogger.d('📞 CallScreen: Starting to answer incoming call...',
        category: LogCategory.general);

    final success = await _callService.answerCall();

    AppLogger.d('📞 CallScreen: answerCall returned: $success',
        category: LogCategory.general);

    if (!success && mounted) {
      AppLogger.e('📞 CallScreen: Failed to answer call, popping screen',
          category: LogCategory.general);
      _showError('Failed to answer call');
      Navigator.of(context).pop();
    }
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _callDuration.value++;
      }
    });
  }

  void _endCall() {
    if (_isEnding) return;
    _isEnding = true;

    _callTimer?.cancel();

    if (_callState != CallState.ended && _callState != CallState.idle) {
      _callService.endCall();
    }

    Future.microtask(() {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _toggleMute() async {
    final success = await _callService.toggleMute();
    if (success && mounted) {
      setState(() => _isMuted = !_isMuted);
    }
  }

  Future<void> _toggleCamera() async {
    final success = await _callService.toggleCamera();
    if (success && mounted) {
      setState(() => _isCameraOff = !_isCameraOff);
    }
  }

  Future<void> _switchCamera() async {
    await _callService.switchCamera();
  }

  Future<void> _toggleSpeaker() async {
    final newState = !_isSpeakerOn;
    final success = await _callService.toggleSpeaker(newState);
    if (success && mounted) {
      setState(() => _isSpeakerOn = newState);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showCustomSnackBar(context, message: message, backgroundColor: AppTheme.errorColor);
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Unified UI: Same layout and controls for voice and video when connected.
    // Voice calls use same screen (avatar/remote area + local PIP when camera on); camera off by default for voice but can be turned on.
    final hasLocalVideo =
        _localRenderer?.srcObject?.getVideoTracks().isNotEmpty ?? false;
    final hasRemoteVideoOnRenderer =
        _remoteRenderer?.srcObject?.getVideoTracks().isNotEmpty ?? false;
    final hasRemoteStreamFromService =
        _callService.remoteStream?.getVideoTracks().isNotEmpty ?? false;
    final hasRemoteVideo =
        hasRemoteVideoOnRenderer || hasRemoteStreamFromService;
    final showVideoUI = _callState == CallState.connected;

    if (kDebugMode) {
      AppLogger.d(
          '📹 CallScreen.build - state: $_callState, showVideoUI: $showVideoUI, hasLocalVideo: $hasLocalVideo, hasRemoteVideo: $hasRemoteVideo',
          category: LogCategory.general);
    }

    return PopScope(
      // Intercept back button to properly end the call
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // End the call when back button is pressed
        _endCall();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppTheme.callBackground,
          body: Stack(
            children: [
              showVideoUI
                  ? _buildUnifiedCallUI()
                  : CallAudioView(
                      calleeId: widget.calleeId,
                      calleeName: widget.calleeName,
                      calleeAvatar: widget.calleeAvatar,
                      callState: _callState,
                      isMuted: _isMuted,
                      isCameraOff: _isCameraOff,
                      isSpeakerOn: _isSpeakerOn,
                      hasVideoTrack: _callService.hasVideoTrack,
                      isVideoCall: widget.callType == CallType.video,
                      isDesktop: _isDesktopLayout,
                      callDuration: _callDuration,
                      pulseAnimation: _pulseAnimation,
                      ringController: _ringController,
                      dotsController: _dotsController,
                      onToggleMute: _toggleMute,
                      onToggleCamera: _toggleCamera,
                      onToggleSpeaker: _toggleSpeaker,
                      onFlipCamera: _switchCamera,
                      onEndCall: _endCall,
                    ),
              // Permission error banner at top (all platforms: mic/camera denial)
              if (_permissionError != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: CallPermissionBanner(
                      errorMessage: _permissionError!,
                      onDismiss: () {
                        setState(() {
                          _permissionError = null;
                        });
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Check if we should use desktop layout (web or large screen)
  bool get _isDesktopLayout {
    if (kIsWeb) return true;
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= 600; // Tablet/desktop breakpoint
  }

  /// Unified call UI - works for both video and voice calls
  /// Shows video when available, falls back to audio UI when not
  /// Responsive: uses different layouts for mobile vs desktop/web
  Widget _buildUnifiedCallUI() {
    final remoteRenderer = _remoteRenderer;
    final localRenderer = _localRenderer;

    // Defer attach remote stream until after this frame so native view exists and has layout (fixes remote not visible)
    final remoteStream = _callService.remoteStream;
    final shouldAttach = _callState == CallState.connected &&
        remoteStream != null &&
        remoteRenderer != null &&
        remoteRenderer.srcObject != remoteStream;
    if (shouldAttach && !_deferredAttachScheduled) {
      _deferredAttachScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed || _remoteRenderer == null) return;
        final stream = _callService.remoteStream;
        if (stream == null) return;
        for (final track in stream.getVideoTracks()) {
          if (!track.enabled) track.enabled = true;
        }
        AppLogger.i(
            '📹 CallScreen: Attaching remote stream to renderer (deferred)',
            category: LogCategory.general);
        setState(() {
          final r = _remoteRenderer;
          if (r != null) r.srcObject = stream;
        });
      });
    }

    // Initialize local video position if not set
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final pipWidth = _isDesktopLayout
        ? (_isLocalVideoLarge ? 240.0 : 180.0)
        : (_isLocalVideoLarge ? 180.0 : 120.0);
    _localVideoPosition ??= Offset(
      screenSize.width - pipWidth - (_isDesktopLayout ? 32.0 : 16.0),
      topPadding + 16.0,
    );

    void toggleSize() => setState(() => _isLocalVideoLarge = !_isLocalVideoLarge);
    void updatePos(Offset p) => setState(() => _localVideoPosition = p);

    if (_isDesktopLayout) {
      return CallDesktopVideoLayout(
        remoteRenderer: remoteRenderer, localRenderer: localRenderer,
        hasRemoteStreamFromService: _callService.remoteStream != null,
        calleeId: widget.calleeId, calleeName: widget.calleeName,
        calleeAvatar: widget.calleeAvatar,
        isMuted: _isMuted, isCameraOff: _isCameraOff, isSpeakerOn: _isSpeakerOn,
        isConnected: _callState == CallState.connected,
        hasVideoTrack: _callService.hasVideoTrack,
        isVideoCall: widget.callType == CallType.video,
        isLocalVideoLarge: _isLocalVideoLarge,
        localVideoPosition: _localVideoPosition!,
        callDuration: _callDuration, formatDuration: _formatDuration,
        onToggleMute: _toggleMute, onToggleCamera: _toggleCamera,
        onToggleSpeaker: _toggleSpeaker, onFlipCamera: _switchCamera,
        onEndCall: _endCall, onToggleLocalVideoSize: toggleSize,
        onLocalVideoPositionChanged: updatePos,
      );
    }
    return CallMobileVideoLayout(
      remoteRenderer: remoteRenderer, localRenderer: localRenderer,
      hasRemoteStreamFromService: _callService.remoteStream != null,
      calleeId: widget.calleeId, calleeName: widget.calleeName,
      calleeAvatar: widget.calleeAvatar,
      isMuted: _isMuted, isCameraOff: _isCameraOff, isSpeakerOn: _isSpeakerOn,
      isConnected: _callState == CallState.connected,
      hasVideoTrack: _callService.hasVideoTrack,
      isVideoCall: widget.callType == CallType.video,
      isDesktopLayout: false,
      isLocalVideoLarge: _isLocalVideoLarge,
      localVideoPosition: _localVideoPosition!,
      callDuration: _callDuration, formatDuration: _formatDuration,
      onToggleMute: _toggleMute, onToggleCamera: _toggleCamera,
      onToggleSpeaker: _toggleSpeaker, onFlipCamera: _switchCamera,
      onEndCall: _endCall, onToggleLocalVideoSize: toggleSize,
      onLocalVideoPositionChanged: updatePos,
    );
  }
}
