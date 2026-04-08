import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/features/calling/domain/call_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/calling/presentation/pages/call_screen.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/profile/domain/follow_service.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

/// Compact call button for chat headers
class CallButton extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;
  final CallType callType;
  final double size;

  const CallButton({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.callType,
    this.size = 40,
  });

  @override
  State<CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends State<CallButton> {
  bool _isStartingCall = false;
  final CallService _callService = CallService();

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == CallType.video;

    return GestureDetector(
      onTap: _isStartingCall ? null : () => _startCall(context),
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: _isStartingCall ? 0.5 : 1.0,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isVideo ? Icons.videocam_rounded : Icons.call_rounded,
            color: AppTheme.primaryColor,
            size: widget.size * 0.55,
          ),
        ),
      ),
    );
  }

  Future<void> _startCall(BuildContext context) async {
    // Prevent double-tap and check if already in a call
    if (_isStartingCall) return;

    if (_callService.isInCall || _callService.state != CallState.idle) {
      AppLogger.w('Cannot start call - already in a call',
          category: LogCategory.general);
      if (context.mounted) {
        showCustomSnackBar(context, message: 'You are already in a call', duration: const Duration(seconds: 2));
      }
      return;
    }

    setState(() => _isStartingCall = true);
    if (!kIsWeb) HapticFeedback.mediumImpact();

    if (!context.mounted) {
      setState(() => _isStartingCall = false);
      return;
    }

    // Navigate to call screen - push notification will alert the user
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          calleeId: widget.userId,
          calleeName: widget.userName,
          calleeAvatar: widget.userAvatar,
          callType: widget.callType,
        ),
      ),
    )
        .then((_) {
      // Reset state when returning from call screen
      if (mounted) {
        setState(() => _isStartingCall = false);
      }
    });
  }
}

/// Combined call buttons (voice + video) for chat headers
class CallButtons extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;
  final double iconSize;
  final double spacing;

  const CallButtons({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.iconSize = 22,
    this.spacing = 8,
  });

  @override
  State<CallButtons> createState() => _CallButtonsState();
}

class _CallButtonsState extends State<CallButtons> {
  bool _isStartingCall = false;
  final CallService _callService = CallService();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _isStartingCall ? 0.5 : 1.0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Voice call
          _CallIconButton(
            icon: Icons.call_rounded,
            tooltip: 'Voice call',
            onTap: _isStartingCall
                ? null
                : () => _startCall(context, CallType.voice),
            size: widget.iconSize,
          ),
          SizedBox(width: widget.spacing),
          // Video call
          _CallIconButton(
            icon: Icons.videocam_rounded,
            tooltip: 'Video call',
            onTap: _isStartingCall
                ? null
                : () => _startCall(context, CallType.video),
            size: widget.iconSize,
          ),
        ],
      ),
    );
  }

  Future<void> _startCall(BuildContext context, CallType type) async {
    // Prevent double-tap and check if already in a call
    if (_isStartingCall) return;

    if (_callService.isInCall || _callService.state != CallState.idle) {
      AppLogger.w('Cannot start call - already in a call',
          category: LogCategory.general);
      if (context.mounted) {
        showCustomSnackBar(context, message: 'You are already in a call', duration: const Duration(seconds: 2));
      }
      return;
    }

    setState(() => _isStartingCall = true);
    if (!kIsWeb) HapticFeedback.mediumImpact();

    if (!context.mounted) {
      setState(() => _isStartingCall = false);
      return;
    }

    try {
      // Check mutual follow before starting call
      final followService = FollowService();
      final isMutual = await followService.isMutualFollow(widget.userId);
      
      if (!isMutual) {
        if (mounted) {
          showCustomSnackBar(context, message: 'You can only call people who follow you back', backgroundColor: AppTheme.errorColor, duration: const Duration(seconds: 3));
        }
        setState(() => _isStartingCall = false);
        return;
      }

      // Navigate to call screen - push notification will alert the user
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => CallScreen(
            calleeId: widget.userId,
            calleeName: widget.userName,
            calleeAvatar: widget.userAvatar,
            callType: type,
          ),
        ),
      )
          .then((_) {
        // Reset state when returning from call screen
        if (mounted) {
          setState(() => _isStartingCall = false);
        }
      });
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, message: 'Cannot start call: ${e.toString()}', backgroundColor: AppTheme.errorColor, duration: const Duration(seconds: 3));
      }
      setState(() => _isStartingCall = false);
    }
  }
}

class _CallIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;

  const _CallIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = MouseRegion(
      cursor:
          onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Icon(
            icon,
            color: AppTheme.primaryColor
                .withValues(alpha: onTap != null ? 0.8 : 0.4),
            size: size,
          ),
        ),
      ),
    );

    // Show tooltip on web for better discoverability
    if (kIsWeb) {
      return Tooltip(
        message: tooltip,
        child: button,
      );
    }

    return button;
  }
}
