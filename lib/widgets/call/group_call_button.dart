import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/config/call_ui_config.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/pages/call/group_call_screen.dart';
import 'package:aurogram/services/group_call_service.dart';

/// Single group call button for gram chat headers
/// - Normal state: Shows primary color icon
/// - Active call: Shows green pulsing icon to indicate call in progress
/// Tapping always navigates to call (starts new or joins existing)
/// Works on all platforms including web (Agora SDK 6.x supports web)
class GroupCallButton extends StatefulWidget {
  final String spaceId;
  final String spaceName;
  final double size;

  /// Use same color as other header icons when null (muted primary). Pass to match header.
  final Color? iconColor;

  const GroupCallButton({
    super.key,
    required this.spaceId,
    required this.spaceName,
    this.size = 22,
    this.iconColor,
  });

  @override
  State<GroupCallButton> createState() => _GroupCallButtonState();
}

class _GroupCallButtonState extends State<GroupCallButton> {
  bool _cleanupAttempted = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .doc(widget.spaceId)
          .collection('calls')
          .doc('active')
          .snapshots(),
      builder: (context, snapshot) {
        // Check if there's an active call
        bool hasActiveCall = false;
        int participantCount = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final participants = data?['participants'] as List<dynamic>? ?? [];
          hasActiveCall = participants.isNotEmpty;
          participantCount = participants.length;

          // Attempt cleanup of stale participants (only once per widget lifecycle)
          if (hasActiveCall && !_cleanupAttempted) {
            _cleanupAttempted = true;
            // Run cleanup asynchronously - don't block the UI
            GroupCallService.cleanupStaleCallParticipants(widget.spaceId);
          }
        }

        final button = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _startCall(context),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: hasActiveCall
                  ? _ActiveCallIcon(size: widget.size)
                  : Icon(
                      CallUIConfig.callIcon,
                      color: widget.iconColor ??
                          AppTheme.primaryColor.withValues(alpha: 0.7),
                      size: widget.size,
                    ),
            ),
          ),
        );

        return Tooltip(
          message: hasActiveCall
              ? 'Join call ($participantCount in call)'
              : 'Start call',
          child: button,
        );
      },
    );
  }

  void _startCall(BuildContext context) {
    if (!kIsWeb) HapticFeedback.lightImpact();

    // Check if user is already in this call
    final groupCallService = GroupCallService();
    if (groupCallService.isInCall &&
        groupCallService.activeSpaceId == widget.spaceId) {
      // Already in this call - navigate back to it
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GroupCallScreen(
            spaceId: widget.spaceId,
            spaceName: widget.spaceName,
          ),
        ),
      );
      return;
    }

    if (groupCallService.isInCall) {
      // In a different call
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Already in another call'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Navigate to group call screen (start or join)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupCallScreen(
          spaceId: widget.spaceId,
          spaceName: widget.spaceName,
        ),
      ),
    );
  }
}

/// Animated icon for active call state
class _ActiveCallIcon extends StatefulWidget {
  final double size;

  const _ActiveCallIcon({required this.size});

  @override
  State<_ActiveCallIcon> createState() => _ActiveCallIconState();
}

class _ActiveCallIconState extends State<_ActiveCallIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: CallUIConfig.activeCallColor
                      .withValues(alpha: 0.5 * _animation.value),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              CallUIConfig.callActiveIcon,
              color: CallUIConfig.activeCallColor,
              size: widget.size,
            ),
          ),
        );
      },
    );
  }
}

/// Circular group call button variant (for use in different layouts)
/// Works on all platforms including web (Agora SDK 6.x supports web)
class GroupCallButtonCircle extends StatelessWidget {
  final String spaceId;
  final String spaceName;
  final double size;

  const GroupCallButtonCircle({
    super.key,
    required this.spaceId,
    required this.spaceName,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('calls')
          .doc('active')
          .snapshots(),
      builder: (context, snapshot) {
        bool hasActiveCall = false;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final participants = data?['participants'] as List<dynamic>? ?? [];
          hasActiveCall = participants.isNotEmpty;
        }

        final buttonColor = hasActiveCall
            ? CallUIConfig.activeCallColor
            : AppTheme.primaryColor;

        return Tooltip(
          message: hasActiveCall ? 'Join call' : 'Start call',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _startCall(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color:
                      buttonColor.withValues(alpha: hasActiveCall ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                  border: hasActiveCall
                      ? Border.all(color: buttonColor, width: 2)
                      : null,
                ),
                child: Icon(
                  hasActiveCall
                      ? CallUIConfig.callActiveIcon
                      : CallUIConfig.callIcon,
                  color: buttonColor,
                  size: size * 0.55,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _startCall(BuildContext context) {
    if (!kIsWeb) HapticFeedback.lightImpact();

    final groupCallService = GroupCallService();
    if (groupCallService.isInCall &&
        groupCallService.activeSpaceId != spaceId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Already in another call'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupCallScreen(
          spaceId: spaceId,
          spaceName: spaceName,
        ),
      ),
    );
  }
}
