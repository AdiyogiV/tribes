import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/models/space_types.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/pages/spaces/space_chat_screen.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/widgets/dialogs/login_bottom_sheet.dart';

/// Opens a DM conversation in the appropriate layout (mobile push or desktop inline).
Future<void> openConversation({
  required BuildContext context,
  required DmConversation conversation,
  required void Function(String id, Space space, String? otherUserId)
      onDesktopSelect,
}) async {
  final isDM = conversation.id.startsWith('dm_');
  final isGroupSpace = conversation.participants.length > 2;

  String displayName = conversation.spaceName ?? conversation.otherUserId;
  String? otherUserId;

  if (isDM) {
    otherUserId = conversation.otherUserId;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(conversation.otherUserId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          displayName = userData['name'] as String? ??
              userData['nickname'] as String? ??
              conversation.otherUserId;
        }
      }
    } catch (e) {
      AppLogger.w('Error fetching user name for conversation',
          category: LogCategory.ui, data: {'error': e.toString()});
    }
  }

  if (!context.mounted) return;

  final space = Space(
    id: conversation.id,
    name: displayName,
    searchName: isDM ? 'dm_${conversation.otherUserId}' : conversation.id,
    description: isDM
        ? 'Direct message conversation'
        : isGroupSpace
            ? 'Gram conversation'
            : 'Private conversation',
    spaceType: SpaceType.private,
    limitedVisibility: false,
  );

  if (Responsive.isWideLayout(context)) {
    onDesktopSelect(conversation.id, space, otherUserId);
  } else {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => SpaceChatScreen(
          spaceId: conversation.id,
          space: space,
          otherUserId: otherUserId,
        ),
      ),
    );
  }
}

/// Opens a user's profile page.
void openProfile(BuildContext context, String userId) {
  Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute(
      builder: (context) => UserProfilePage(uid: userId),
    ),
  );
}

/// Starts a new conversation with a user (or opens existing one).
Future<void> startConversationWithUser({
  required BuildContext context,
  required String userId,
  required String userName,
  required String? currentUserId,
  required SpaceChatService chatService,
  required TextEditingController searchController,
  required FocusNode searchFocusNode,
  required void Function(String query) onSearchChanged,
  required void Function(String id, Space space, String? otherUserId)
      onDesktopSelect,
}) async {
  if (currentUserId == null) {
    showLoginBottomSheet(context);
    return;
  }

  try {
    // Fetch actual user data to get the correct name
    String actualUserName = userName;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          actualUserName = userData['name'] as String? ??
              userData['nickname'] as String? ??
              userName;
        }
      }
    } catch (e) {
      AppLogger.w('Error fetching user data, using provided name',
          category: LogCategory.ui, data: {'error': e.toString()});
    }

    // Create or get existing conversation
    final conversationId = await chatService.createDirectMessage(userId);

    if (!context.mounted) return;

    // Clear search
    searchController.clear();
    onSearchChanged('');
    searchFocusNode.unfocus();

    final space = Space(
      id: conversationId,
      name: actualUserName,
      searchName: 'dm_$userId',
      description: 'Direct message conversation',
      spaceType: SpaceType.private,
      limitedVisibility: false,
    );

    if (Responsive.isWideLayout(context)) {
      onDesktopSelect(conversationId, space, userId);
    } else {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => SpaceChatScreen(
            spaceId: conversationId,
            space: space,
            otherUserId: userId,
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Error'),
          content: Text('Failed to create conversation: $e'),
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
