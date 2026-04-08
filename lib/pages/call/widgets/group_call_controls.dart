import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

class GroupCallControls extends StatelessWidget {
  final bool isAudioMuted;
  final bool isVideoOff;
  final bool isSpeakerOn;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleVideo;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onFlipCamera;
  final VoidCallback onLeave;

  const GroupCallControls({
    super.key,
    required this.isAudioMuted,
    required this.isVideoOff,
    required this.isSpeakerOn,
    required this.onToggleMute,
    required this.onToggleVideo,
    required this.onToggleSpeaker,
    required this.onFlipCamera,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.9),
              Colors.black.withValues(alpha: 0.5),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ControlButton(
              icon: isAudioMuted ? Icons.mic_off : Icons.mic,
              label: isAudioMuted ? 'Unmute' : 'Mute',
              onTap: onToggleMute,
              isActive: isAudioMuted,
            ),
            _ControlButton(
              icon: isVideoOff ? Icons.videocam_off : Icons.videocam,
              label: isVideoOff ? 'Start' : 'Stop',
              onTap: onToggleVideo,
              isActive: isVideoOff,
            ),
            _EndCallButton(onTap: onLeave),
            // Speaker toggle - only on mobile (web audio output is managed by OS)
            if (!kIsWeb)
              _ControlButton(
                icon: isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                label: 'Speaker',
                onTap: onToggleSpeaker,
                isActive: isSpeakerOn,
                activeColor: Colors.white,
                inactiveColor: Colors.white.withValues(alpha: 0.2),
              ),
            // Flip camera - available on all platforms (mobile web has multiple cameras)
            _ControlButton(
              icon: Icons.flip_camera_ios,
              label: 'Flip',
              onTap: onFlipCamera,
              isActive: false,
              enabled: !isVideoOff,
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool enabled;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isActive,
    this.activeColor,
    this.inactiveColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? (activeColor ?? Colors.white)
                      : (inactiveColor ?? Colors.white.withValues(alpha: 0.15)),
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
              const SizedBox(height: AppDimensions.spacingSmMd),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
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

class _EndCallButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EndCallButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Leave call',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF5F5F), AppTheme.dangerRed],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.dangerRed.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 28),
            ),
            const SizedBox(height: AppDimensions.spacingSmMd),
            Text(
              'Leave',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
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
