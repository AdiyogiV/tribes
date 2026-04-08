import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:aurogram/features/calling/presentation/widgets/call_controls.dart';
import 'package:aurogram/features/calling/presentation/widgets/call_local_video_pip.dart';
import 'package:aurogram/features/calling/presentation/widgets/call_remote_video.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Desktop/Web optimized video layout for connected calls.
/// - Full-height remote video with Contain fit (no cropping)
/// - Larger PIP positioned top-right for desktop
/// - Desktop-friendly control sizing
class CallDesktopVideoLayout extends StatelessWidget {
  final RTCVideoRenderer? remoteRenderer;
  final RTCVideoRenderer? localRenderer;
  final bool hasRemoteStreamFromService;
  final String calleeId;
  final String calleeName;
  final String? calleeAvatar;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final bool isConnected;
  final bool hasVideoTrack;
  final bool isVideoCall;
  final bool isLocalVideoLarge;
  final Offset localVideoPosition;
  final ValueNotifier<int> callDuration;
  final String Function(int) formatDuration;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onFlipCamera;
  final VoidCallback onEndCall;
  final VoidCallback onToggleLocalVideoSize;
  final ValueChanged<Offset> onLocalVideoPositionChanged;

  const CallDesktopVideoLayout({
    super.key,
    required this.remoteRenderer,
    required this.localRenderer,
    required this.hasRemoteStreamFromService,
    required this.calleeId,
    required this.calleeName,
    this.calleeAvatar,
    required this.isMuted,
    required this.isCameraOff,
    required this.isSpeakerOn,
    required this.isConnected,
    required this.hasVideoTrack,
    required this.isVideoCall,
    required this.isLocalVideoLarge,
    required this.localVideoPosition,
    required this.callDuration,
    required this.formatDuration,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onToggleSpeaker,
    required this.onFlipCamera,
    required this.onEndCall,
    required this.onToggleLocalVideoSize,
    required this.onLocalVideoPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark background
        Container(color: AppTheme.callBackground),

        // Remote video - Contain fit to show full video without cropping
        Positioned.fill(
          child: CallRemoteVideo(
            remoteRenderer: remoteRenderer,
            hasStreamFromService: hasRemoteStreamFromService,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            avatar: Center(
              child: UserAvatar(
                userId: calleeId,
                imageUrl: calleeAvatar,
                size: 140,
                loadFromFirestore: calleeAvatar == null,
                nameInitials:
                    calleeName.isNotEmpty ? calleeName[0].toUpperCase() : 'U',
              ),
            ),
          ),
        ),

        // Local video PIP - larger for desktop, draggable
        CallLocalVideoPip(
          localRenderer: localRenderer,
          isDesktop: true,
          isLocalVideoLarge: isLocalVideoLarge,
          isCameraOff: isCameraOff,
          position: localVideoPosition,
          onToggleSize: onToggleLocalVideoSize,
          onPositionChanged: onLocalVideoPositionChanged,
        ),

        // Encrypted badge - centered above controls
        Positioned(
          bottom: 180,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd, vertical: AppDimensions.paddingSm),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 14,
                  ),
                  const SizedBox(width: AppDimensions.spacingSmMd),
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

        // Desktop top bar
        _CallDesktopTopBar(
          calleeName: calleeName,
          callDuration: callDuration,
          formatDuration: formatDuration,
          onEndCall: onEndCall,
        ),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: UnifiedCallControls(
            isMuted: isMuted,
            isCameraOff: isCameraOff,
            isSpeakerOn: isSpeakerOn,
            isConnected: isConnected,
            hasVideoTrack: hasVideoTrack,
            isVideoCall: isVideoCall,
            onToggleMute: onToggleMute,
            onToggleCamera: onToggleCamera,
            onToggleSpeaker: onToggleSpeaker,
            onFlipCamera: onFlipCamera,
            onEndCall: onEndCall,
            isDesktop: true,
          ),
        ),
      ],
    );
  }
}

/// Desktop top bar with back button, callee name, and call duration.
class _CallDesktopTopBar extends StatelessWidget {
  final String calleeName;
  final ValueNotifier<int> callDuration;
  final String Function(int) formatDuration;
  final VoidCallback onEndCall;

  const _CallDesktopTopBar({
    required this.calleeName,
    required this.callDuration,
    required this.formatDuration,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
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
                onTap: onEndCall,
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
            const SizedBox(width: AppDimensions.spacingXl),
            // Call info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    calleeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  ValueListenableBuilder<int>(
                    valueListenable: callDuration,
                    builder: (context, duration, _) {
                      return Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.activeGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                          Text(
                            formatDuration(duration),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 15,
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
    );
  }
}

/// Mobile video layout for connected calls.
/// Uses Contain fit for remote video and a smaller PIP for local.
class CallMobileVideoLayout extends StatelessWidget {
  final RTCVideoRenderer? remoteRenderer;
  final RTCVideoRenderer? localRenderer;
  final bool hasRemoteStreamFromService;
  final String calleeId;
  final String calleeName;
  final String? calleeAvatar;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final bool isConnected;
  final bool hasVideoTrack;
  final bool isVideoCall;
  final bool isDesktopLayout;
  final bool isLocalVideoLarge;
  final Offset localVideoPosition;
  final ValueNotifier<int> callDuration;
  final String Function(int) formatDuration;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onFlipCamera;
  final VoidCallback onEndCall;
  final VoidCallback onToggleLocalVideoSize;
  final ValueChanged<Offset> onLocalVideoPositionChanged;

  const CallMobileVideoLayout({
    super.key,
    required this.remoteRenderer,
    required this.localRenderer,
    required this.hasRemoteStreamFromService,
    required this.calleeId,
    required this.calleeName,
    this.calleeAvatar,
    required this.isMuted,
    required this.isCameraOff,
    required this.isSpeakerOn,
    required this.isConnected,
    required this.hasVideoTrack,
    required this.isVideoCall,
    required this.isDesktopLayout,
    required this.isLocalVideoLarge,
    required this.localVideoPosition,
    required this.callDuration,
    required this.formatDuration,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onToggleSpeaker,
    required this.onFlipCamera,
    required this.onEndCall,
    required this.onToggleLocalVideoSize,
    required this.onLocalVideoPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Remote video - Contain so full frame is visible (no cropping)
        Positioned.fill(
          child: CallRemoteVideo(
            remoteRenderer: remoteRenderer,
            hasStreamFromService: hasRemoteStreamFromService,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            avatar: Container(
              color: AppTheme.darkGradientBase,
              child: Center(
                child: UserAvatar(
                  userId: calleeId,
                  imageUrl: calleeAvatar,
                  size: 120,
                  loadFromFirestore: calleeAvatar == null,
                  nameInitials:
                      calleeName.isNotEmpty ? calleeName[0].toUpperCase() : 'U',
                ),
              ),
            ),
          ),
        ),

        // Local video (picture-in-picture) - draggable
        CallLocalVideoPip(
          localRenderer: localRenderer,
          isDesktop: false,
          isLocalVideoLarge: isLocalVideoLarge,
          isCameraOff: isCameraOff,
          position: localVideoPosition,
          onToggleSize: onToggleLocalVideoSize,
          onPositionChanged: onLocalVideoPositionChanged,
        ),

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
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 12,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
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
                  onTap: onEndCall,
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                // Call info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        calleeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimensions.spacingXxs),
                      ValueListenableBuilder<int>(
                        valueListenable: callDuration,
                        builder: (context, duration, _) {
                          return Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppTheme.activeGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spacingSmMd),
                              Text(
                                formatDuration(duration),
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
            isMuted: isMuted,
            isCameraOff: isCameraOff,
            isSpeakerOn: isSpeakerOn,
            isConnected: isConnected,
            hasVideoTrack: hasVideoTrack,
            isVideoCall: isVideoCall,
            onToggleMute: onToggleMute,
            onToggleCamera: onToggleCamera,
            onToggleSpeaker: onToggleSpeaker,
            onFlipCamera: onFlipCamera,
            onEndCall: onEndCall,
            isDesktop: isDesktopLayout,
          ),
        ),
      ],
    );
  }
}
