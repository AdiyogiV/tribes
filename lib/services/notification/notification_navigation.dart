part of '../notification_service.dart';

/// Deep-link navigation and tap routing for all notification types.
extension _NotificationNavigation on NotificationService {
  /// Navigate based on notification type.
  void _navigateForNotification(AppNotification notification) {
    switch (notification.type) {
      case NotificationType.chat:
      case NotificationType.message:
        if (notification.spaceId != null) {
          _navigateToChatWithRetry(notification.spaceId!);
        }
        break;
      case NotificationType.dailyAstroInsight:
        _navigateToDailyInsight(
          cardIndex: notification.cardIndex,
          insightDate: notification.insightId ?? notification.date,
        );
        break;
      case NotificationType.reply:
      case NotificationType.like:
      case NotificationType.newSpacePost:
        if (notification.spaceId != null) {
          _navigateToPost(notification.spaceId!, notification.postId);
        }
        break;
      case NotificationType.namaste:
        if (notification.authorId != null) {
          _navigateToProfile(notification.authorId!);
        }
        break;
      case NotificationType.invite:
        _navigateToInvites();
        break;
      case NotificationType.request:
        if (notification.spaceId != null) {
          _navigateToRequests(notification.spaceId!);
        }
        break;
      case NotificationType.addedToGroup:
        if (notification.spaceId != null) {
          _navigateToSpace(notification.spaceId!);
        }
        break;
      case NotificationType.follow:
      case NotificationType.followAccepted:
      case NotificationType.mutualFollow:
        // Navigate to the profile of the user who followed/is now friends
        final userId = notification.authorId ??
            notification.data['fromUserId'] as String? ??
            notification.data['authorId'] as String?;
        if (userId != null) {
          _navigateToProfile(userId);
        }
        break;
      case NotificationType.followRequest:
        // Navigate to the requestor's profile
        final requestorId = notification.authorId ??
            notification.data['fromUserId'] as String? ??
            notification.data['authorId'] as String?;
        if (requestorId != null) {
          _navigateToProfile(requestorId);
        }
        break;
      case NotificationType.anonymousMessage:
        _navigateToSecretMessagesInbox();
        break;
      default:
        break;
    }
  }

  // ── Individual navigation helpers ─────────────────────────────────────────

  void _navigateToSecretMessagesInbox() {
    if (_navigatorKey?.currentState == null) return;
    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (context) => const SecretMessagesInboxScreen(),
      ),
    );
  }

  void _navigateToChatWithRetry(String spaceId, {int attempt = 0}) {
    if (_navigatorKey?.currentState == null) {
      if (attempt < 10) {
        Future.delayed(Duration(milliseconds: 500 * (attempt + 1)), () {
          _navigateToChatWithRetry(spaceId, attempt: attempt + 1);
        });
      }
      return;
    }

    final chatService = ChatNotificationService();
    chatService.setNavigatorKey(_navigatorKey!);

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (context) => SpaceChatScreen(
          spaceId: spaceId,
          space: null,
          otherUserId: spaceId.startsWith('dm_')
              ? spaceId
                  .split('_')
                  .where((id) => id != _currentUser?.uid)
                  .firstOrNull
              : null,
        ),
      ),
    );
  }

  void _navigateToDailyInsight({
    int attempt = 0,
    int? cardIndex,
    String? insightDate,
  }) {
    final userId = _currentUser?.uid;
    if (userId == null) return;

    if (_navigatorKey?.currentState == null) {
      if (attempt < 5) {
        Future.delayed(Duration(milliseconds: 500 * (attempt + 1)), () {
          _navigateToDailyInsight(
            attempt: attempt + 1,
            cardIndex: cardIndex,
            insightDate: insightDate,
          );
        });
      }
      return;
    }

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (_) => DailyInsightPage(
          uid: userId,
          highlightCardIndex: cardIndex,
          insightDate: insightDate,
        ),
      ),
    );
  }

  void _navigateToPost(String spaceId, String? postId) {
    if (_navigatorKey?.currentState == null) return;
    if (postId != null && postId.isNotEmpty) {
      _navigatorKey!.currentState!.push(
        MaterialPageRoute(
          builder: (_) => ThreadView(postId: postId),
        ),
      );
    } else {
      _navigatorKey!.currentState!.push(
        MaterialPageRoute(
          builder: (_) => SpaceScreen(rid: spaceId),
        ),
      );
    }
  }

  void _navigateToProfile(String userId) {
    if (_navigatorKey?.currentState == null) return;

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(uid: userId),
      ),
    );
  }

  void _navigateToSpace(String spaceId) {
    if (_navigatorKey?.currentState == null) return;

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (_) => SpaceScreen(rid: spaceId),
      ),
    );
  }

  void _navigateToInvites() {
    if (_navigatorKey?.currentState == null) return;

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(builder: (_) => const Invites()),
    );
  }

  void _navigateToRequests(String spaceId) {
    if (_navigatorKey?.currentState == null) return;

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(builder: (_) => const Requests()),
    );
  }

  /// Navigate to group call screen with retry for app startup timing.
  void _navigateToGroupCall(String spaceId, String spaceName,
      {int retryCount = 0}) {
    if (_navigatorKey?.currentState == null) {
      if (retryCount < 15) {
        AppLogger.d(
            'Navigator not ready for group call, retrying... (attempt ${retryCount + 1})',
            category: LogCategory.general);
        Future.delayed(Duration(milliseconds: 500 + (retryCount * 200)), () {
          _navigateToGroupCall(spaceId, spaceName, retryCount: retryCount + 1);
        });
        return;
      }
      AppLogger.e(
          'Cannot navigate to group call - navigator not ready after retries',
          category: LogCategory.general);
      return;
    }

    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (_) => GroupCallScreen(
          spaceId: spaceId,
          spaceName: spaceName,
        ),
      ),
    );
  }
}
