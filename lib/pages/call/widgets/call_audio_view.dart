import 'package:flutter/material.dart';
import 'package:aurogram/services/call_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/common/user_avatar.dart';
import 'package:aurogram/pages/call/widgets/call_controls.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Full audio (pre-connected / voice-only) call UI.
/// Shown before the call is connected, or when in audio-only mode.
class CallAudioView extends StatelessWidget {
  final String calleeId;
  final String calleeName;
  final String? calleeAvatar;
  final CallState callState;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final bool hasVideoTrack;
  final bool isVideoCall;
  final bool isDesktop;
  final ValueNotifier<int> callDuration;
  final Animation<double> pulseAnimation;
  final AnimationController ringController;
  final AnimationController dotsController;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onFlipCamera;
  final VoidCallback onEndCall;

  const CallAudioView({
    super.key,
    required this.calleeId,
    required this.calleeName,
    this.calleeAvatar,
    required this.callState,
    required this.isMuted,
    required this.isCameraOff,
    required this.isSpeakerOn,
    required this.hasVideoTrack,
    required this.isVideoCall,
    required this.isDesktop,
    required this.callDuration,
    required this.pulseAnimation,
    required this.ringController,
    required this.dotsController,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onToggleSpeaker,
    required this.onFlipCamera,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkGradientBase,
            AppTheme.callGradientMid,
            Color(0xFF0F0F1A),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _CallAudioTopBar(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CallAvatarSection(
                    calleeId: calleeId,
                    calleeName: calleeName,
                    calleeAvatar: calleeAvatar,
                    callState: callState,
                    pulseAnimation: pulseAnimation,
                    ringController: ringController,
                  ),
                  const SizedBox(height: AppDimensions.spacingSection),
                  _CallCalleeName(calleeName: calleeName),
                  const SizedBox(height: AppDimensions.spacingMd),
                  CallStatusText(
                    callState: callState,
                    callDuration: callDuration,
                    dotsController: dotsController,
                  ),
                  const SizedBox(height: AppDimensions.spacingXxl),
                  if (callState == CallState.connected) const CallEncryptedBadge(),
                ],
              ),
            ),
            UnifiedCallControls(
              isMuted: isMuted,
              isCameraOff: isCameraOff,
              isSpeakerOn: isSpeakerOn,
              isConnected: callState == CallState.connected,
              hasVideoTrack: hasVideoTrack,
              isVideoCall: isVideoCall,
              onToggleMute: onToggleMute,
              onToggleCamera: onToggleCamera,
              onToggleSpeaker: onToggleSpeaker,
              onFlipCamera: onFlipCamera,
              onEndCall: onEndCall,
              isDesktop: isDesktop,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small private top-bar used only in the audio (pre-connected) view
// ---------------------------------------------------------------------------
class _CallAudioTopBar extends StatelessWidget {
  const _CallAudioTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated avatar section with pulsing ring(s)
// ---------------------------------------------------------------------------
class CallAvatarSection extends StatelessWidget {
  final String calleeId;
  final String calleeName;
  final String? calleeAvatar;
  final CallState callState;
  final Animation<double> pulseAnimation;
  final AnimationController ringController;

  const CallAvatarSection({
    super.key,
    required this.calleeId,
    required this.calleeName,
    this.calleeAvatar,
    required this.callState,
    required this.pulseAnimation,
    required this.ringController,
  });

  @override
  Widget build(BuildContext context) {
    final isRinging =
        callState == CallState.ringing || callState == CallState.connecting;
    final isConnected = callState == CallState.connected;

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isRinging) ...[
            CallAnimatedRing(
                controller: ringController, delay: 0, size: 200),
            CallAnimatedRing(
                controller: ringController, delay: 0.33, size: 170),
            CallAnimatedRing(
                controller: ringController, delay: 0.66, size: 140),
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
            animation: pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isConnected ? 1.0 : pulseAnimation.value,
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
                  userId: calleeId,
                  imageUrl: calleeAvatar,
                  size: 134,
                  loadFromFirestore: calleeAvatar == null,
                  nameInitials: calleeName.isNotEmpty
                      ? calleeName[0].toUpperCase()
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
}

// ---------------------------------------------------------------------------
// A single animated ring used in the ringing state
// ---------------------------------------------------------------------------
class CallAnimatedRing extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final double size;

  const CallAnimatedRing({
    super.key,
    required this.controller,
    required this.delay,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final progress = ((controller.value + delay) % 1.0);
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
}

// ---------------------------------------------------------------------------
// Callee name text widget
// ---------------------------------------------------------------------------
class _CallCalleeName extends StatelessWidget {
  final String calleeName;

  const _CallCalleeName({required this.calleeName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        calleeName,
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
}

// ---------------------------------------------------------------------------
// Call status text (Ringing / Connecting / timer / Call ended)
// ---------------------------------------------------------------------------
class CallStatusText extends StatelessWidget {
  final CallState callState;
  final ValueNotifier<int> callDuration;
  final AnimationController dotsController;

  const CallStatusText({
    super.key,
    required this.callState,
    required this.callDuration,
    required this.dotsController,
  });

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: callDuration,
      builder: (context, duration, _) {
        String statusText;
        Color statusColor;

        switch (callState) {
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

        final showDots = callState == CallState.ringing ||
            callState == CallState.connecting ||
            callState == CallState.incoming ||
            callState == CallState.answering ||
            callState == CallState.idle;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (callState == CallState.connected) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00D26A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
            ],
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 16,
                fontWeight: callState == CallState.connected
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
            if (showDots) CallAnimatedDots(controller: dotsController),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Animated dots (...) for loading/ringing states
// ---------------------------------------------------------------------------
class CallAnimatedDots extends StatelessWidget {
  final AnimationController controller;

  const CallAnimatedDots({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = ((controller.value + delay) % 1.0);
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
}

// ---------------------------------------------------------------------------
// End-to-end encrypted badge
// ---------------------------------------------------------------------------
class CallEncryptedBadge extends StatelessWidget {
  const CallEncryptedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
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
          const SizedBox(width: AppDimensions.spacingSmMd),
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
}
