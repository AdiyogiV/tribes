import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Unified call controls - works for both video and voice calls
/// Conditionally shows camera controls based on video capability
class UnifiedCallControls extends StatelessWidget {
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final bool isConnected;
  final bool hasVideoTrack; // Whether video tracks are currently available
  final bool isVideoCall; // Whether this is a video call (based on callType)
  final VoidCallback onToggleMute;
  final VoidCallback? onToggleCamera; // Optional - only if video call
  final VoidCallback? onToggleSpeaker;
  final VoidCallback? onFlipCamera; // Optional - only if video call
  final VoidCallback onEndCall;

  /// Whether to use desktop-optimized layout
  final bool isDesktop;

  const UnifiedCallControls({
    super.key,
    required this.isMuted,
    required this.isCameraOff,
    required this.isSpeakerOn,
    required this.isConnected,
    required this.hasVideoTrack,
    required this.isVideoCall,
    required this.onToggleMute,
    this.onToggleCamera,
    this.onToggleSpeaker,
    this.onFlipCamera,
    required this.onEndCall,
    this.isDesktop = false,
  });

  // Legacy constructors for backward compatibility
  /// Audio-only call controls (no video capability)
  factory UnifiedCallControls.audio({
    required bool isMuted,
    required bool isSpeakerOn,
    required bool isConnected,
    required VoidCallback onToggleMute,
    required VoidCallback onToggleSpeaker,
    required VoidCallback onEndCall,
    bool isDesktop = false,
  }) {
    return UnifiedCallControls(
      isMuted: isMuted,
      isCameraOff: true,
      isSpeakerOn: isSpeakerOn,
      isConnected: isConnected,
      hasVideoTrack: false,
      isVideoCall: false,
      onToggleMute: onToggleMute,
      onToggleSpeaker: onToggleSpeaker,
      onEndCall: onEndCall,
      isDesktop: isDesktop,
    );
  }

  /// Video call controls (with video capability)
  factory UnifiedCallControls.video({
    required bool isMuted,
    required bool isCameraOff,
    required bool isSpeakerOn,
    required VoidCallback onToggleMute,
    required VoidCallback onToggleCamera,
    required VoidCallback onToggleSpeaker,
    required VoidCallback onFlipCamera,
    required VoidCallback onEndCall,
    bool isDesktop = false,
  }) {
    return UnifiedCallControls(
      isMuted: isMuted,
      isCameraOff: isCameraOff,
      isSpeakerOn: isSpeakerOn,
      isConnected: true,
      hasVideoTrack: true,
      isVideoCall: true,
      onToggleMute: onToggleMute,
      onToggleCamera: onToggleCamera,
      onToggleSpeaker: onToggleSpeaker,
      onFlipCamera: onFlipCamera,
      onEndCall: onEndCall,
      isDesktop: isDesktop,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hide speaker on web (browser manages audio output)
    final showSpeaker = !kIsWeb && !isDesktop;

    // Show video controls (camera, flip, compact style) for video calls or when camera is available (e.g. voice call can turn camera on)
    final showVideoControls =
        isVideoCall || hasVideoTrack || onToggleCamera != null;

    // Responsive padding and sizing
    // Use video-style padding if we have video capability, audio-style if not
    final horizontalPadding = showVideoControls
        ? (isDesktop ? 48.0 : 12.0)
        : (isDesktop ? 48.0 : 24.0);
    final verticalPadding = showVideoControls
        ? (isDesktop ? 32.0 : 16.0)
        : (isDesktop ? 32.0 : 24.0);
    final bottomPadding =
        MediaQuery.of(context).padding.bottom + verticalPadding;

    // Build list of control buttons
    final controlButtons = <Widget>[
      // Mute button - always available
      showVideoControls
          ? _CallCompactControlButton(
              icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: isMuted ? 'Unmute' : 'Mute',
              isActive: isMuted,
              onTap: onToggleMute,
              isDesktop: isDesktop,
            )
          : _CallControlButton(
              icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: isMuted ? 'Unmute' : 'Mute',
              isActive: isMuted,
              onTap: isConnected ? onToggleMute : null,
              enabled: isConnected,
            ),

      // Camera toggle - show when callback provided (video and voice calls; voice can turn camera on)
      if (onToggleCamera != null)
        _CallCompactControlButton(
          icon:
              isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
          label: 'Camera',
          isActive: isCameraOff,
          onTap: onToggleCamera,
          isDesktop: isDesktop,
        ),

      // Speaker toggle - only on mobile/desktop (not web)
      if (showSpeaker && onToggleSpeaker != null)
        showVideoControls
            ? _CallCompactControlButton(
                icon: isSpeakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: 'Speaker',
                isActive: isSpeakerOn,
                onTap: onToggleSpeaker,
                isDesktop: isDesktop,
              )
            : _CallControlButton(
                icon: isSpeakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: 'Speaker',
                isActive: isSpeakerOn,
                onTap: isConnected ? onToggleSpeaker : null,
                enabled: isConnected,
              ),

      // Flip camera - show when callback provided
      if (onFlipCamera != null)
        _CallCompactControlButton(
          icon: Icons.flip_camera_ios_rounded,
          label: 'Flip',
          isActive: false,
          onTap: onFlipCamera,
          isDesktop: isDesktop,
        ),
    ];

    return Container(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        top: verticalPadding,
        bottom: bottomPadding,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: showVideoControls
              ? [
                  Colors.black.withValues(alpha: isDesktop ? 0.9 : 0.85),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                ]
              : [
                  Colors.black.withValues(alpha: isDesktop ? 0.6 : 0.4),
                  Colors.transparent,
                ],
          stops: showVideoControls ? const [0.0, 0.6, 1.0] : const [0.0, 1.0],
        ),
      ),
      child: isDesktop
          ? // Desktop: All buttons in single row with proper spacing
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add spacing between control buttons
                ...controlButtons
                    .expand((button) => [
                          button,
                          SizedBox(width: 24),
                        ])
                    .toList()
                  ..removeLast(), // Remove last spacing
                SizedBox(width: 32),
                CallEndCallButton(onTap: onEndCall, isDesktop: isDesktop),
              ],
            )
          : // Mobile: Two rows (controls on top, end call below)
          Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: controlButtons,
                ),
                SizedBox(height: showVideoControls ? 20 : 32),
                CallEndCallButton(onTap: onEndCall, isDesktop: isDesktop),
              ],
            ),
    );
  }
}

// Legacy aliases for backward compatibility during migration
@Deprecated('Use UnifiedCallControls instead')
class AudioCallControls extends StatelessWidget {
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isConnected;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onEndCall;
  final bool isDesktop;

  const AudioCallControls({
    super.key,
    required this.isMuted,
    required this.isSpeakerOn,
    required this.isConnected,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onEndCall,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedCallControls(
      isMuted: isMuted,
      isCameraOff: true,
      isSpeakerOn: isSpeakerOn,
      isConnected: isConnected,
      hasVideoTrack: false,
      isVideoCall: false,
      onToggleMute: onToggleMute,
      onToggleSpeaker: onToggleSpeaker,
      onEndCall: onEndCall,
      isDesktop: isDesktop,
    );
  }
}

@Deprecated('Use UnifiedCallControls instead')
class VideoCallControls extends StatelessWidget {
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onFlipCamera;
  final VoidCallback onEndCall;
  final bool isDesktop;

  const VideoCallControls({
    super.key,
    required this.isMuted,
    required this.isCameraOff,
    required this.isSpeakerOn,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onToggleSpeaker,
    required this.onFlipCamera,
    required this.onEndCall,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedCallControls(
      isMuted: isMuted,
      isCameraOff: isCameraOff,
      isSpeakerOn: isSpeakerOn,
      isConnected: true,
      hasVideoTrack: true,
      isVideoCall: true,
      onToggleMute: onToggleMute,
      onToggleCamera: onToggleCamera,
      onToggleSpeaker: onToggleSpeaker,
      onFlipCamera: onFlipCamera,
      onEndCall: onEndCall,
      isDesktop: isDesktop,
    );
  }
}

class CallSmallControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const CallSmallControlButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class CallEndCallButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool small;

  /// Whether to use desktop-optimized sizing
  final bool isDesktop;

  const CallEndCallButton({
    super.key,
    required this.onTap,
    this.small = false,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    // Responsive sizing: desktop > normal > small
    final double size;
    final double iconSize;
    if (small) {
      size = 56;
      iconSize = 26;
    } else if (isDesktop) {
      size = 80;
      iconSize = 36;
    } else {
      size = 72;
      iconSize = 32;
    }

    return Semantics(
      button: true,
      label: 'End call',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF5F5F),
                  Color(0xFFE53935),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withValues(alpha: 0.4),
                  blurRadius: isDesktop ? 24 : 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _CallCompactControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  /// Whether to use desktop-optimized sizing
  final bool isDesktop;

  const _CallCompactControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isDesktop = false,
  });

  @override
  State<_CallCompactControlButton> createState() =>
      _CallCompactControlButtonState();
}

class _CallCompactControlButtonState extends State<_CallCompactControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Responsive sizing
    final buttonSize = widget.isDesktop ? 60.0 : 48.0;
    final iconSize = widget.isDesktop ? 26.0 : 22.0;
    final labelSize = widget.isDesktop ? 12.0 : 11.0;
    final spacing = widget.isDesktop ? 8.0 : 6.0;

    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? Colors.white
                      : _isHovered
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: widget.isActive
                      ? null
                      : Border.all(
                          color: _isHovered
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.isActive ? Colors.black : Colors.white,
                  size: iconSize,
                ),
              ),
              SizedBox(height: spacing),
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: labelSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final bool enabled;

  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = !enabled || onTap == null;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: isActive
                    ? null
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.black : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
