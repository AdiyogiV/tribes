import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/shared/models/space_types.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/core/config/call_ui_config.dart';
import 'package:aurogram/features/calling/domain/group_call_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// In-process cache of "is there an active call?" state per space.
///
/// Used by [GramPreviewActions.buildCallButton] to avoid opening a Firestore
/// snapshots() listener on every gram preview tile (which used to add ~1
/// listener per gram on screen, killing performance and battery).
class _ActiveCallCache {
  _ActiveCallCache._();
  static const Duration _ttl = Duration(seconds: 30);
  static final Map<String, _ActiveCallEntry> _entries = {};

  static _ActiveCallEntry get(String spaceId) =>
      _entries.putIfAbsent(spaceId, () => _ActiveCallEntry(spaceId));
}

class _ActiveCallEntry {
  _ActiveCallEntry(this.spaceId);
  final String spaceId;
  final ValueNotifier<_CallStatus> notifier =
      ValueNotifier(const _CallStatus(false, 0));
  DateTime? _lastFetch;
  Future<void>? _inflight;

  bool get _isStale =>
      _lastFetch == null ||
      DateTime.now().difference(_lastFetch!) > _ActiveCallCache._ttl;

  Future<void> refreshIfStale() {
    if (!_isStale) return Future.value();
    return _inflight ??= _fetch().whenComplete(() => _inflight = null);
  }

  Future<void> _fetch() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('calls')
          .doc('active')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
      _lastFetch = DateTime.now();
      if (!doc.exists) {
        notifier.value = const _CallStatus(false, 0);
        return;
      }
      final data = doc.data();
      final participants = (data?['participants'] as List<dynamic>?) ?? const [];
      notifier.value = _CallStatus(participants.isNotEmpty, participants.length);
    } catch (_) {
      // Keep last known value on transient errors.
      _lastFetch = DateTime.now();
    }
  }
}

class _CallStatus {
  const _CallStatus(this.hasActiveCall, this.participantCount);
  final bool hasActiveCall;
  final int participantCount;
}

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
  /// Works on all platforms (Agora SDK 6.x supports web).
  ///
  /// Uses an in-memory cache + 30s polling instead of a per-widget Firestore
  /// snapshots() listener, since rendering N preview tiles used to spawn N
  /// concurrent listeners.
  static Widget buildCallButton(
      BuildContext context, String spaceId, String spaceName) {
    if (spaceId.isEmpty) return const SizedBox.shrink();
    final entry = _ActiveCallCache.get(spaceId);
    // Fire-and-forget refresh; cache de-dupes inflight requests.
    unawaited(entry.refreshIfStale());

    return ValueListenableBuilder<_CallStatus>(
      valueListenable: entry.notifier,
      builder: (context, status, _) {
        final iconColor =
            status.hasActiveCall ? AppTheme.activeGreen : AppTheme.primaryColor;
        final callButton = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openCall(context, spaceId, spaceName),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            decoration: status.hasActiveCall
                ? BoxDecoration(
                    color: AppTheme.activeGreen.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status.hasActiveCall
                      ? CallUIConfig.callActiveIcon
                      : CallUIConfig.callIcon,
                  size: 20,
                  color: iconColor,
                ),
                if (status.hasActiveCall) ...[
                  const SizedBox(width: AppDimensions.spacingXs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.activeGreen,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMdSm),
                    ),
                    child: Text(
                      '${status.participantCount}',
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
          message: status.hasActiveCall
              ? 'Join call (${status.participantCount})'
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

    context.push('/call/group/$spaceId', extra: {'spaceName': spaceName});
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

    context.push('/space/chat/$spaceId', extra: {'space': space});
  }
}
