import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/widgets/notifications/unified_notification_card.dart';
import 'package:aurogram/widgets/common/user_avatar.dart';

/// Alerts list tile for a missed voice/video call. Tap opens caller profile.
class MissedCallTile extends StatelessWidget {
  final Map<String, dynamic>? data;

  const MissedCallTile({this.data, super.key});

  String _timestamp() {
    if (data?['timestamp'] != null) {
      try {
        final ts = data!['timestamp'];
        return TimeDisplay.getCompactTimestamp(
            ts is Timestamp ? ts.toDate() : DateTime.now());
      } catch (_) {
        AppLogger.w('MissedCallTile: failed to parse timestamp', category: LogCategory.general);
      }
    }
    return 'Recently';
  }

  @override
  Widget build(BuildContext context) {
    final callerId = data?['callerId']?.toString() ?? '';
    final callerName = data?['callerName']?.toString() ?? 'Someone';
    final callerAvatar = data?['callerAvatar']?.toString() ?? '';
    final callType = data?['callType']?.toString() ?? 'voice';
    final isRead = data?['read'] == true;

    final title = 'Missed call from $callerName';
    final subtitle = callType == 'video'
        ? '📹 Missed video call'
        : '📞 Missed voice call';

    return UnifiedNotificationCard(
      isRead: isRead,
      leading: UserAvatar(
        userId: callerId,
        imageUrl: callerAvatar,
        size: 40,
        nameInitials: callerName.isNotEmpty ? callerName.substring(0, 1) : null,
      ),
      title: title,
      subtitle: subtitle,
      timestamp: _timestamp(),
      onTap: () {
        if (callerId.isNotEmpty) {
          Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(
              builder: (context) => UserProfilePage(uid: callerId),
            ),
          );
        }
      },
    );
  }
}
