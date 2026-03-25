import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:aurogram/pages/call/widgets/call_controls.dart';
import 'package:aurogram/services/call_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

// Agent debug logging: only in debug mode to avoid prod network calls and log noise
void _agentDebugLog(String location, String message, Map<String, dynamic> data,
    String hypothesisId) {
  if (!kDebugMode) return;
  final payload = jsonEncode({
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'location': location,
    'message': message,
    'data': data,
    'sessionId': 'debug-session',
    'hypothesisId': hypothesisId,
  });
  http
      .post(
        Uri.parse(
            'http://127.0.0.1:7242/ingest/327cfdf5-167e-4df8-b9b2-c2bd6e2cc615'),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      )
      .catchError((_) => http.Response('', 500));
}

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
  MediaStream? _pendingRemoteStream;

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
      AppLogger.d('📹 CallScreen: Initializing WebRTC renderers...',
          category: LogCategory.general);

      // Create renderers
      _localRenderer = RTCVideoRenderer();
      _remoteRenderer = RTCVideoRenderer();

      // Initialize them
      await _localRenderer!.initialize();
      await _remoteRenderer!.initialize();

      AppLogger.i(
          '📹 CallScreen: WebRTC renderers initialized successfully (isWeb: $kIsWeb)',
          category: LogCategory.general);

      // Mark renderers as initialized
      _renderersInitialized = true;

      // Attach any pending streams that arrived before renderers were ready
      // Don't attach remote stream here - let build() defer attach after video UI frame (fixes remote not visible)
      if (_pendingRemoteStream != null) {
        _pendingRemoteStream = null;
      }

      if (_pendingLocalStream != null) {
        AppLogger.i('📹 CallScreen: Attaching pending local stream to renderer',
            category: LogCategory.general);
        // Sync camera state from the stream
        final videoTracks = _pendingLocalStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          _isCameraOff = !videoTracks[0].enabled;
        }
        setState(() {
          _localRenderer?.srcObject = _pendingLocalStream;
        });
        _pendingLocalStream = null;
      } else {
        // Check if there's already a local stream waiting
        final existingLocalStream = _callService.localStream;
        if (existingLocalStream != null) {
          AppLogger.i(
              '📹 CallScreen: Found existing local stream, attaching to renderer',
              category: LogCategory.general);
          // Sync camera state from the stream
          final videoTracks = existingLocalStream.getVideoTracks();
          if (videoTracks.isNotEmpty) {
            _isCameraOff = !videoTracks[0].enabled;
          }
          setState(() {
            _localRenderer?.srcObject = existingLocalStream;
          });
        }
      }
    } catch (e) {
      AppLogger.e('📹 CallScreen: Failed to initialize WebRTC renderers',
          category: LogCategory.general, error: e);
      // Clean up partial initialization
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
    AppLogger.d('CallScreen: Setting up call service callbacks',
        category: LogCategory.general);

    // Handle permission errors - show user-friendly messages
    _callService.onPermissionError = (error) {
      AppLogger.w('CallScreen: Permission error: $error',
          category: LogCategory.general);
      if (mounted) {
        // Cancel any existing timer
        _permissionErrorTimer?.cancel();

        setState(() {
          _permissionError = error;
        });

        // Auto-dismiss after 6 seconds
        _permissionErrorTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) {
            setState(() {
              _permissionError = null;
            });
          }
        });
      }
    };

    _callService.onCallStateChanged = (state) {
      AppLogger.i(
          '📞 CallScreen: Received state callback: $state (mounted: $mounted, isDisposed: $_isDisposed, isEnding: $_isEnding)',
          category: LogCategory.general);

      // Check if widget is still valid
      if (_isDisposed) {
        AppLogger.w('CallScreen: Widget disposed, ignoring state: $state',
            category: LogCategory.general);
        return;
      }

      if (!mounted) {
        AppLogger.w('CallScreen: Widget not mounted, ignoring state: $state',
            category: LogCategory.general);
        return;
      }

      // Update local state
      if (!_isEnding) {
        setState(() => _callState = state);
      }

      // Handle specific states
      if (state == CallState.connected) {
        AppLogger.d('CallScreen: Call connected - starting timer',
            category: LogCategory.general);
        _startCallTimer();
        _pulseController.stop();
        _ringController.stop();
        _dotsController.stop();

        // Sync camera state from service (important for voice calls that start with camera off)
        if (mounted) {
          setState(() {
            _isCameraOff = _callService.isCameraOff;
            _isMuted = _callService.isMuted;
            _isSpeakerOn = _callService.isSpeakerOn;
          });
        }
      } else if (state == CallState.answering) {
        // Intermediate state - show connecting UI
        AppLogger.d('CallScreen: Call answering - showing connecting UI',
            category: LogCategory.general);
      } else if (state == CallState.ended) {
        AppLogger.d('CallScreen: Call ended - will pop screen',
            category: LogCategory.general);
        _callTimer?.cancel();
        if (!_isEnding) {
          _isEnding = true;
          // Use post frame callback to ensure we're not in a build phase
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDisposed) {
              AppLogger.d('CallScreen: Popping screen after call ended',
                  category: LogCategory.general);
              Navigator.of(context).pop();
            }
          });
        }
      } else if (state == CallState.idle) {
        // Also handle idle state as a terminal state
        AppLogger.d('CallScreen: Call state is idle',
            category: LogCategory.general);
        if (!_isEnding && _callState != CallState.idle) {
          _isEnding = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDisposed) {
              AppLogger.d('CallScreen: Popping screen after idle state',
                  category: LogCategory.general);
              Navigator.of(context).pop();
            }
          });
        }
      }
    };

    _callService.onLocalStream = (stream) {
      AppLogger.d(
          '📹 CallScreen: onLocalStream called - mounted: $mounted, '
          'renderersInitialized: $_renderersInitialized, stream: ${stream.id}',
          category: LogCategory.general);

      // Sync camera state immediately when stream arrives (important for voice calls)
      if (mounted && !_isDisposed) {
        final videoTracks = stream.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          final cameraEnabled = videoTracks[0].enabled;
          setState(() {
            _isCameraOff = !cameraEnabled;
          });
          AppLogger.d(
              '📹 CallScreen: Synced camera state - isCameraOff: $_isCameraOff',
              category: LogCategory.general);
        }
      }

      // Store stream for later if renderers aren't ready
      if (!_renderersInitialized || _initializationFailed) {
        AppLogger.d('📹 CallScreen: Storing local stream for later attachment',
            category: LogCategory.general);
        _pendingLocalStream = stream;
        return;
      }

      if (mounted && !_isDisposed) {
        AppLogger.d('📹 CallScreen: Setting local stream to renderer',
            category: LogCategory.general);
        setState(() => _localRenderer?.srcObject = stream);
      }
    };

    _callService.onRemoteStream = (stream) {
      AppLogger.d(
          '📹 CallScreen: onRemoteStream called - mounted: $mounted, '
          'renderersInitialized: $_renderersInitialized, stream: ${stream.id}, '
          'tracks: ${stream.getTracks().length}',
          category: LogCategory.general);
      // #region agent log
      _agentDebugLog(
          'call_screen.dart:onRemoteStream',
          'onRemoteStream',
          {
            'streamId': stream.id,
            'videoTracks': stream.getVideoTracks().length,
            'audioTracks': stream.getAudioTracks().length,
            'mounted': mounted,
            'renderersInitialized': _renderersInitialized,
            'callState': _callState.toString(),
          },
          'H4');
      // #endregion

      // Store stream for later if renderers aren't ready
      if (!_renderersInitialized || _initializationFailed) {
        AppLogger.d('📹 CallScreen: Storing remote stream for later attachment',
            category: LogCategory.general);
        _pendingRemoteStream = stream;
        return;
      }

      // Attach immediately so the first build that shows RTCVideoView has the stream on the renderer.
      // On Android the native view often does not refresh if srcObject is set after the view is created (deferred attach).
      final renderer = _remoteRenderer;
      if (mounted && !_isDisposed && renderer != null) {
        for (final track in stream.getVideoTracks()) {
          if (!track.enabled) track.enabled = true;
        }
        AppLogger.i(
            '📹 CallScreen: Attaching remote stream to renderer (immediate)',
            category: LogCategory.general);
        setState(() => renderer.srcObject = stream);
      }
    };

    // Sync initial state from service (handles race where state went to connected before callback was set, e.g. on web)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed) return;
      final serviceState = _callService.state;
      if (serviceState != _callState) {
        AppLogger.d(
            'CallScreen: Syncing initial state from service: $_callState -> $serviceState',
            category: LogCategory.general);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  Widget _buildPermissionErrorBanner() {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade700,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _permissionError ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              onPressed: () {
                setState(() {
                  _permissionError = null;
                });
              },
            ),
          ],
        ),
      ),
    );
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
          backgroundColor: const Color(0xFF0D0D0D),
          body: Stack(
            children: [
              showVideoUI ? _buildUnifiedCallUI() : _buildAudioCallUI(),
              // Permission error banner at top (all platforms: mic/camera denial)
              if (_permissionError != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: _buildPermissionErrorBanner(),
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

  /// Builds remote video view with Key and explicit size.
  /// Shows RTCVideoView when we have a remote stream (on renderer or pending from service) so the native view exists before attach.
  Widget _buildRemoteVideoPlaceholder(
    RTCVideoRenderer? remoteRenderer, {
    required RTCVideoViewObjectFit objectFit,
    required Widget avatar,
  }) {
    final hasStreamOnRenderer = remoteRenderer?.srcObject != null;
    final hasStreamFromService = _callService.remoteStream != null;
    final showRtcView =
        remoteRenderer != null && (hasStreamOnRenderer || hasStreamFromService);
    // #region agent log
    _agentDebugLog(
        'call_screen.dart:_buildRemoteVideoPlaceholder',
        'placeholder choice',
        {
          'showRtcView': showRtcView,
          'hasStreamOnRenderer': hasStreamOnRenderer,
          'hasStreamFromService': hasStreamFromService,
          'remoteRendererNull': remoteRenderer == null,
        },
        'H3');
    // #endregion
    if (showRtcView) {
      // Stable key so same native view is kept when we attach stream in post-frame (fixes remote not visible)
      return SizedBox.expand(
        child: RTCVideoView(
          remoteRenderer,
          key: const ValueKey<String>('remote_video'),
          objectFit: objectFit,
        ),
      );
    }
    return avatar;
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
      // #region agent log
      _agentDebugLog(
          'call_screen.dart:_buildUnifiedCallUI',
          'schedule deferred attach',
          {
            'streamId': remoteStream.id,
            'videoTracks': remoteStream.getVideoTracks().length,
          },
          'H2');
      // #endregion
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed || _remoteRenderer == null) return;
        final stream = _callService.remoteStream;
        if (stream == null) return;
        // #region agent log
        _agentDebugLog(
            'call_screen.dart:deferredCallback',
            'callback running before setState',
            {
              'streamId': stream.id,
              'videoTracks': stream.getVideoTracks().length,
              'rendererHash': _remoteRenderer.hashCode,
            },
            'H1');
        // #endregion
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
        // #region agent log
        _agentDebugLog(
            'call_screen.dart:deferredCallback',
            'after setState srcObject set',
            {
              'streamId': stream.id,
              'rendererHasStream': _remoteRenderer?.srcObject != null,
            },
            'H5');
        // #endregion
      });
    }

    // Debug logging for video rendering - elevated to INFO for visibility
    final hasRemoteSrc = remoteRenderer?.srcObject != null;
    final hasLocalSrc = localRenderer?.srcObject != null;
    final remoteVideoTracks =
        remoteRenderer?.srcObject?.getVideoTracks().length ?? 0;
    final localVideoTracks =
        localRenderer?.srcObject?.getVideoTracks().length ?? 0;
    final remoteVideoTracksEnabled = remoteRenderer?.srcObject
            ?.getVideoTracks()
            .where((track) => track.enabled)
            .length ??
        0;

    if (kDebugMode) {
      AppLogger.d(
          '📹 Video UI - remote: $hasRemoteSrc ($remoteVideoTracks video, $remoteVideoTracksEnabled enabled), local: $hasLocalSrc ($localVideoTracks), isDesktop: $_isDesktopLayout',
          category: LogCategory.general);
    }

    // Warn if video tracks exist but are disabled
    if (hasRemoteSrc &&
        remoteVideoTracks > 0 &&
        remoteVideoTracksEnabled == 0) {
      AppLogger.w('📹 WARNING: Remote video tracks exist but all are disabled!',
          category: LogCategory.general);
    }

    if (_isDesktopLayout) {
      return _buildDesktopVideoLayout(remoteRenderer, localRenderer);
    }
    return _buildMobileVideoLayout(remoteRenderer, localRenderer);
  }

  /// Desktop/Web optimized video layout
  /// - Full-height remote video with Contain fit (no cropping)
  /// - Larger PIP positioned top-right for desktop
  /// - Desktop-friendly control sizing
  Widget _buildDesktopVideoLayout(
      RTCVideoRenderer? remoteRenderer, RTCVideoRenderer? localRenderer) {
    return Stack(
      children: [
        // Dark background
        Container(color: const Color(0xFF0D0D0D)),

        // Remote video - Contain fit to show full video without cropping
        // Key + SizedBox.expand force native view to refresh and get correct size (fixes black/blank remote video on some devices)
        Positioned.fill(
          child: _buildRemoteVideoPlaceholder(
            remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            avatar: Center(
              child: UserAvatar(
                userId: widget.calleeId,
                imageUrl: widget.calleeAvatar,
                size: 140,
                loadFromFirestore: widget.calleeAvatar == null,
                nameInitials: widget.calleeName.isNotEmpty
                    ? widget.calleeName[0].toUpperCase()
                    : 'U',
              ),
            ),
          ),
        ),

        // Local video PIP - larger for desktop, draggable
        _buildDraggableLocalVideo(localRenderer, isDesktop: true),

        // Encrypted badge - centered above controls
        Positioned(
          bottom: 180,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'End-to-end encrypted',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Desktop top bar - simplified with better spacing
        _buildDesktopTopBar(),

        // Bottom controls - same for voice and video (camera can be turned on in voice)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: UnifiedCallControls(
            isMuted: _isMuted,
            isCameraOff: _isCameraOff,
            isSpeakerOn: _isSpeakerOn,
            isConnected: _callState == CallState.connected,
            hasVideoTrack: _callService.hasVideoTrack,
            isVideoCall: widget.callType == CallType.video,
            onToggleMute: _toggleMute,
            onToggleCamera: _toggleCamera,
            onToggleSpeaker: _toggleSpeaker,
            onFlipCamera: _switchCamera,
            onEndCall: _endCall,
            isDesktop: true,
          ),
        ),
      ],
    );
  }

  /// Desktop top bar with better spacing
  Widget _buildDesktopTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 32,
          right: 32,
          bottom: 24,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.black.withValues(alpha: 0.3),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Row(
          children: [
            // Back button - larger for desktop
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Call info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.calleeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<int>(
                    valueListenable: _callDuration,
                    builder: (context, duration, _) {
                      return Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 15,
                            ),
                          ),
                          // Removed call type indicator - not needed, UI shows video when active
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mobile video layout (original behavior with Cover fit)
  Widget _buildMobileVideoLayout(
      RTCVideoRenderer? remoteRenderer, RTCVideoRenderer? localRenderer) {
    return Stack(
      children: [
        // Remote video - Contain so full frame is visible (no cropping)
        Positioned.fill(
          child: _buildRemoteVideoPlaceholder(
            remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            avatar: Container(
              color: const Color(0xFF1A1A2E),
              child: Center(
                child: UserAvatar(
                  userId: widget.calleeId,
                  imageUrl: widget.calleeAvatar,
                  size: 120,
                  loadFromFirestore: widget.calleeAvatar == null,
                  nameInitials: widget.calleeName.isNotEmpty
                      ? widget.calleeName[0].toUpperCase()
                      : 'U',
                ),
              ),
            ),
          ),
        ),

        // Local video (picture-in-picture) - draggable
        _buildDraggableLocalVideo(localRenderer, isDesktop: false),

        // Encrypted badge - centered above controls
        Positioned(
          bottom: 240,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Encrypted',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Top bar with call info
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Row(
              children: [
                // Back/minimize button
                CallSmallControlButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: _endCall,
                ),
                const SizedBox(width: 12),
                // Call info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.calleeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      ValueListenableBuilder<int>(
                        valueListenable: _callDuration,
                        builder: (context, duration, _) {
                          return Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatDuration(duration),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom controls - same for voice and video
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: UnifiedCallControls(
            isMuted: _isMuted,
            isCameraOff: _isCameraOff,
            isSpeakerOn: _isSpeakerOn,
            isConnected: _callState == CallState.connected,
            hasVideoTrack: _callService.hasVideoTrack,
            isVideoCall: widget.callType == CallType.video,
            onToggleMute: _toggleMute,
            onToggleCamera: _toggleCamera,
            onToggleSpeaker: _toggleSpeaker,
            onFlipCamera: _switchCamera,
            onEndCall: _endCall,
            isDesktop: _isDesktopLayout,
          ),
        ),
      ],
    );
  }

  /// Audio call UI (voice only) - used only when not yet connected (ringing/connecting)
  Widget _buildAudioCallUI() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
            Color(0xFF0F0F1A),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAvatarSection(),
                  const SizedBox(height: 32),
                  _buildCalleeName(),
                  const SizedBox(height: 12),
                  _buildCallStatus(),
                  const SizedBox(height: 24),
                  if (_callState == CallState.connected) _buildEncryptedBadge(),
                ],
              ),
            ),
            UnifiedCallControls(
              isMuted: _isMuted,
              isCameraOff: _isCameraOff,
              isSpeakerOn: _isSpeakerOn,
              isConnected: _callState == CallState.connected,
              hasVideoTrack: _callService.hasVideoTrack,
              isVideoCall: widget.callType == CallType.video,
              onToggleMute: _toggleMute,
              onToggleCamera: _toggleCamera,
              onToggleSpeaker: _toggleSpeaker,
              onFlipCamera: _switchCamera,
              onEndCall: _endCall,
              isDesktop: _isDesktopLayout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            // Removed call type indicator - not needed, UI shows video when active
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    final isRinging =
        _callState == CallState.ringing || _callState == CallState.connecting;
    final isConnected = _callState == CallState.connected;

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isRinging) ...[
            _buildAnimatedRing(0, 200),
            _buildAnimatedRing(0.33, 170),
            _buildAnimatedRing(0.66, 140),
          ],
          if (isConnected)
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D26A).withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isConnected ? 1.0 : _pulseAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isConnected
                      ? const Color(0xFF00D26A).withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: UserAvatar(
                  userId: widget.calleeId,
                  imageUrl: widget.calleeAvatar,
                  size: 134,
                  loadFromFirestore: widget.calleeAvatar == null,
                  nameInitials: widget.calleeName.isNotEmpty
                      ? widget.calleeName[0].toUpperCase()
                      : 'U',
                  showBorder: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedRing(double delay, double size) {
    return AnimatedBuilder(
      animation: _ringController,
      builder: (context, _) {
        final progress = ((_ringController.value + delay) % 1.0);
        final opacity = (1.0 - progress) * 0.5;
        final scale = 0.6 + (progress * 0.4);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: opacity),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalleeName() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        widget.calleeName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCallStatus() {
    return ValueListenableBuilder<int>(
      valueListenable: _callDuration,
      builder: (context, duration, _) {
        String statusText;
        Color statusColor;

        switch (_callState) {
          case CallState.ringing:
            statusText = 'Ringing';
            statusColor = Colors.white.withValues(alpha: 0.6);
            break;
          case CallState.connecting:
          case CallState.incoming:
          case CallState.answering:
            statusText = 'Connecting';
            statusColor = Colors.white.withValues(alpha: 0.6);
            break;
          case CallState.connected:
            statusText = _formatDuration(duration);
            statusColor = const Color(0xFF00D26A);
            break;
          case CallState.ended:
            statusText = 'Call ended';
            statusColor = Colors.white.withValues(alpha: 0.5);
            break;
          default:
            statusText = 'Connecting';
            statusColor = Colors.white.withValues(alpha: 0.6);
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_callState == CallState.connected) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00D26A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 16,
                fontWeight: _callState == CallState.connected
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
            if (_callState == CallState.ringing ||
                _callState == CallState.connecting ||
                _callState == CallState.incoming ||
                _callState == CallState.answering ||
                _callState == CallState.idle)
              _buildAnimatedDots(),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedDots() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = ((_dotsController.value + delay) % 1.0);
            final opacity =
                0.3 + (0.7 * (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0));

            return Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildEncryptedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: Colors.white.withValues(alpha: 0.6),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            'End-to-end encrypted',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a draggable local video preview widget
  Widget _buildDraggableLocalVideo(RTCVideoRenderer? localRenderer,
      {required bool isDesktop}) {
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    // Calculate current size
    final width = isDesktop
        ? (_isLocalVideoLarge ? 240.0 : 180.0)
        : (_isLocalVideoLarge ? 180.0 : 120.0);
    final height = isDesktop
        ? (_isLocalVideoLarge ? 320.0 : 240.0)
        : (_isLocalVideoLarge ? 240.0 : 160.0);

    // Initialize position if not set (top-right corner)
    if (_localVideoPosition == null) {
      _localVideoPosition = Offset(
        screenSize.width - width - (isDesktop ? 32.0 : 16.0),
        topPadding + (isDesktop ? 16.0 : 16.0),
      );
    }

    // Clamp position to ensure it stays within bounds (especially when size changes)
    final maxX = screenSize.width - width;
    final maxY = screenSize.height - height;
    final minX = 0.0;
    final minY = topPadding;

    _localVideoPosition = Offset(
      _localVideoPosition!.dx.clamp(minX, maxX),
      _localVideoPosition!.dy.clamp(minY, maxY),
    );

    // Get current position
    var currentPosition = _localVideoPosition!;

    return Positioned(
      left: currentPosition.dx,
      top: currentPosition.dy,
      child: GestureDetector(
        onTap: () => setState(() => _isLocalVideoLarge = !_isLocalVideoLarge),
        onPanUpdate: (details) {
          setState(() {
            // Use the current stored position (not the captured variable)
            final currentPos = _localVideoPosition ?? currentPosition;

            // Calculate new position
            var newX = currentPos.dx + details.delta.dx;
            var newY = currentPos.dy + details.delta.dy;

            // Keep within screen bounds
            newX = newX.clamp(minX, maxX);
            newY = newY.clamp(minY, maxY);

            _localVideoPosition = Offset(newX, newY);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDesktop ? 0.6 : 0.5),
                blurRadius: isDesktop ? 20 : 10,
                spreadRadius: isDesktop ? 4 : 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: (localRenderer != null &&
                    localRenderer.srcObject != null &&
                    !_isCameraOff)
                ? RTCVideoView(
                    localRenderer,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  )
                : Container(
                    color: const Color(0xFF2A2A3E),
                    child: Center(
                      child: Icon(
                        Icons.videocam_off_rounded,
                        color: Colors.white54,
                        size: isDesktop ? 40 : 32,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
