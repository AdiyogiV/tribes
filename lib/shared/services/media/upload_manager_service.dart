import 'package:aurogram/shared/services/media/media_compression_service.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/features/creation/pages/uploads_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// A service to manage upload navigation and status tracking
class UploadManagerService {
  final MediaCompressionService _mediaCompressionService =
      MediaCompressionService();

  // Notification plugin for background notifications
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  /// Singleton instance
  static final UploadManagerService _instance =
      UploadManagerService._internal();

  /// Factory constructor
  factory UploadManagerService() {
    return _instance;
  }

  /// Private constructor
  UploadManagerService._internal() {
    _initializeNotifications();
  }

  /// Track whether uploads page is currently showing
  bool _isUploadsPageShowing = false;

  /// Stream subscription to listen for completed uploads (EVENT-DRIVEN)
  StreamSubscription? _completionSubscription;

  /// Track uploads that need notifications
  final Map<String, Map<String, dynamic>> _pendingNotifications = {};

  /// Initialize the notification plugin
  Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    _notificationsInitialized = true;
  }

  void _handleNotificationTap(NotificationResponse response) {
    // Handle notification tap - extract data from payload
    if (response.payload != null) {
      final parts = response.payload!.split('|');
      if (parts.length >= 2) {
        // final spaceId = parts[0];
        // final postId = parts[1];

        // Navigate to post - this will be handled by the app when it's opened
        // The app will need to check for this payload on startup
      }
    }
  }

  /// Start background monitoring for completed uploads (EVENT-DRIVEN)
  void startBackgroundMonitoring(BuildContext context) {
    // Cancel existing subscription if any
    _completionSubscription?.cancel();

    // TRULY EVENT-DRIVEN: Listen to completion events for instant notifications
    _completionSubscription =
        _mediaCompressionService.completionStream.listen((event) {
      if (event.success &&
          !_pendingNotifications.containsKey(event.postId) &&
          !_isUploadsPageShowing) {
        _showCompletionNotification(
          event.postId,
          event.uploadData?['title'] ?? 'Video',
          event.uploadData?['space'],
        );

        // Track this notification to avoid duplicates
        _pendingNotifications[event.postId] = event.uploadData ?? {};
      }
    });
  }

  /// Stop background monitoring
  void stopBackgroundMonitoring() {
    _completionSubscription?.cancel();
    _completionSubscription = null;
  }

  /// Show a notification for a completed upload
  Future<void> _showCompletionNotification(
    String postId,
    String title,
    String? spaceId,
  ) async {
    if (!_notificationsInitialized) await _initializeNotifications();

    final spaceName = spaceId != null ? await _fetchSpaceName(spaceId) : null;
    final notificationTitle = 'Upload Complete';
    final notificationBody = spaceName != null
        ? '"$title" has been uploaded to $spaceName'
        : '"$title" has been uploaded successfully';

    final androidDetails = AndroidNotificationDetails(
      'upload_complete_channel',
      'Upload Notifications',
      channelDescription: 'Notifications for completed uploads',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Payload format: spaceId|postId
    final payload = spaceId != null ? '$spaceId|$postId' : '|$postId';

    await _notificationsPlugin.show(
      postId.hashCode, // Use hashcode of postId as notification id
      notificationTitle,
      notificationBody,
      details,
      payload: payload,
    );
  }

  /// Fetch a space name from Firestore
  Future<String?> _fetchSpaceName(String spaceId) async {
    try {
      final spaceDoc = await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .get();

      if (spaceDoc.exists && spaceDoc.data() != null) {
        final spaceName = spaceDoc.data()?['name'] as String?;
        if (spaceName != null) {
          return spaceName;
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      return null;
    }
  }

  /// Check for active uploads
  Future<bool> hasActiveUploads() async {
    final uploads = await _mediaCompressionService.getUploadProgress();

    return uploads.any((item) =>
        item['status'] != 'completed' &&
        item['status'] != 'failed' &&
        item['status'] != 'cancelled');
  }

  /// Get count of active uploads
  Future<int> getActiveUploadCount() async {
    final uploads = await _mediaCompressionService.getUploadProgress();

    return uploads
        .where((item) =>
            item['status'] != 'completed' &&
            item['status'] != 'failed' &&
            item['status'] != 'cancelled')
        .length;
  }

  /// Show uploads page if there are active uploads and set up callbacks
  Future<bool> showUploadsPageIfNeeded(
    BuildContext context, {
    String? navigateToSpaceId,
    String? navigateToPostId,
    bool shouldReplace = false,
    VoidCallback? onComplete,
  }) async {
    if (await hasActiveUploads()) {
      if (!_isUploadsPageShowing) {
        _isUploadsPageShowing = true;

        if (!context.mounted) return false;
        // Get the navigator context cautiously
        final navigator = Navigator.of(context, rootNavigator: true);

        try {
          // When showing uploads page, we use push instead of pushReplacement
          // to preserve the back stack for replies from feed
          await navigator.push(
            MaterialPageRoute(
              builder: (context) => UploadsPage(
                onAllComplete: () {
                  // Check if navigator is still available before proceeding
                  if (navigator.mounted) {
                    navigator.pop(); // Close uploads page

                    // Don't navigate anywhere after upload completion
                    // This is intentionally disabled to prevent automatic navigation
                    if (kDebugMode) {
                      AppLogger.i('', category: LogCategory.general);
                    }
                  }

                  // Call the completion callback if provided
                  onComplete?.call();
                },
              ),
            ),
          );
        } catch (e) {
          // Handle navigator errors gracefully
          if (kDebugMode) {
            AppLogger.d('', category: LogCategory.general);
          }
        } finally {
          _isUploadsPageShowing = false;
        }
        return true;
      }
      return true; // Return true even if uploads page is already showing
    } else if (navigateToSpaceId != null) {
      // If no active uploads but we have a destination, don't navigate directly either
      if (kDebugMode) {
        AppLogger.d('', category: LogCategory.general);
      }
      return true;
    }
    return false;
  }

  /// Validate space before upload
  Future<bool> validateSpaceBeforeUpload(String? spaceId) async {
    if (spaceId == null || spaceId.isEmpty) {
      return false;
    }

    try {
      // Check if space exists in Firestore
      final spaceDoc = await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .get();

      return spaceDoc.exists;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      return false;
    }
  }

  /// Clear notification for a specific upload
  void clearNotificationForUpload(String postId) {
    _pendingNotifications.remove(postId);
    _notificationsPlugin.cancel(postId.hashCode);
  }

  /// Clear all pending notifications
  void clearAllNotifications() {
    _pendingNotifications.clear();
    _notificationsPlugin.cancelAll();
  }

  /// Cancel all uploads
  Future<void> cancelAllUploads() async {
    final uploads = await _mediaCompressionService.getUploadProgress();

    for (final upload in uploads) {
      if (upload['status'] != 'completed' &&
          upload['status'] != 'failed' &&
          upload['status'] != 'cancelled') {
        await _mediaCompressionService.cancelUpload(upload['postId'] as String);
      }
    }
  }

  /// Get upload post details
  Future<Map<String, dynamic>?> getUploadDetails(String postId) async {
    final uploads = await _mediaCompressionService.getUploadProgress();

    try {
      return uploads.firstWhere((item) => item['postId'] == postId);
    } catch (e) {
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    stopBackgroundMonitoring();
    _pendingNotifications.clear();
  }
}
