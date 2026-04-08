import 'package:flutter/cupertino.dart';
import 'package:aurogram/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/services/namaste_service.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/models/space_types.dart';
import 'package:aurogram/pages/spaces/space_chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Mixin providing namaste, direct message, and block/unblock functionality
/// for the user profile page.
mixin ProfileUserInteractions<T extends StatefulWidget> on State<T> {
  /// Subclass must provide these
  String? get interactionTargetUid;
  User? get interactionCurrentUser;
  Map<String, dynamic>? get interactionCachedProfileData;
  bool get interactionIsUserBlocked;
  set interactionIsUserBlocked(bool value);

  Future<void> sendNamaste() async {
    if (interactionCurrentUser == null || interactionTargetUid == null) {
      showLoginBottomSheet(context);
      return;
    }

    final result = await NamasteService().sendNamaste(interactionTargetUid!);

    if (!mounted) return;

    if (result.success) {
      final remaining = result.remaining ?? 0;
      final points = result.senderPointsAwarded ?? 0;
      final pointsLine =
          points > 0 ? '+$points Auro for sending Namaste!\n\n' : '';
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Namaste Sent! \u{1F64F}'),
          content: Text(
              '${pointsLine}Your greeting has been delivered.\n${remaining > 0 ? "$remaining namaste${remaining == 1 ? '' : 's'} remaining today." : "You've used all namastes for today."}'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else if (result.quotaExceeded) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Daily Limit Reached'),
          content: Text(
              'You\'ve sent all 3 namastes for today.\nCome back tomorrow to greet more people! \u{1F64F}'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else if (result.alreadySentToday) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Already Greeted'),
          content: Text('You\'ve already sent namaste to this person today.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else if (result.blocked) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Cannot Send'),
          content: Text('Unable to send namaste to this user.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else {
      AppLogger.e('Error sending namaste: ${result.error}',
          category: LogCategory.general);
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Error'),
          content: Text('Failed to send namaste. Please try again.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> openDirectMessage() async {
    if (interactionCurrentUser == null || interactionTargetUid == null) {
      showLoginBottomSheet(context);
      return;
    }

    try {
      final chatService = SpaceChatService();
      final conversationId =
          await chatService.createDirectMessage(interactionTargetUid!);

      if (mounted) {
        final name = interactionCachedProfileData?['name'] ?? 'User';
        Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(
            builder: (context) => SpaceChatScreen(
              spaceId: conversationId,
              space: Space(
                id: conversationId,
                name: name,
                searchName: 'dm_$interactionTargetUid',
                description: 'Direct message conversation',
                spaceType: SpaceType.private,
                limitedVisibility: false,
              ),
              otherUserId: interactionTargetUid,
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.e('Error opening DM', category: LogCategory.general, error: e);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Error'),
            content: Text('Failed to open conversation. Please try again.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void toggleBlockUser() {
    if (interactionIsUserBlocked) {
      unblockUser();
    } else {
      blockUser();
    }
  }

  Future<void> blockUser() async {
    if (interactionTargetUid == null) return;

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Block User'),
        content: Text('Are you sure you want to block this user?'),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text('Block'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final userService = UserService();
        await userService.blockUser(interactionTargetUid!);

        if (mounted) {
          setState(() => interactionIsUserBlocked = true);
        }
      } catch (e) {
        AppLogger.e('Error blocking user',
            category: LogCategory.general, error: e);
      }
    }
  }

  Future<void> unblockUser() async {
    if (interactionTargetUid == null) return;

    try {
      final userService = UserService();
      await userService.unblockUser(interactionTargetUid!);

      if (mounted) {
        setState(() => interactionIsUserBlocked = false);
      }
    } catch (e) {
      AppLogger.e('Error unblocking user',
          category: LogCategory.general, error: e);
    }
  }
}
