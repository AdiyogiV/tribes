import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/shared/models/space_types.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/spaces/presentation/pages/space_chat_screen.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/core/config/call_ui_config.dart';
import 'package:aurogram/features/calling/presentation/pages/group_call_screen.dart';
import 'package:aurogram/features/calling/domain/group_call_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Action widgets (call button, chat/lock icons) for GramPreviewBox.
/// These are extracted as standalone widget-builder functions.
class GramPreviewActions {
  GramPreviewActions._();

  /// Build lock icon (for private spaces) and chat button
  /// Call button is shown separately so it's always visible
  static Widget buildChatAndLockIcons(
    BuildContext context,
    Map<String, dynamic> spaceData,
    SpaceType? type,
    SpaceChatService chatService,
  ) {
    // Show lock for private spaces (type 2) or if limitedVisibility is true
    final limitedVisibility = spaceData['limitedVisibility'] as bool? ?? false;
    final isPrivate = (type != null && isPrivateSpaceType(type)) || limitedVisibility;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lock icon for private spaces
        if (isPrivate)
          Padding(
            padding: const EdgeInsets.only(right: 2.0),
            child: Opacity(
              opacity: 0.9,
              child: Image.asset(
                'assets/images/lock.png',
                width: 28,
                height: 28,
              ),
            ),
          ),
        // Paper plane icon (chat)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openChat(context, spaceData, chatService),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
            child: Icon(
              CupertinoIcons.paperplane_fill,
              size: 24,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  /// Build a call button that turns green when there's an active call
  /// Works on all platforms (Agora SDK 6.x supports web)
  static Widget buildCallButton(BuildContext context, String spaceId, String spaceName) {
    if (spaceId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('calls')
          .doc('active')
          .snapshots(),
      builder: (context, snapshot) {
        bool hasActiveCall = false;
        int participantCount = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final participants = data?['participants'] as List<dynamic>? ?? [];
          hasActiveCall = participants.isNotEmpty;
          participantCount = participants.length;
        }

        final iconColor = hasActiveCall
            ? AppTheme.activeGreen
            : AppTheme.primaryColor;

        final callButton = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openCall(context, spaceId, spaceName),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            decoration: hasActiveCall
                ? BoxDecoration(
                    color: AppTheme.activeGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasActiveCall ? CallUIConfig.callActiveIcon : CallUIConfig.callIcon,
                  size: 20,
                  color: iconColor,
                ),
                if (hasActiveCall) ...[
                  const SizedBox(width: AppDimensions.spacingXs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.activeGreen,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                    ),
                    child: Text(
                      '$participantCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

        return Tooltip(
          message: hasActiveCall
              ? 'Join call ($participantCount)'
              : 'Start call',
          child: callButton,
        );
      },
    );
  }

  static void _openCall(BuildContext context, String spaceId, String spaceName) {
    if (spaceId.isEmpty) return;

    final groupCallService = GroupCallService();
    if (groupCallService.isInCall && groupCallService.activeSpaceId != spaceId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: AppDimensions.spacingMd),
              Text('Already in another call'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupCallScreen(
          spaceId: spaceId,
          spaceName: spaceName,
        ),
      ),
    );
  }

  static void _openChat(BuildContext context, Map<String, dynamic> spaceData, SpaceChatService chatService) {
    final String? spaceId = spaceData['id'] as String?;
    if (spaceId == null || spaceId.isEmpty) return;

    // Mark all messages as read when opening chat
    chatService.markAllMessagesAsRead(spaceId);

    Space space;
    final dynamic obj = spaceData['spaceObject'];
    if (obj is Space) {
      space = obj;
    } else {
      final String name = (spaceData['name'] as String?) ?? '';
      final SpaceType spaceType =
          spaceData['spaceType'] as SpaceType? ?? SpaceType.public;
      space = Space(
        id: spaceId,
        name: name,
        searchName: name.toLowerCase(),
        spaceType: spaceType,
        description: spaceData['description'] as String?,
        displayPicture: spaceData['displayPicture'] as String?,
      );
    }

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => SpaceChatScreen(
          spaceId: spaceId,
          space: space,
        ),
      ),
    );
  }
}
