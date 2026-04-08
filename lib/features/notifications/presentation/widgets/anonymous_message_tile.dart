import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:aurogram/features/notifications/presentation/widgets/unified_notification_card.dart';
import 'package:aurogram/features/anonymous_messages/pages/inbox_screen.dart';

class AnonymousMessageTile extends StatelessWidget {
  final Map<String, dynamic>? data;

  const AnonymousMessageTile({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    final timestamp = data?['timestamp'];
    final dateTime =
        timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
    final preview = data?['preview']?.toString();
    final isRead = data?['read'] == true;

    return UnifiedNotificationCard(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          CupertinoIcons.lock_fill,
          color: AppTheme.primaryColor,
          size: 18,
        ),
      ),
      title: 'New anonymous message',
      subtitle: preview != null && preview.isNotEmpty
          ? preview
          : 'Tap to see what they said',
      timestamp: TimeDisplay.getCompactTimestamp(dateTime),
      isRead: isRead,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SecretMessagesInboxScreen(),
          ),
        );
      },
    );
  }
}
