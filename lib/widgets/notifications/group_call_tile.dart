import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/pages/spaces/space_chat_screen.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/notifications/unified_notification_card.dart';

/// Alerts list tile for a group call in a gram. Tap opens space chat (call entry).
class GroupCallTile extends StatelessWidget {
  final Map<String, dynamic>? data;

  const GroupCallTile({this.data, super.key});

  String _timestamp() {
    if (data?['timestamp'] != null) {
      try {
        final ts = data!['timestamp'];
        return TimeDisplay.getCompactTimestamp(
            ts is Timestamp ? ts.toDate() : DateTime.now());
      } catch (_) {}
    }
    return 'Recently';
  }

  @override
  Widget build(BuildContext context) {
    final spaceId = data?['spaceId']?.toString() ?? '';
    final spaceName = data?['spaceName']?.toString() ?? 'a gram';
    final callerName = data?['callerName']?.toString() ?? 'Someone';
    final participantCount = data?['participantCount'] is int
        ? data!['participantCount'] as int
        : int.tryParse(data?['participantCount']?.toString() ?? '') ?? 0;
    final isRead = data?['read'] == true;

    final title = spaceName;
    final subtitle = participantCount > 0
        ? '📞 $callerName started a call · $participantCount in call'
        : '📞 $callerName started a group call';

    return UnifiedNotificationCard(
      isRead: isRead,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          CupertinoIcons.person_2_fill,
          color: AppTheme.primaryColor,
          size: 22,
        ),
      ),
      title: title,
      subtitle: subtitle,
      timestamp: _timestamp(),
      onTap: () {
        if (spaceId.isNotEmpty) {
          Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(
              builder: (context) => SpaceChatScreen(spaceId: spaceId),
            ),
          );
        }
      },
    );
  }
}
