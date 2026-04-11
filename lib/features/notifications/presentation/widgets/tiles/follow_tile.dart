import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot, Timestamp;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/features/profile/domain/follow_service.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/notifications/presentation/widgets/unified_notification_card.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Tile for follow notifications (type: follow)
/// Shows when someone starts following you (public profile)
/// Includes "Follow Back" button for quick action
class FollowTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const FollowTile({this.data, super.key});

  @override
  _FollowTileState createState() => _FollowTileState();
}

class _FollowTileState extends State<FollowTile> {
  final FollowService _followService = FollowService();
  String _fromUserName = '';
  String _fromUserAvatar = '';
  String _fromUserId = '';
  String _date = '';
  bool _ready = false;
  bool _isFollowingBack = false;
  bool _isFollowLoading = false;
  bool _isPrivateProfile = false;

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

      if (widget.data?['timestamp'] is Timestamp) {
        _date = TimeDisplay.getCompactTimestamp(
            (widget.data!['timestamp'] as Timestamp).toDate());
      } else {
        _date = 'Recently';
      }

      // Fetch latest user info and check follow status in parallel
      if (_fromUserId.isNotEmpty) {
        try {
          final results = await Future.wait([
            locator<UserRepository>().getUser(_fromUserId),
            _followService.isFollowing(_fromUserId),
          ]);

          final userDoc = results[0] as DocumentSnapshot;
          _isFollowingBack = results[1] as bool;

          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            _fromUserName = data?['name']?.toString() ?? _fromUserName;
            _fromUserAvatar = data?['displayPicture']?.toString() ?? _fromUserAvatar;
            _isPrivateProfile = data?['isPrivateProfile'] == true;
          }
        } catch (_) {
          AppLogger.w('FollowRequestTile: user doc fetch failed for follow notification',
              category: LogCategory.general);
        }
      }
    } catch (e) {
      AppLogger.e('Error fetching follow notification data',
          category: LogCategory.general, data: {'error': e.toString()});
    } finally {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  Future<void> _followBack() async {
    if (_isFollowLoading || _fromUserId.isEmpty) return;

    // Haptic feedback
    HapticFeedback.lightImpact();

    setState(() => _isFollowLoading = true);

    try {
      // Use FollowService for consistency
      final success = await _followService.followUser(
        _fromUserId,
        targetIsPrivate: _isPrivateProfile,
      );

      if (success) {
        HapticFeedback.mediumImpact();
        if (mounted) {
          setState(() {
            _isFollowingBack = true;
            _isFollowLoading = false;
          });
        }
      } else {
        throw Exception('Follow failed');
      }
    } catch (e) {
      AppLogger.e('Error following back', error: e);
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
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
              children: [
                UserAvatar(
                  userId: _fromUserId,
                  imageUrl: _fromUserAvatar,
                  size: 44,
                  nameInitials: _fromUserName.isNotEmpty ? _fromUserName[0] : null,
                ),
                const SizedBox(width: AppDimensions.spacingMd),
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
                            const TextSpan(text: ' started following you'),
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
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                _buildFollowBackButton(primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowBackButton(Color primaryColor) {
    // Already following - show checkmark
    if (_isFollowingBack) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.checkmark_alt,
              size: 12,
              color: primaryColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 5),
            Text(
              'Following',
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w600,
                color: primaryColor.withValues(alpha: 0.7),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }

    // Loading state
    if (_isFollowLoading) {
      return Container(
        width: 88,
        height: 34,
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CupertinoActivityIndicator(color: primaryColor),
          ),
        ),
      );
    }

    // Follow Back button
    return GestureDetector(
      onTap: _followBack,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          'Follow Back',
          style: TextStyle(
            fontSize: AppTheme.holyCowTextSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
