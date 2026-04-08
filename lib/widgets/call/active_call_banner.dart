import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/core/config/call_ui_config.dart';
import 'package:aurogram/features/calling/presentation/pages/group_call_screen.dart';
import 'package:aurogram/features/calling/domain/group_call_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Banner that shows when there's an active call in a gram
/// Allows users to easily join an ongoing call
class ActiveCallBanner extends StatefulWidget {
  final String spaceId;
  final String spaceName;

  const ActiveCallBanner({
    super.key,
    required this.spaceId,
    required this.spaceName,
  });

  @override
  State<ActiveCallBanner> createState() => _ActiveCallBannerState();
}

class _ActiveCallBannerState extends State<ActiveCallBanner> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _cleanupAttempted = false;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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
        // Don't show if no active call
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();
        
        final participants = data['participants'] as List<dynamic>? ?? [];
        if (participants.isEmpty) return const SizedBox.shrink();
        
        final participantCount = participants.length;
        
        // Attempt cleanup of stale participants (only once per widget lifecycle)
        if (!_cleanupAttempted) {
          _cleanupAttempted = true;
          // Run cleanup asynchronously - don't block the UI
          GroupCallService.cleanupStaleCallParticipants(widget.spaceId);
        }
        
        // Check if current user is already in the call
        final groupCallService = GroupCallService();
        final isInCall = groupCallService.isInCall && 
            groupCallService.activeSpaceId == widget.spaceId;
        
        if (isInCall) return const SizedBox.shrink();
        
        return GestureDetector(
          onTap: _joinCall,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.activeGreen.withValues(alpha: _pulseAnimation.value),
                      const Color(0xFF2E7D32).withValues(alpha: _pulseAnimation.value),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.activeGreen.withValues(alpha: 0.3 * _pulseAnimation.value),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Call icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CallUIConfig.callBannerIcon,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),
                    
                    // Call info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Call in progress',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingXxs),
                          Text(
                            '$participantCount ${participantCount == 1 ? 'participant' : 'participants'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Join button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                      ),
                      child: const Text(
                        'Join',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _joinCall() {
    HapticFeedback.mediumImpact();
    
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

/// Compact active call indicator for header
class ActiveCallIndicator extends StatelessWidget {
  final String spaceId;
  final String spaceName;
  final double size;

  const ActiveCallIndicator({
    super.key,
    required this.spaceId,
    required this.spaceName,
    this.size = 32,
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
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final participants = data?['participants'] as List<dynamic>? ?? [];
        if (participants.isEmpty) return const SizedBox.shrink();
        
        final groupCallService = GroupCallService();
        final isInCall = groupCallService.isInCall && 
            groupCallService.activeSpaceId == spaceId;
        
        return GestureDetector(
          onTap: () => _openCall(context),
          child: Container(
            width: size,
            height: size,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isInCall 
                  ? AppTheme.activeGreen 
                  : AppTheme.activeGreen.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.activeGreen,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                CallUIConfig.callActiveIcon,
                color: isInCall ? Colors.white : CallUIConfig.activeCallColor,
                size: size * 0.5,
              ),
            ),
          ),
        );
      },
    );
  }

  void _openCall(BuildContext context) {
    HapticFeedback.lightImpact();
    
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
