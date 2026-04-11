import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/shared/services/database_service.dart';
import 'package:aurogram/shared/utils/time_display.dart';

/// Mixin that provides common data-fetching logic shared across all notification tiles.
///
/// Eliminates duplicate user/space/timestamp fetching code that was previously
/// copy-pasted into 15+ tile widgets (reply_tile, like_tile, chat_message_tile, etc.)
///
/// Usage:
/// ```dart
/// class _MyTileState extends State<MyTile> with NotificationDataMixin {
///   @override
///   void initState() {
///     super.initState();
///     _loadData();
///   }
///
///   Future<void> _loadData() async {
///     final userId = widget.data?['author'] as String? ?? '';
///     authorName = await fetchUserDisplayName(userId, widget.data);
///     authorAvatar = await fetchUserAvatar(userId);
///     timestamp = parseNotificationTimestamp(widget.data);
///     if (mounted) setState(() => isDataReady = true);
///   }
/// }
/// ```
mixin NotificationDataMixin<T extends StatefulWidget> on State<T> {
  /// Whether the async data has been loaded and the tile is ready to render.
  bool isDataReady = false;

  // ---------------------------------------------------------------------------
  // USER DATA FETCHING
  // ---------------------------------------------------------------------------

  /// Fetch a user's display name with notification-data fast path.
  ///
  /// 1. Checks [notificationData] for pre-stored name fields (faster, no Firestore read).
  /// 2. Falls back to [UserService.getUserDisplayName] if missing or generic.
  /// 3. Returns `'Someone'` as last resort.
  Future<String> fetchUserDisplayName(
    String userId,
    Map<String, dynamic>? notificationData,
  ) async {
    try {
      // Fast path: name embedded in notification
      final storedName = notificationData?['authorName'] ??
          notificationData?['senderName'] ??
          notificationData?['likerName'];
      if (storedName is String && storedName.isNotEmpty && storedName != 'Someone') {
        return storedName;
      }

      if (userId.isEmpty) return 'Someone';

      final userService = locator<UserService>();
      final name = await userService
          .getUserDisplayName(userId)
          .timeout(const Duration(seconds: 5));
      return (name != null && name.isNotEmpty) ? name : 'Someone';
    } catch (e) {
      AppLogger.w('NotificationDataMixin: failed to fetch display name for $userId',
          category: LogCategory.general);
      return 'Someone';
    }
  }

  /// Fetch a user's avatar URL.
  ///
  /// Returns `null` if the user document is missing or has no avatar.
  Future<String?> fetchUserAvatar(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final userDoc = await locator<UserRepository>()
          .getUser(userId)
          .timeout(const Duration(seconds: 5));
      if (userDoc == null || !userDoc.exists) return null;
      final data = userDoc.data() as Map<String, dynamic>?;
      return data?['displayPicture'] as String?;
    } catch (e) {
      AppLogger.w('NotificationDataMixin: failed to fetch avatar for $userId',
          category: LogCategory.general);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // SPACE / GRAM DATA FETCHING
  // ---------------------------------------------------------------------------

  /// Fetch a space/gram name by ID.
  ///
  /// Falls back to [fallbackName] (or `'A Space'`) if the document doesn't exist.
  Future<String> fetchSpaceName(String? spaceId, {String? fallbackName}) async {
    final fallback = fallbackName ?? 'A Space';
    if (spaceId == null || spaceId.isEmpty) return fallback;
    try {
      final spaceDoc = await DatabaseService()
          .getSpace(spaceId)
          .timeout(const Duration(seconds: 5));
      if (spaceDoc == null || !spaceDoc.exists) return fallback;
      final data = spaceDoc.data() as Map<String, dynamic>?;
      return data?['name'] as String? ?? fallback;
    } catch (e) {
      AppLogger.w('NotificationDataMixin: failed to fetch space $spaceId',
          category: LogCategory.general);
      return fallback;
    }
  }

  // ---------------------------------------------------------------------------
  // TIMESTAMP PARSING
  // ---------------------------------------------------------------------------

  /// Parse and format a notification timestamp into a compact display string (e.g. "5m", "2h").
  ///
  /// Handles both [Timestamp] and [DateTime] values stored in notification data.
  /// Returns `'Recently'` if parsing fails.
  String parseNotificationTimestamp(Map<String, dynamic>? data) {
    try {
      final raw = data?['timestamp'];
      if (raw == null) return 'Recently';

      DateTime dateTime;
      if (raw is Timestamp) {
        dateTime = raw.toDate();
      } else if (raw is DateTime) {
        dateTime = raw;
      } else {
        return 'Recently';
      }

      return TimeDisplay.getCompactTimestamp(dateTime);
    } catch (_) {
      return 'Recently';
    }
  }
}
