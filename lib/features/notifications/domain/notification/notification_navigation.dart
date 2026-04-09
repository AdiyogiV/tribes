import 'package:aurogram/shared/models/notification.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/chat/domain/chat_notification_service.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/core/routing/page_factory.dart';

import '../notification_service.dart';

/// Deep-link navigation and tap routing for all notification types.
extension NotificationNavigation on NotificationService {
  /// Navigate based on notification type.
  void navigateForNotification(AppNotification notification) {
    switch (notification.type) {
      case NotificationType.chat:
      case NotificationType.message:
        if (notification.spaceId != null) {
          navigateToChatWithRetry(notification.spaceId!);
        }
        break;
      case NotificationType.dailyAstroInsight:
        navigateToDailyInsight(
          cardIndex: notification.cardIndex,
          insightDate: notification.insightId ?? notification.date,
        );
        break;
      case NotificationType.reply:
      case NotificationType.like:
      case NotificationType.newSpacePost:
        if (notification.spaceId != null) {
          navigateToPost(notification.spaceId!, notification.postId);
        }
        break;
      case NotificationType.namaste:
        if (notification.authorId != null) {
          navigateToProfile(notification.authorId!);
        }
        break;
      case NotificationType.invite:
        navigateToInvites();
        break;
      case NotificationType.request:
        if (notification.spaceId != null) {
          navigateToRequests(notification.spaceId!);
        }
        break;
      case NotificationType.addedToGroup:
        if (notification.spaceId != null) {
          navigateToSpace(notification.spaceId!);
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
          navigateToProfile(userId);
        }
        break;
      case NotificationType.followRequest:
        // Navigate to the requestor's profile
        final requestorId = notification.authorId ??
            notification.data['fromUserId'] as String? ??
            notification.data['authorId'] as String?;
        if (requestorId != null) {
          navigateToProfile(requestorId);
        }
        break;
      case NotificationType.anonymousMessage:
        navigateToSecretMessagesInbox();
        break;
      default:
        break;
    }
  }

  // ── Individual navigation helpers ─────────────────────────────────────────

  void navigateToSecretMessagesInbox() {
    if (navigatorKey?.currentState == null) return;
    navigatorKey!.currentState!.push(
      PageFactory.route(RouteNames.secretMessagesInbox),
    );
  }

  void navigateToChatWithRetry(String spaceId, {int attempt = 0}) {
    if (navigatorKey?.currentState == null) {
      if (attempt < 10) {
        Future.delayed(Duration(milliseconds: 500 * (attempt + 1)), () {
          navigateToChatWithRetry(spaceId, attempt: attempt + 1);
        });
      }
      return;
    }

    final chatService = ChatNotificationService();
    chatService.setNavigatorKey(navigatorKey!);

    navigatorKey!.currentState!.push(
      PageFactory.route(RouteNames.spaceChatScreen, arguments: {
        'spaceId': spaceId,
        'space': null,
        'otherUserId': spaceId.startsWith('dm_')
            ? spaceId
                .split('_')
                .where((id) => id != currentUser?.uid)
                .firstOrNull
            : null,
      }),
    );
  }

  void navigateToDailyInsight({
    int attempt = 0,
    int? cardIndex,
    String? insightDate,
  }) {
    final userId = currentUser?.uid;
    if (userId == null) return;

    if (navigatorKey?.currentState == null) {
      if (attempt < 5) {
        Future.delayed(Duration(milliseconds: 500 * (attempt + 1)), () {
          navigateToDailyInsight(
            attempt: attempt + 1,
            cardIndex: cardIndex,
            insightDate: insightDate,
          );
        });
      }
      return;
    }

    navigatorKey!.currentState!.push(
      PageFactory.route(RouteNames.dailyInsight, arguments: {
        'uid': userId,
        'cardIndex': cardIndex,
        'insightDate': insightDate,
      }),
    );
  }

  void navigateToPost(String spaceId, String? postId) {
    if (navigatorKey?.currentState == null) return;
    if (postId != null && postId.isNotEmpty) {
      navigatorKey!.currentState!.push(
        PageFactory.route(RouteNames.threadView, arguments: {
          'postId': postId,
        }),
      );
    } else {
      navigatorKey!.currentState!.push(
        PageFactory.route(RouteNames.spaceScreen, arguments: {
          'rid': spaceId,
        }),
      );
    }
  }

  void navigateToProfile(String userId) {
    if (navigatorKey?.currentState == null) return;

    navigatorKey!.currentState!.push(
      PageFactory.route(RouteNames.userProfile, arguments: {
        'uid': userId,
      }),
    );
  }

  void navigateToSpace(String spaceId) {
    if (navigatorKey?.currentState == null) return;

    navigatorKey!.currentState!.push(
      PageFactory.route(RouteNames.spaceScreen, arguments: {
        'rid': spaceId,
      }),
    );
  }

  void navigateToInvites() {
    if (navigatorKey?.currentState == null) return;

    navigatorKey!.currentState!.push(
      PageFactory.route(RouteNames.invites),
    );
  }

  void navigateToRequests(String spaceId) {
    if (navigatorKey?.currentState == null) return;

    navigatorKey!.currentState!.push(
      PageFactory.route(RouteNames.requests),
    );
  }

  /// Navigate to group call screen with retry for app startup timing.
  void navigateToGroupCall(String spaceId, String spaceName,
      {int retryCount = 0}) {
    if (navigatorKey?.currentState == null) {
      if (retryCount < 15) {
        AppLogger.d(
            'Navigator not ready for group call, retrying... (attempt ${retryCount + 1})',
            category: LogCategory.general);
        Future.delayed(Duration(milliseconds: 500 + (retryCount * 200)), () {
          navigateToGroupCall(spaceId, spaceName, retryCount: retryCount + 1);
        });
        return;
      }
      AppLogger.e(
          'Cannot navigate to group call - navigator not ready after retries',
          category: LogCategory.general);
      return;
    }

    navigatorKey!.currentState!.push(
      PageFactory.route(RouteNames.groupCall, arguments: {
        'spaceId': spaceId,
        'spaceName': spaceName,
      }),
    );
  }
}
