import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/notifications/presentation/widgets/unified_notification_card.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Tile for follow accepted notifications (type: followAccepted)
/// Shows when a private profile user accepts your follow request
class FollowAcceptedTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const FollowAcceptedTile({this.data, super.key});

  @override
  _FollowAcceptedTileState createState() => _FollowAcceptedTileState();
}

class _FollowAcceptedTileState extends State<FollowAcceptedTile> {
  String _fromUserName = '';
  String _fromUserAvatar = '';
  String _fromUserId = '';
  String _date = '';
  bool _ready = false;

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

      if (_fromUserId.isNotEmpty) {
        try {
          final userDoc = await locator<UserRepository>().getUser(_fromUserId);
          if (userDoc.exists) {
            final data = userDoc.data();
            _fromUserName = data?['name']?.toString() ?? _fromUserName;
            _fromUserAvatar = data?['displayPicture']?.toString() ?? _fromUserAvatar;
          }
        } catch (_) {
          AppLogger.w('FollowRequestTile: user doc fetch failed for follow accepted',
              category: LogCategory.general);
        }
      }
    } catch (e) {
      AppLogger.e('Error fetching follow accepted notification data',
          category: LogCategory.general, data: {'error': e.toString()});
    } finally {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  void _openProfile() {
    if (_fromUserId.isEmpty) return;
    HapticFeedback.selectionClick();
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
              // Avatar with success indicator
              Stack(
                children: [
                  UserAvatar(
                    userId: _fromUserId,
                    imageUrl: _fromUserAvatar,
                    size: 46,
                    nameInitials: _fromUserName.isNotEmpty ? _fromUserName[0] : null,
                  ),
                  // Success badge
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.scaffoldLightColor,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.checkmark,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppDimensions.spacingMdLg),
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
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(
                            text: ' accepted your follow request',
                            style: TextStyle(fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSmMd),
                    Text(
                      _date,
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        color: primaryColor.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: primaryColor.withValues(alpha: 0.3),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
