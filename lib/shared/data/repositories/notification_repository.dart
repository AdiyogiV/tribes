import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/models/notification.dart';

/// Repository for notification data access.
///
/// Wraps the Firestore subcollection `notifications/{uid}/notifications`
/// and provides paginated queries, mark-as-read, and unread-count streaming.
/// Presentation layer should use this instead of accessing Firestore directly.
class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Default page size for paginated queries.
  static const int defaultPageSize = 20;

  /// Last successfully fetched unread count — returned on fetch errors
  /// instead of a misleading zero.
  int _lastKnownUnreadCount = 0;

  /// Reference to a user's notification subcollection.
  CollectionReference<Map<String, dynamic>> _userNotifications(String uid) =>
      _firestore
          .collection('notifications')
          .doc(uid)
          .collection('notifications');

  // ── Paginated queries ─────────────────────────────────────────────

  /// Fetch a page of notifications for [uid], ordered newest-first.
  ///
  /// Pass [startAfter] from a previous call to paginate.
  /// Set [unreadOnly] to true to filter to unread notifications only.
  /// Returns a [NotificationPage] with the documents and pagination info.
  Future<NotificationPage> getNotifications(
    String uid, {
    int pageSize = defaultPageSize,
    DocumentSnapshot? startAfter,
    bool unreadOnly = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _userNotifications(uid)
          .orderBy('timestamp', descending: true)
          .limit(pageSize);

      if (unreadOnly) {
        query = query.where('read', isEqualTo: false);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      final notifications = snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();

      return NotificationPage(
        notifications: notifications,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length >= pageSize,
      );
    } catch (e, stack) {
      AppLogger.e('NotificationRepository: error fetching notifications',
          category: LogCategory.general, error: e, stackTrace: stack);
      rethrow;
    }
  }

  // ── Streams ───────────────────────────────────────────────────────

  /// Stream the unread notification count for [uid].
  ///
  /// Uses Firestore count() aggregation to avoid downloading full documents.
  /// Emits immediately, then refreshes every 30 seconds.
  Stream<int> unreadCountStream(String uid) async* {
    // Emit initial count immediately
    yield await _fetchUnreadCount(uid);

    // Then poll every 30 seconds (count() doesn't support real-time snapshots)
    yield* Stream.periodic(const Duration(seconds: 30))
        .asyncMap((_) => _fetchUnreadCount(uid));
  }

  /// Fetch unread count using Firestore count() aggregation.
  ///
  /// On failure, returns the last successfully fetched count rather than
  /// a misleading zero (avoids the badge disappearing on network errors).
  Future<int> _fetchUnreadCount(String uid) async {
    try {
      final countQuery = _userNotifications(uid)
          .where('read', isEqualTo: false)
          .count();
      final snapshot = await countQuery.get();
      _lastKnownUnreadCount = snapshot.count ?? 0;
      return _lastKnownUnreadCount;
    } catch (e) {
      AppLogger.w('NotificationRepository: count aggregation failed, using last known count',
          category: LogCategory.general,
          data: {'lastKnown': _lastKnownUnreadCount, 'error': e.toString()});
      return _lastKnownUnreadCount;
    }
  }

  // ── Writes ────────────────────────────────────────────────────────

  /// Mark a single notification as read.
  Future<void> markAsRead(String uid, String notificationId) async {
    try {
      await _userNotifications(uid).doc(notificationId).update({'read': true});
    } catch (e) {
      AppLogger.w('NotificationRepository: failed to mark as read',
          category: LogCategory.general,
          data: {'uid': uid, 'notificationId': notificationId, 'error': e.toString()});
    }
  }

  /// Mark all notifications as read for [uid].
  ///
  /// Processes in chunks of 500 to respect Firestore's WriteBatch limit.
  Future<void> markAllAsRead(String uid) async {
    try {
      final unread = await _userNotifications(uid)
          .where('read', isEqualTo: false)
          .get();

      if (unread.docs.isEmpty) return;

      // Firestore WriteBatch has a 500-operation limit — chunk accordingly.
      const batchLimit = 500;
      for (var i = 0; i < unread.docs.length; i += batchLimit) {
        final batch = _firestore.batch();
        final chunk = unread.docs.skip(i).take(batchLimit);
        for (final doc in chunk) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
      }
    } catch (e) {
      AppLogger.w('NotificationRepository: failed to mark all as read',
          category: LogCategory.general,
          data: {'uid': uid, 'error': e.toString()});
    }
  }
}

/// A page of notification results with pagination cursor.
class NotificationPage {
  const NotificationPage({
    required this.notifications,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<AppNotification> notifications;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
}
