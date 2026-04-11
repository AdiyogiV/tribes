import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:aurogram/features/calling/presentation/pages/models/ui_participant.dart';
import 'package:aurogram/features/calling/presentation/widgets/group_call_controls.dart';
import 'package:aurogram/features/calling/presentation/widgets/group_call_joining_view.dart';
import 'package:aurogram/features/calling/presentation/widgets/group_call_top_bar.dart';
import 'package:aurogram/features/calling/domain/group_call_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

/// Group call screen using Agora RTC
/// Video call by default - users can turn camera off for audio-only
class GroupCallScreen extends StatefulWidget {
  final String spaceId;
  final String spaceName;

  const GroupCallScreen({
    super.key,
    required this.spaceId,
    required this.spaceName,
  });

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen>
    with TickerProviderStateMixin {
  final GroupCallService _groupCallService = GroupCallService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State
  bool _isJoining = true;
  bool _isAudioMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  bool _isLeaving = false;

  // Participants
  final Map<int, UiParticipant> _participants = {};
  int? _activeSpeaker;

  // Connection quality (0-5, 5 is best)
  int _connectionQuality = 5;

  // Timer
  Timer? _callTimer;
  final ValueNotifier<int> _callDuration = ValueNotifier<int>(0);

  // Stream subscriptions (for cleanup)
  StreamSubscription? _participantsSubscription;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _speakingController;
  late Animation<double> _speakingAnimation;

  @override
  void initState() {
    super.initState();
    // Enable wakelock on mobile only (web handles this differently)
    if (!kIsWeb) {
      WakelockPlus.enable();
    }
    _setupAnimations();
    _setupCallbacks();
    _joinCall();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _speakingController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..repeat(reverse: true);

    _speakingAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _speakingController, curve: Curves.easeInOut),
    );
  }

  void _setupCallbacks() {
    _groupCallService.onJoinedChannel = () {
      if (mounted) {
        setState(() {
          _isJoining = false;
          // Sync muted state from service (may have joined with media disabled)
          _isAudioMuted = _groupCallService.isAudioMuted;
          _isVideoOff = _groupCallService.isVideoMuted;
        });
        _startCallTimer();
        _addLocalParticipant();
      }
    };

    _groupCallService.onUserJoined = (uid) {
      if (mounted) {
        _addRemoteParticipant(uid);
      }
    };

    _groupCallService.onUserLeft = (uid) {
      if (mounted) {
        setState(() => _participants.remove(uid));
      }
    };

    _groupCallService.onCallEnded = () {
      if (mounted && !_isLeaving) {
        _leave();
      }
    };

    _groupCallService.onError = (error) {
      if (mounted) {
        showCustomSnackBar(context, message: error, backgroundColor: Colors.red);
      }
    };

    _groupCallService.onNetworkQualityChanged = (quality) {
      if (mounted && _connectionQuality != quality) {
        setState(() => _connectionQuality = quality);
      }
    };
  }

  void _addLocalParticipant() async {
    final localUid = _groupCallService.localUid;
    if (localUid == null) return;

    final userId = _groupCallService.currentUserId;
    String displayName = 'You';
    String? avatarUrl;

    if (userId != null) {
      try {
        final userData = await locator<UserRepository>().getUserData(userId);
        if (userData != null) {
          displayName = userData['name'] ?? userData['nickname'] ?? 'You';
          avatarUrl = userData['imageUrl'];
        }
      } catch (_) {
        AppLogger.w('GroupCallScreen: failed to fetch local user data', category: LogCategory.general);
      }
    }

    if (mounted) {
      setState(() {
        _participants[localUid] = UiParticipant(
          agoraUid: localUid,
          oderId: userId ?? '',
          displayName: displayName,
          avatarUrl: avatarUrl,
          isLocal: true,
        );
      });
    }
  }

  void _addRemoteParticipant(int agoraUid) async {
    // Add placeholder first
    if (mounted) {
      setState(() {
        _participants[agoraUid] = UiParticipant(
          agoraUid: agoraUid,
          oderId: '',
          displayName: 'Connecting...',
        );
      });
    }

    // Fetch from Firestore with retry
    for (int retry = 0; retry < 3; retry++) {
      try {
        if (retry > 0) {
          await Future.delayed(Duration(milliseconds: 500 * retry));
        }

        final callDoc = await _firestore
            .collection('spaces')
            .doc(widget.spaceId)
            .collection('calls')
            .doc('active')
            .get();

        final data = callDoc.data();
        final participants = data?['participants'] as List<dynamic>? ?? [];

        // Find participant by Agora UID
        for (final p in participants) {
          if (p is! Map) {
            continue;
          }
          if (p['agoraUid'] == agoraUid) {
            final displayName = p['displayName'] ?? 'User';
            final oderId = p['oderId'] ?? '';
            final avatarUrl = p['avatarUrl'];

            if (mounted) {
              setState(() {
                _participants[agoraUid] = UiParticipant(
                  agoraUid: agoraUid,
                  oderId: oderId,
                  displayName: displayName,
                  avatarUrl: avatarUrl,
                );
              });
            }
            return;
          }
        }
      } catch (_) {
        AppLogger.w('GroupCallScreen: failed to resolve remote participant', category: LogCategory.general);
      }
    }

    // Fallback if not found
    if (mounted) {
      setState(() {
        _participants[agoraUid] = UiParticipant(
          agoraUid: agoraUid,
          oderId: '',
          displayName: 'User',
        );
      });
    }
  }

  Future<void> _joinCall() async {
    final success = await _groupCallService.startOrJoinGroupCall(
      spaceId: widget.spaceId,
      spaceName: widget.spaceName,
    );

    if (!success && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDuration.value++;
    });
  }

  Future<void> _toggleMute() async {
    await _groupCallService.toggleAudio();
    if (mounted) {
      setState(() => _isAudioMuted = _groupCallService.isAudioMuted);

      final localUid = _groupCallService.localUid;
      if (localUid != null && _participants.containsKey(localUid)) {
        _participants[localUid]!.isAudioMuted = _isAudioMuted;
      }
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _toggleVideo() async {
    await _groupCallService.toggleVideo();
    if (mounted) {
      setState(() => _isVideoOff = _groupCallService.isVideoMuted);

      final localUid = _groupCallService.localUid;
      if (localUid != null && _participants.containsKey(localUid)) {
        _participants[localUid]!.isVideoMuted = _isVideoOff;
      }
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _toggleSpeaker() async {
    await _groupCallService.toggleSpeaker(!_isSpeakerOn);
    if (mounted) {
      setState(() => _isSpeakerOn = !_isSpeakerOn);
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _switchCamera() async {
    if (_isVideoOff) return;
    await _groupCallService.switchCamera();
    HapticFeedback.lightImpact();
  }

  Future<void> _leave() async {
    if (_isLeaving) return;
    _isLeaving = true;

    HapticFeedback.mediumImpact();
    await _groupCallService.leaveCall();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    // Clear callbacks to avoid setState after dispose
    _groupCallService.onJoinedChannel = null;
    _groupCallService.onUserJoined = null;
    _groupCallService.onUserLeft = null;
    _groupCallService.onCallEnded = null;
    _groupCallService.onError = null;
    _groupCallService.onNetworkQualityChanged = null;

    // IMPORTANT: Leave the call if it's still active when screen is disposed
    // This catches edge cases where dispose is called without going through _leave()
    if (!_isLeaving && !_isJoining) {
      _groupCallService.leaveCall();
    }

    _participantsSubscription?.cancel();
    _callTimer?.cancel();
    _callDuration.dispose();
    _pulseController.dispose();
    _speakingController.dispose();
    // Disable wakelock on mobile only
    if (!kIsWeb) {
      WakelockPlus.disable();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Intercept back button to properly leave the call
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Leave the call when back button is pressed
        _leave();
      },
      child: Scaffold(
        backgroundColor: AppTheme.callBackground,
        body: SafeArea(
          child: Stack(
            children: [
              _buildVideoGrid(),
              GroupCallTopBar(
                spaceName: widget.spaceName,
                isJoining: _isJoining,
                participantsCount: _participants.length,
                connectionQuality: _connectionQuality,
                callDuration: _callDuration,
                formatDuration: _formatDuration,
                onLeave: _leave,
              ),
              GroupCallControls(
                isAudioMuted: _isAudioMuted,
                isVideoOff: _isVideoOff,
                isSpeakerOn: _isSpeakerOn,
                onToggleMute: _toggleMute,
                onToggleVideo: _toggleVideo,
                onToggleSpeaker: _toggleSpeaker,
                onFlipCamera: _switchCamera,
                onLeave: _leave,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoGrid() {
    final engine = _groupCallService.engine;
    if (engine == null || _isJoining) {
      return GroupCallJoiningView(
        spaceName: widget.spaceName,
        pulseAnimation: _pulseAnimation,
      );
    }

    final participantList = _participants.values.toList();
    if (participantList.isEmpty) {
      return GroupCallJoiningView(
        spaceName: widget.spaceName,
        pulseAnimation: _pulseAnimation,
      );
    }

    // Insets so video grid stays below top bar and above controls (no overlap)
    const gridPadding =
        EdgeInsets.only(top: 72, bottom: 132, left: 8, right: 8);
    return Padding(
      padding: gridPadding,
      child: _buildOptimalGrid(participantList, engine),
    );
  }

  Widget _buildOptimalGrid(List<UiParticipant> participants, RtcEngine engine) {
    final count = participants.length;

    if (count == 1) {
      return _buildVideoTile(participants[0], engine, isFullScreen: true);
    }

    // Use LayoutBuilder to adapt grid based on available space aspect ratio
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final aspectRatio = constraints.maxWidth / constraints.maxHeight;

        // Calculate optimal grid dimensions based on participant count and aspect ratio
        final gridConfig =
            _calculateOptimalGrid(count, aspectRatio, isLandscape);

        return _buildAdaptiveGrid(
          participants: participants,
          engine: engine,
          columns: gridConfig.columns,
          rows: gridConfig.rows,
        );
      },
    );
  }

  /// Calculate optimal grid layout based on participant count and screen aspect ratio
  /// Returns (columns, rows) that best fills the available space
  ({int columns, int rows}) _calculateOptimalGrid(
      int count, double aspectRatio, bool isLandscape) {
    switch (count) {
      case 2:
        // For 2 participants: side-by-side on landscape, stacked on portrait
        return isLandscape ? (columns: 2, rows: 1) : (columns: 1, rows: 2);

      case 3:
        // For 3: prefer 3 in a row on very wide screens, otherwise 1+2 layout
        if (aspectRatio > 2.0) {
          return (columns: 3, rows: 1);
        } else if (isLandscape) {
          return (columns: 3, rows: 1);
        } else {
          // Portrait: 1 on top, 2 on bottom (handled specially)
          return (columns: 2, rows: 2);
        }

      case 4:
        // For 4: always 2x2 grid
        return (columns: 2, rows: 2);

      case 5:
      case 6:
        // For 5-6: 3x2 on landscape, 2x3 on portrait
        return isLandscape ? (columns: 3, rows: 2) : (columns: 2, rows: 3);

      case 7:
      case 8:
      case 9:
        // For 7-9: 3x3 grid
        return (columns: 3, rows: 3);

      default:
        // For 10+: calculate based on sqrt for roughly square grid
        // Prefer more columns on landscape, more rows on portrait
        final sqrt = count.toDouble();
        int cols = (sqrt / 1.5).ceil().clamp(2, 4);
        if (isLandscape && cols < 4) cols++;
        int rows = (count / cols).ceil();
        return (columns: cols, rows: rows);
    }
  }

  /// Build an adaptive grid with the specified columns and rows
  Widget _buildAdaptiveGrid({
    required List<UiParticipant> participants,
    required RtcEngine engine,
    required int columns,
    required int rows,
  }) {
    final count = participants.length;

    // Special case: 3 participants in portrait mode (1 on top, 2 on bottom)
    if (count == 3 && columns == 2 && rows == 2) {
      return Column(
        children: [
          Expanded(child: _buildVideoTile(participants[0], engine)),
          const SizedBox(height: AppDimensions.spacingSm),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildVideoTile(participants[1], engine)),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(child: _buildVideoTile(participants[2], engine)),
              ],
            ),
          ),
        ],
      );
    }

    // Build standard grid
    int participantIndex = 0;
    return Column(
      children: [
        for (int row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: AppDimensions.spacingSm),
          Expanded(
            child: Row(
              children: [
                for (int col = 0; col < columns; col++) ...[
                  if (col > 0) const SizedBox(width: AppDimensions.spacingSm),
                  Expanded(
                    child: participantIndex < count
                        ? _buildVideoTile(
                            participants[participantIndex++], engine)
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoTile(UiParticipant participant, RtcEngine engine,
      {bool isFullScreen = false}) {
    final isSpeaking = _activeSpeaker == participant.agoraUid;
    final showVideo =
        participant.isLocal ? !_isVideoOff : !participant.isVideoMuted;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkGradientBase,
        borderRadius: BorderRadius.circular(isFullScreen ? 0 : 16),
        border: Border.all(
          color: isSpeaking
              ? AppTheme.activeGreen
              : participant.isLocal
                  ? AppTheme.primaryColor.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
          width: isSpeaking ? 3 : 2,
        ),
        boxShadow: isSpeaking
            ? [
                BoxShadow(
                  color: AppTheme.activeGreen.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isFullScreen ? 0 : 14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video view or avatar
            if (showVideo)
              // Fill tile; RenderModeFit shows full frame without cropping (letterboxing if aspect differs)
              participant.isLocal
                  ? AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: engine,
                        canvas: const VideoCanvas(
                          uid: 0,
                          renderMode: RenderModeType.renderModeFit,
                        ),
                      ),
                    )
                  : AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: engine,
                        canvas: VideoCanvas(
                          uid: participant.agoraUid,
                          renderMode: RenderModeType.renderModeFit,
                        ),
                        connection:
                            RtcConnection(channelId: 'gram_${widget.spaceId}'),
                      ),
                    )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildParticipantAvatar(
                        participant, isFullScreen ? 100 : 60),
                    const SizedBox(height: AppDimensions.spacingMd),
                    Text(
                      participant.isLocal ? 'You' : participant.displayName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: isFullScreen ? 18 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Participant info overlay
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (participant.isLocal
                            ? _isAudioMuted
                            : participant.isAudioMuted)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.mic_off,
                              color: Colors.red.withValues(alpha: 0.9),
                              size: 14,
                            ),
                          ),
                        Text(
                          participant.isLocal ? 'You' : participant.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (isSpeaking)
                    AnimatedBuilder(
                      animation: _speakingAnimation,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.activeGreen
                                .withValues(alpha: _speakingAnimation.value),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic,
                              color: Colors.white, size: 12),
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

  Widget _buildParticipantAvatar(UiParticipant participant, double size) {
    if (participant.avatarUrl != null && participant.avatarUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
        ),
        child: ClipOval(
          child: Image.network(
            participant.avatarUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _buildDefaultAvatar(participant, size),
          ),
        ),
      );
    }
    return _buildDefaultAvatar(participant, size);
  }

  Widget _buildDefaultAvatar(UiParticipant participant, double size) {
    final initial = participant.displayName.isNotEmpty
        ? participant.displayName[0].toUpperCase()
        : 'U';
    final colors = [
      AppTheme.indigoColor,
      AppTheme.cosmicPurple,
      AppTheme.pinkAccent,
      const Color(0xFF14B8A6),
      AppTheme.amberAccent,
    ];
    final color = colors[participant.agoraUid % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.3),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
