part of '../notification_service.dart';

/// FCM token registration, Firestore persistence, unread-count tracking,
/// and notification CRUD operations.
extension NotificationTokens on NotificationService {
  // VAPID key for web push notifications.
  // Loaded from Firebase Remote Config key 'web_vapid_key' at runtime.
  static String get _webVapidKey =>
      AppConfig().getString('web_vapid_key', defaultValue: '');

  // ── Token registration ─────────────────────────────────────────────────────

  /// Register FCM token with retry for iOS APNs and support for web.
  Future<void> _registerFCMToken() async {
    try {
      String? token;

      if (kIsWeb) {
        // Web: Request permission first, then get token with VAPID key.
        final permission = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (permission.authorizationStatus == AuthorizationStatus.authorized ||
            permission.authorizationStatus == AuthorizationStatus.provisional) {
          try {
            if (_webVapidKey.isNotEmpty) {
              token = await FirebaseMessaging.instance
                  .getToken(vapidKey: _webVapidKey)
                  .timeout(const Duration(seconds: 30));
            } else {
              // Fallback: try without VAPID key (limited functionality).
              token = await FirebaseMessaging.instance
                  .getToken()
                  .timeout(const Duration(seconds: 30));
              AppLogger.w(
                'Web FCM: Using token without VAPID key - configure VAPID for full push support',
                category: LogCategory.messaging,
              );
            }
          } catch (e) {
            AppLogger.e('Web FCM token retrieval failed',
                category: LogCategory.messaging, error: e);
          }
        } else {
          AppLogger.w('Web notification permission denied',
              category: LogCategory.messaging);
          return;
        }
      } else {
        // Mobile: iOS requires APNs token first.
        if (PlatformServices.instance.isIOS) {
          String? apnsToken;
          // Try up to 15 times with increasing delays (total ~45 seconds).
          for (int i = 0; i < 15; i++) {
            apnsToken = await FirebaseMessaging.instance.getAPNSToken();
            if (apnsToken != null) {
              AppLogger.d('APNs token obtained on attempt ${i + 1}',
                  category: LogCategory.messaging);
              break;
            }
            // Increasing delay: 1s, 1s, 2s, 2s, 3s, 3s, 4s, 4s, 5s…
            await Future.delayed(Duration(seconds: (i ~/ 2) + 1));
          }

          if (apnsToken == null) {
            AppLogger.e(
              'APNs token not available after 15 attempts - iOS push notifications will NOT work!',
              category: LogCategory.messaging,
            );
            // Still try to get FCM token anyway – it might work in some cases.
          }
        }

        token = await FirebaseMessaging.instance
            .getToken()
            .timeout(const Duration(seconds: 30));
      }

      if (token != null) {
        await _saveTokenToFirestore(token);
        AppLogger.i(
          'FCM token registered successfully${kIsWeb ? ' (web)' : ''}',
          category: LogCategory.messaging,
        );
      } else {
        AppLogger.e('FCM token is null', category: LogCategory.messaging);
      }
    } catch (e) {
      AppLogger.e('FCM token registration failed',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Save FCM token to Firestore (supports multi-device).
  Future<void> _saveTokenToFirestore(String token) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc = _firestore.collection('users').doc(uid);
      final snapshot = await userDoc.get();

      if (snapshot.exists) {
        final existingTokens =
            (snapshot.data()?['fcmTokens'] as List<dynamic>?)?.cast<String>() ??
                [];

        if (!existingTokens.contains(token)) {
          await userDoc.update({
            'fcmToken': token,
            'fcmTokens': FieldValue.arrayUnion([token]),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          AppLogger.d('FCM token registered', category: LogCategory.messaging);
        } else {
          await userDoc.update({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await userDoc.set({
          'fcmToken': token,
          'fcmTokens': [token],
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        AppLogger.d('FCM token saved', category: LogCategory.messaging);
      }
    } catch (e) {
      AppLogger.e('FCM token save failed',
          category: LogCategory.messaging, error: e);
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Force register FCM token – call this if token wasn't registered initially.
  Future<void> forceRegisterToken() async {
    await _registerFCMToken();
  }

  /// Force re-register the FCM token (for debugging/fixing).
  Future<bool> forceReRegisterToken() async {
    try {
      AppLogger.i('🔔 Force re-registering FCM token...',
          category: LogCategory.messaging);
      await _registerFCMToken();
      return true;
    } catch (e) {
      AppLogger.e('🔔 Force re-register failed: $e',
          category: LogCategory.messaging);
      return false;
    }
  }

  // ── Unread count ───────────────────────────────────────────────────────────

  /// Start listening to unread notification count.
  void _startUnreadCountListener() {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    _firestore
        .collection('notifications')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      _unreadCount = snapshot.docs.length;
      _unreadCountController.add(_unreadCount);
    });
  }

  // ── Notification CRUD ──────────────────────────────────────────────────────

  /// Mark a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore
          .collection('notifications')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      AppLogger.e('Failed to mark notification as read',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    try {
      final batch = _firestore.batch();
      final unread = await _firestore
          .collection('notifications')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
    } catch (e) {
      AppLogger.e('Failed to mark all notifications as read',
          category: LogCategory.messaging, error: e);
    }
  }

  /// Delete notifications older than 30 days.
  Future<void> cleanupOldNotifications() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final batch = _firestore.batch();

      final oldNotifications = await _firestore
          .collection('notifications')
          .doc(uid)
          .collection('notifications')
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      for (final doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      AppLogger.d(
        'Cleaned up ${oldNotifications.docs.length} old notifications',
        category: LogCategory.messaging,
      );
    } catch (e) {
      AppLogger.e('Failed to cleanup old notifications',
          category: LogCategory.messaging, error: e);
    }
  }

  // ── Diagnostics ────────────────────────────────────────────────────────────

  /// Diagnostic method to check notification setup status.
  /// Returns a map with diagnostic info for debugging.
  Future<Map<String, dynamic>> runDiagnostics() async {
    final diagnostics = <String, dynamic>{};

    try {
      if (kIsWeb) {
        diagnostics['platform'] = 'Web';
      } else {
        diagnostics['platform'] =
            PlatformServices.instance.isIOS ? 'iOS' : 'Android';
      }

      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      diagnostics['permissionStatus'] = settings.authorizationStatus.toString();
      diagnostics['permissionGranted'] =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!kIsWeb && PlatformServices.instance.isIOS) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        diagnostics['apnsToken'] = apnsToken != null
            ? '${apnsToken.substring(0, 20)}...'
            : 'NULL - APNs not working!';
        diagnostics['hasApnsToken'] = apnsToken != null;
      }

      final fcmToken = await FirebaseMessaging.instance.getToken();
      diagnostics['fcmToken'] =
          fcmToken != null ? '${fcmToken.substring(0, 20)}...' : 'NULL';
      diagnostics['hasFcmToken'] = fcmToken != null;

      final uid = _currentUser?.uid;
      if (uid != null && fcmToken != null) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final userData = userDoc.data();
        final savedTokens =
            (userData?['fcmTokens'] as List<dynamic>?)?.cast<String>() ?? [];
        final legacyToken = userData?['fcmToken'] as String?;

        diagnostics['tokenInFirestore'] =
            savedTokens.contains(fcmToken) || legacyToken == fcmToken;
        diagnostics['savedTokenCount'] = savedTokens.length;
        diagnostics['hasLegacyToken'] = legacyToken != null;
      }

      diagnostics['initialized'] = _initialized;
      diagnostics['permissionsRequested'] = _permissionsRequested;
      diagnostics['userId'] = _currentUser?.uid ?? 'NOT LOGGED IN';
    } catch (e) {
      diagnostics['error'] = e.toString();
    }

    AppLogger.i('🔔 Notification Diagnostics: $diagnostics',
        category: LogCategory.messaging);
    return diagnostics;
  }
}
