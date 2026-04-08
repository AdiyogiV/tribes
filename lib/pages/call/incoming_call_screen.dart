import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:aurogram/services/call_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/common/user_avatar.dart';
import 'package:aurogram/pages/call/call_screen.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Full-screen incoming call UI
/// Modern design matching CallScreen
class IncomingCallScreen extends StatefulWidget {
  final Call call;

  const IncomingCallScreen({
    super.key,
    required this.call,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  final CallService _callService = CallService();

  late AnimationController _pulseController;
  late AnimationController _ringController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  Timer? _vibrationTimer;
  Timer? _timeoutTimer;
  bool _isHandled = false;

  @override
  void initState() {
    super.initState();

    AppLogger.i('📞 IncomingCallScreen.initState (isWeb: $kIsWeb)',
        category: LogCategory.general,
        data: {
          'callId': widget.call.id,
          'callerName': widget.call.callerName,
          'callType': widget.call.type.toString(),
        });

    _setupAnimations();
    _startVibration();

    // Auto-miss after 45 seconds
    _timeoutTimer = Timer(const Duration(seconds: 45), () {
      if (!_isHandled) {
        AppLogger.w('📞 IncomingCallScreen: timeout reached, marking as missed',
            category: LogCategory.general);
        _missCall();
      }
    });

    // NOTE: We do NOT set onCallStateChanged here anymore.
    // IncomingCallScreen uses its own Firestore listener (_setupCallStatusListener)
    // to detect when the caller hangs up.
    // Setting the callback here would cause a race condition where dispose()
    // clears the callback after CallScreen sets it when answering.

    // Validate call status on init (handles race conditions)
    _validateAndSetupCall();
  }

  /// Validate call is still valid and set up real-time listener
  Future<void> _validateAndSetupCall() async {
    try {
      // Check if call still exists and is ringing
      final callDoc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.call.id)
          .get();

      if (!mounted) return;

      if (!callDoc.exists) {
        AppLogger.w('Call no longer exists, dismissing',
            category: LogCategory.general);
        _handleCallEnded();
        return;
      }

      final status = callDoc.data()?['status'] as String?;
      if (status != 'ringing') {
        AppLogger.w('Call is no longer ringing (status: $status), dismissing',
            category: LogCategory.general);
        _handleCallEnded();
        return;
      }

      // Set up real-time listener for call status changes
      _setupCallStatusListener();
    } catch (e) {
      AppLogger.e('Error validating call status',
          category: LogCategory.general, error: e);
      // On error, be safe and dismiss
      _handleCallEnded();
    }
  }

  StreamSubscription<DocumentSnapshot>? _callStatusSubscription;

  /// Set up real-time listener for call status changes from Firestore
  void _setupCallStatusListener() {
    _callStatusSubscription?.cancel();
    _callStatusSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.call.id)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || _isHandled) return;

      if (!snapshot.exists) {
        AppLogger.d('Call document deleted, dismissing',
            category: LogCategory.general);
        _handleCallEnded();
        return;
      }

      final status = snapshot.data()?['status'] as String?;
      if (status != 'ringing') {
        AppLogger.d('Call status changed to $status, dismissing',
            category: LogCategory.general);
        _handleCallEnded();
      }
    });
  }

  /// Handle when call has ended (caller disconnected, etc.)
  void _handleCallEnded() {
    if (_isHandled) return;
    _isHandled = true;

    _cleanup();

    // Show brief message and pop
    Future.microtask(() {
      if (mounted) {
        showCustomSnackBar(context, message: 'Call ended', duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating);
        Navigator.of(context).pop();
      }
    });
  }

  void _setupAnimations() {
    // Gentle pulse for avatar
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Ring animation
    _ringController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    // Slide animation for buttons
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    // NOTE: Do NOT clear _callService.onCallStateChanged here!
    // If we're answering the call, CallScreen will have already set its callback.
    // Clearing it here would cause a race condition where the CallScreen's
    // callback gets cleared, preventing it from receiving state updates.

    _cleanup();
    _pulseController.dispose();
    _ringController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _cleanup() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _callStatusSubscription?.cancel();
    _callStatusSubscription = null;

    // Cancel vibration safely (not supported on web)
    if (!kIsWeb) {
      try {
        Vibration.cancel();
      } catch (e) {
        // Ignore vibration cancel errors
      }
    }
  }

  void _startVibration() async {
    // Vibration is not supported on web
    if (kIsWeb) {
      AppLogger.d('📞 Skipping vibration on web platform',
          category: LogCategory.general);
      return;
    }

    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return;

      _vibrationTimer =
          Timer.periodic(const Duration(milliseconds: 2000), (_) async {
        await Vibration.vibrate(duration: 500);
        await Future.delayed(const Duration(milliseconds: 200));
        await Vibration.vibrate(duration: 500);
      });

      Vibration.vibrate(duration: 500);
    } catch (e) {
      AppLogger.w('📞 Vibration error: $e', category: LogCategory.general);
    }
  }

  Future<void> _answerCall() async {
    if (_isHandled) return;
    _isHandled = true;

    AppLogger.i(
        '📞 User accepted call from ${widget.call.callerName}, navigating to CallScreen',
        category: LogCategory.general);

    HapticFeedback.mediumImpact();
    _cleanup();

    if (!mounted) return;

    // Navigate immediately to CallScreen
    // CallScreen will handle the actual answering and receive all callbacks
    // This ensures video streams are properly attached
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          calleeId: widget.call.callerId,
          calleeName: widget.call.callerName,
          calleeAvatar: widget.call.callerAvatar,
          callType: widget.call.type,
          isIncoming: true,
        ),
      ),
    );
  }

  Future<void> _rejectCall() async {
    if (_isHandled) return;
    _isHandled = true;

    HapticFeedback.mediumImpact();
    _cleanup();

    try {
      await _callService.rejectCall();
    } catch (e) {
      AppLogger.w('Error rejecting call: $e', category: LogCategory.general);
      // Continue to pop anyway - call is effectively rejected
    }

    Future.microtask(() {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _missCall() async {
    if (_isHandled) return;
    _isHandled = true;

    _cleanup();

    try {
      await _callService.missCall();
    } catch (e) {
      AppLogger.w('Error marking call as missed: $e',
          category: LogCategory.general);
      // Continue to pop anyway
    }

    Future.microtask(() {
      if (mounted) Navigator.of(context).pop();
    });
  }

  /// Check if we should use desktop layout (web or large screen)
  bool _isDesktopLayout(BuildContext context) {
    if (kIsWeb) return true;
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= 600; // Tablet/desktop breakpoint
  }

  @override
  Widget build(BuildContext context) {
    final bool isVideo = widget.call.isVideo;
    final bool isDesktop = _isDesktopLayout(context);

    return PopScope(
      // Intercept back button - pressing back rejects the call
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Reject the call when back button is pressed
        _rejectCall();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppTheme.callBackground,
          body: Container(
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
                  // Top section with call type
                  _buildTopSection(isVideo),

                  // Main content
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar with rings
                        _buildAvatarSection(isDesktop),

                        SizedBox(height: isDesktop ? 48 : 36),

                        // Caller name
                        _buildCallerName(isDesktop),

                        SizedBox(height: isDesktop ? 16 : 12),

                        // Call type badge
                        _buildCallTypeBadge(isVideo, isDesktop),
                      ],
                    ),
                  ),

                  // Bottom action buttons
                  _buildActionButtons(isVideo, isDesktop),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection(bool isVideo) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingXl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMdSm),
                Text(
                  'Incoming Call',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(bool isDesktop) {
    final containerSize = isDesktop ? 280.0 : 240.0;
    final avatarSize = isDesktop ? 160.0 : 140.0;
    final ringSizes = isDesktop ? [260.0, 230.0, 200.0] : [220.0, 190.0, 160.0];

    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated rings
          _buildAnimatedRing(0, ringSizes[0]),
          _buildAnimatedRing(0.33, ringSizes[1]),
          _buildAnimatedRing(0.66, ringSizes[2]),

          // Avatar with pulse
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: isDesktop ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: isDesktop ? 40 : 30,
                    spreadRadius: isDesktop ? 8 : 5,
                  ),
                ],
              ),
              child: ClipOval(
                child: UserAvatar(
                  userId: widget.call.callerId,
                  imageUrl: widget.call.callerAvatar,
                  size: avatarSize - 6.0,
                  loadFromFirestore: widget.call.callerAvatar == null,
                  nameInitials: widget.call.callerName.isNotEmpty
                      ? widget.call.callerName[0].toUpperCase()
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
        final opacity = (1.0 - progress) * 0.4;
        final scale = 0.5 + (progress * 0.5);

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

  Widget _buildCallerName(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 40),
      child: Text(
        widget.call.callerName,
        style: TextStyle(
          color: Colors.white,
          fontSize: isDesktop ? 36 : 30,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCallTypeBadge(bool isVideo, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 18 : 14,
        vertical: isDesktop ? 10 : 8,
      ),
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
            isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
            color: Colors.white.withValues(alpha: 0.7),
            size: isDesktop ? 18 : 16,
          ),
          SizedBox(width: isDesktop ? 10 : 8),
          Text(
            isVideo ? 'Video Call' : 'Voice Call',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: isDesktop ? 14 : 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isVideo, bool isDesktop) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: EdgeInsets.only(
          left: isDesktop ? 64 : 48,
          right: isDesktop ? 64 : 48,
          top: isDesktop ? 32 : 24,
          bottom: MediaQuery.of(context).padding.bottom + (isDesktop ? 40 : 32),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Decline button
            _buildActionButton(
              icon: Icons.call_end_rounded,
              label: 'Decline',
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF5F5F),
                  AppTheme.dangerRed,
                ],
              ),
              shadowColor: AppTheme.dangerRed,
              onTap: _rejectCall,
              isDesktop: isDesktop,
            ),

            SizedBox(width: isDesktop ? 48 : 32),

            // Accept button
            _buildActionButton(
              icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
              label: 'Accept',
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF66BB6A),
                  Color(0xFF43A047),
                ],
              ),
              shadowColor: const Color(0xFF43A047),
              onTap: _answerCall,
              isDesktop: isDesktop,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required LinearGradient gradient,
    required Color shadowColor,
    required VoidCallback onTap,
    bool isDesktop = false,
  }) {
    // Responsive sizing for desktop
    final buttonSize = isDesktop ? 88.0 : 72.0;
    final iconSize = isDesktop ? 40.0 : 32.0;
    final labelSize = isDesktop ? 15.0 : 14.0;
    final spacing = isDesktop ? 16.0 : 12.0;
    final shadowBlur = isDesktop ? 24.0 : 20.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.4),
                    blurRadius: shadowBlur,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: iconSize,
              ),
            ),
            SizedBox(height: spacing),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: labelSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
