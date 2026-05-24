import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/shared/data/repositories/notification_repository.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/notifications/presentation/widgets/unified_notification_card.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Tile for follow request notifications (type: followRequest)
/// Shows accept/decline buttons for private profile follow requests
class FollowRequestTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const FollowRequestTile({this.data, super.key});

  @override
  _FollowRequestTileState createState() => _FollowRequestTileState();
}

class _FollowRequestTileState extends State<FollowRequestTile> {
  String _fromUserName = '';
  String _fromUserAvatar = '';
  String _fromUserId = '';
  String _date = '';
  bool _ready = false;
  bool _isProcessing = false;
  bool _isAccepted = false;
  bool _isDeclined = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      _fromUserId = widget.data?['fromUserId']?.toString() ?? '';
      _fromUserName = widget.data?['fromUserName']?.toString() ?? 'Someone';
      _fromUserAvatar = widget.data?['fromUserAvatar']?.toString() ?? '';

      // Fetch date
      if (widget.data?['timestamp'] is Timestamp) {
        _date = TimeDisplay.getCompactTimestamp(
            (widget.data!['timestamp'] as Timestamp).toDate());
      } else {
        _date = 'Recently';
      }

      // If we have a fromUserId, try to get latest user info
      if (_fromUserId.isNotEmpty) {
        try {
          final userDoc = await locator<UserRepository>().getUser(_fromUserId);
          if (userDoc.exists) {
            final data = userDoc.data();
            _fromUserName = data?['name']?.toString() ?? _fromUserName;
            _fromUserAvatar = data?['displayPicture']?.toString() ?? _fromUserAvatar;
          }
        } catch (_) {
          AppLogger.w('FollowRequestTile: user doc fetch failed for follow request',
              category: LogCategory.general);
        }
      }
    } catch (e) {
      AppLogger.e('Error fetching follow request notification data',
          category: LogCategory.general, data: {'error': e.toString()});
      if (_fromUserName.isEmpty) _fromUserName = 'Someone';
      if (_date.isEmpty) _date = 'Recently';
    } finally {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  Future<void> _acceptRequest() async {
    if (_isProcessing || _fromUserId.isEmpty) return;

    final currentUserId = _getCurrentUserId();
    if (currentUserId.isEmpty) return;

    // Haptic feedback for action
    HapticFeedback.lightImpact();

    setState(() => _isProcessing = true);

    try {
      // Call backend function to accept the follow request
      // Backend has Admin SDK access to update the follower's document
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('socialGateway');
      await callable.call({'method': 'acceptFollowRequest', 'followerId': _fromUserId});

      // Success haptic
      HapticFeedback.mediumImpact();

      if (mounted) {
        setState(() {
          _isAccepted = true;
          _isProcessing = false;
        });
      }

      // Mark notification as read
      _markAsRead();
    } catch (e) {
      AppLogger.e('Error accepting follow request', error: e);
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _isProcessing = false);
        showCustomSnackBar(context, message: 'Failed to accept request', backgroundColor: AppTheme.errorColor);
      }
    }
  }

  Future<void> _declineRequest() async {
    if (_isProcessing || _fromUserId.isEmpty) return;

    final currentUserId = _getCurrentUserId();
    if (currentUserId.isEmpty) return;

    // Haptic feedback for action
    HapticFeedback.lightImpact();

    setState(() => _isProcessing = true);

    try {
      // Call backend function to reject the follow request
      // Backend has Admin SDK access to delete the follower's document
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('socialGateway');
      await callable.call({'method': 'rejectFollowRequest', 'followerId': _fromUserId});

      if (mounted) {
        setState(() {
          _isDeclined = true;
          _isProcessing = false;
        });
      }

      // Mark notification as read
      _markAsRead();
    } catch (e) {
      AppLogger.e('Error declining follow request', error: e);
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _isProcessing = false);
        showCustomSnackBar(context, message: 'Failed to decline request', backgroundColor: AppTheme.errorColor);
      }
    }
  }

  String _getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  void _markAsRead() {
    final notificationId = widget.data?['id']?.toString();
    final userId = _getCurrentUserId();
    if (notificationId != null && userId.isNotEmpty) {
      locator<NotificationRepository>().markAsRead(userId, notificationId);
    }
  }

  void _openProfile() {
    if (_fromUserId.isEmpty) return;
    context.push('${RouteNames.userProfile}/$_fromUserId');
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingXs, horizontal: AppDimensions.paddingLg),
        child: SkeletonListItem(height: 80),
      );
    }

    final primaryColor = AppTheme.primaryColor;
    final bool isRead = widget.data?['read'] == true;

    return Container(
      decoration: notificationTileDecoration(isRead: isRead),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openProfile,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              UserAvatar(
                userId: _fromUserId,
                imageUrl: _fromUserAvatar,
                size: 44,
                nameInitials: _fromUserName.isNotEmpty ? _fromUserName[0] : null,
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          color: primaryColor,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text: _fromUserName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' wants to follow you'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      _date,
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        color: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                    // Action buttons
                    if (!_isAccepted && !_isDeclined) ...[
                      const SizedBox(height: AppDimensions.spacingMd),
                      Row(
                        children: [
                          // Accept button
                          Expanded(
                            child: GestureDetector(
                              onTap: _isProcessing ? null : _acceptRequest,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _isProcessing
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CupertinoActivityIndicator(
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              CupertinoIcons.checkmark_alt,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: AppDimensions.spacingSmMd),
                                            const Text(
                                              'Accept',
                                              style: TextStyle(
                                                fontSize: AppTheme.holyCowTextSize,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingMdSm),
                          // Decline button
                          Expanded(
                            child: GestureDetector(
                              onTap: _isProcessing ? null : _declineRequest,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                                  border: Border.all(
                                    color: primaryColor.withValues(alpha: 0.25),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Decline',
                                    style: TextStyle(
                                      fontSize: AppTheme.holyCowTextSize,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor.withValues(alpha: 0.7),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: AppDimensions.spacingMdSm),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isAccepted
                              ? AppTheme.successColor.withValues(alpha: 0.1)
                              : primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isAccepted
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : CupertinoIcons.xmark_circle_fill,
                              size: 14,
                              color: _isAccepted
                                  ? AppTheme.successColor
                                  : primaryColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: AppDimensions.spacingSmMd),
                            Text(
                              _isAccepted ? 'Accepted' : 'Declined',
                              style: TextStyle(
                                fontSize: AppTheme.holyCowTextSize,
                                fontWeight: FontWeight.w600,
                                color: _isAccepted
                                    ? AppTheme.successColor
                                    : primaryColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
