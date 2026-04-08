import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/widgets/common/user_avatar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/notifications/unified_notification_card.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Tile for mutual follow notification - "You and X are now friends!"
/// Special celebration design to highlight this special moment
class MutualFollowTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const MutualFollowTile({this.data, super.key});

  @override
  _MutualFollowTileState createState() => _MutualFollowTileState();
}

class _MutualFollowTileState extends State<MutualFollowTile> {
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
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_fromUserId)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data();
            _fromUserName = data?['name']?.toString() ?? _fromUserName;
            _fromUserAvatar = data?['displayPicture']?.toString() ?? _fromUserAvatar;
          }
        } catch (_) {
          AppLogger.w('FollowRequestTile: user doc fetch failed for mutual follow',
              category: LogCategory.general);
        }
      }
    } catch (e) {
      AppLogger.e('Error fetching mutual follow notification data',
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
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => UserProfilePage(uid: _fromUserId),
      ),
    );
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
              // Avatar with glow effect
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isRead ? null : [
                    BoxShadow(
                      color: AppTheme.honeyAmber.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: UserAvatar(
                  userId: _fromUserId,
                  imageUrl: _fromUserAvatar,
                  size: 48,
                  nameInitials: _fromUserName.isNotEmpty ? _fromUserName[0] : null,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMdLg),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: AppTheme.holyCowTextSize,
                                color: primaryColor,
                                height: 1.3,
                              ),
                              children: [
                                const TextSpan(
                                  text: '🎉 ',
                                  style: TextStyle(fontSize: AppTheme.holyCowTextSize),
                                ),
                                const TextSpan(
                                  text: 'You and ',
                                  style: TextStyle(fontWeight: FontWeight.w400),
                                ),
                                TextSpan(
                                  text: _fromUserName,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const TextSpan(
                                  text: ' are now friends!',
                                  style: TextStyle(fontWeight: FontWeight.w400),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingSmMd),
                    // CTA hint
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.honeyAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.sparkles,
                            size: 11,
                            color: AppTheme.honeyAmber,
                          ),
                          const SizedBox(width: AppDimensions.spacingXs),
                          Text(
                            'Check compatibility',
                            style: TextStyle(
                              fontSize: AppTheme.holyCowTextSize,
                              color: AppTheme.honeyAmber,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      _date,
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        color: primaryColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              // Heart icon with container
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingSm),
                decoration: BoxDecoration(
                  color: AppTheme.honeyAmber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.heart_fill,
                  color: AppTheme.honeyAmber,
                  size: 18,
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
