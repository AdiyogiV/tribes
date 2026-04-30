import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/data/firebase/firestore_recovery.dart';

import '../user_service.dart';

/// Extension on [UserService] for registration and authentication checks.
extension UserRegistration on UserService {
  /// Background verification for the deletedUsers/{uid} doc.
  ///
  /// Runs unawaited so it never blocks login. If the server confirms the
  /// account was deleted ('status' == 'completed') we sign the user out and
  /// the auth listener handles the rest.
  Future<void> _verifyDeletionInBackground(String uid) async {
    try {
      final doc = await firestore
          .collection('deletedUsers')
          .doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (!doc.exists) return;
      final status = (doc.data()?['status'] as String?);
      if (status == 'completed') {
        AppLogger.w('🔐 background deletion check: signing out deleted user',
            category: LogCategory.auth, data: {'uid': uid});
        await auth.signOut();
      }
    } catch (e) {
      AppLogger.d('Background deletion check skipped: $e',
          category: LogCategory.auth);
    }
  }

  /// Checks if the currently authenticated user is registered (has a nickname).
  Future<bool> checkRegistration() async {
    final currentUser = auth.currentUser;
    final overallStopwatch = Stopwatch()..start();
    AppLogger.d(
        'UserService: checkRegistration starting - uid: ${currentUser?.uid}',
        category: LogCategory.auth);
    AppLogger.i('🔐 checkRegistration: starting',
        category: LogCategory.auth,
        data: {'uid': currentUser?.uid, 'hasUser': currentUser != null});

    if (currentUser?.uid == null) {
      AppLogger.d(
          'UserService: checkRegistration - no user, returning true (new user)',
          category: LogCategory.auth);
      AppLogger.i('🔐 checkRegistration: no user, returning true (new user)',
          category: LogCategory.auth);
      overallStopwatch.stop();
      return true; // No authenticated user = new user
    }

    // CRITICAL: Check if user is deleted BEFORE checking registration.
    //
    // The deletedUsers/{uid} doc only exists for accounts that were deleted,
    // so a cache miss is the normal path. Doing a server fallback here used
    // to block login by 2-5 seconds when the network was warming up. Instead
    // we:
    //   1. Try the cache (instant, in-memory).
    //   2. If the cache says deleted+completed → sign out immediately.
    //   3. Otherwise allow login NOW and verify against the server in the
    //      background. If the server later confirms a completed deletion we
    //      sign the user out then.
    try {
      final deletedStopwatch = Stopwatch()..start();
      DocumentSnapshot? cachedDoc;
      try {
        cachedDoc = await firestore
            .collection('deletedUsers')
            .doc(currentUser!.uid)
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(milliseconds: 500));
        deletedStopwatch.stop();
        AppLogger.i('🔐 checkRegistration: deletedUsers cache hit',
            category: LogCategory.auth,
            data: {'ms': deletedStopwatch.elapsedMilliseconds});
      } catch (_) {
        deletedStopwatch.stop();
        cachedDoc = null;
      }

      if (cachedDoc != null && cachedDoc.exists) {
        final data = cachedDoc.data() as Map<String, dynamic>?;
        final status = data?['status'] as String?;
        if (status == 'completed') {
          AppLogger.w(
              '🔐 checkRegistration: cached deletion confirmed, blocking login',
              category: LogCategory.auth, data: {'status': status});
          await auth.signOut();
          throw Exception('Account has been deleted');
        }
        // Pending/failed: allow login (Cloud Function will retry cleanup).
        AppLogger.w(
            '🔐 checkRegistration: cached deletion not completed, allowing login',
            category: LogCategory.auth, data: {'status': status});
      } else {
        // Cache miss → verify against server in background. Most users are
        // not deleted, so this almost always confirms "not deleted" without
        // any user-visible delay.
        unawaited(_verifyDeletionInBackground(currentUser!.uid));
      }
    } catch (e) {
      if (e.toString().contains('deleted')) {
        rethrow;
      }
      AppLogger.w(
          '🔐 checkRegistration: error checking deletedUsers, continuing',
          category: LogCategory.auth, data: {'error': e.toString()});
    }

    try {
      AppLogger.d(
          'UserService: checkRegistration - about to fetch user doc from CACHE first...',
          category: LogCategory.auth);
      AppLogger.i('🔐 checkRegistration: fetching user doc...',
          category: LogCategory.auth);

      // CRITICAL: Try cache first to avoid hanging on network issues
      // Firestore with persistence can hang indefinitely waiting for server
      DocumentSnapshot? snapshot;

      try {
        // First try: Get from cache only (instant, no network)
        final cacheStopwatch = Stopwatch()..start();
        AppLogger.d('UserService: Trying cache-only fetch...',
            category: LogCategory.auth);
        snapshot = await userCollection
            .doc(currentUser!.uid)
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 2));
        cacheStopwatch.stop();
        AppLogger.i('🔐 checkRegistration: cache fetch completed',
            category: LogCategory.auth,
            data: {'ms': cacheStopwatch.elapsedMilliseconds});
        AppLogger.d(
            'UserService: Cache hit! exists: ${snapshot.exists}',
            category: LogCategory.auth);
      } catch (cacheError) {
        AppLogger.w('UserService: Cache miss or error: $cacheError',
            category: LogCategory.auth);
        // Cache miss - try server with short timeout
        try {
          final serverStopwatch = Stopwatch()..start();
          AppLogger.d(
              'UserService: Trying server fetch with 3s timeout...',
              category: LogCategory.auth);
          snapshot = await userCollection
              .doc(currentUser!.uid)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 3));
          serverStopwatch.stop();
          AppLogger.i('🔐 checkRegistration: server fetch completed',
              category: LogCategory.auth,
              data: {'ms': serverStopwatch.elapsedMilliseconds});
          AppLogger.d(
              'UserService: Server fetch succeeded! exists: ${snapshot.exists}',
              category: LogCategory.auth);
        } catch (serverError) {
          AppLogger.w(
              'UserService: Server fetch failed: $serverError - assuming existing user',
              category: LogCategory.auth);
          // Both cache and server failed - assume existing user to not block
          AppLogger.w('🔐 checkRegistration: both cache and server failed',
              category: LogCategory.auth,
              data: {'error': serverError.toString()});
          // Kick off a recovery attempt in background to help future reads
          Future(() async {
            await FirestoreRecovery.attemptRecovery(
                context: 'checkRegistration');
          });
          return false; // Assume existing user
        }
      }

      AppLogger.d(
          'UserService: checkRegistration - user doc fetched, exists: ${snapshot.exists}',
          category: LogCategory.auth);
      AppLogger.i('🔐 checkRegistration: user doc fetched',
          category: LogCategory.auth, data: {'exists': snapshot.exists});

      if (!snapshot.exists) {
        AppLogger.d(
            'UserService: checkRegistration - user doc does not exist, new user',
            category: LogCategory.auth);
        AppLogger.i(
            '🔐 checkRegistration: user doc does not exist, new user',
            category: LogCategory.auth);
        return true; // New user
      }

      Map<String, dynamic>? userData =
          snapshot.data() as Map<String, dynamic>?;
      if (userData == null) {
        AppLogger.d(
            'UserService: checkRegistration - user data is null, new user',
            category: LogCategory.auth);
        AppLogger.i('🔐 checkRegistration: user data is null, new user',
            category: LogCategory.auth);
        return true; // New user
      }

      // Check if 'nickname' field exists and is not empty
      final hasNickname = userData.containsKey('nickname') &&
          userData['nickname'] != null &&
          userData['nickname'].toString().trim().isNotEmpty;

      AppLogger.d(
          'UserService: checkRegistration completed - hasNickname: $hasNickname, isNewUser: ${!hasNickname}',
          category: LogCategory.auth);
      AppLogger.i('🔐 checkRegistration: completed',
          category: LogCategory.auth,
          data: {'hasNickname': hasNickname, 'isNewUser': !hasNickname});
      overallStopwatch.stop();
      AppLogger.i('🔐 checkRegistration: completed',
          category: LogCategory.auth,
          data: {'totalMs': overallStopwatch.elapsedMilliseconds});
      return !hasNickname; // false = existing user, true = new user
    } on TimeoutException catch (e) {
      // On timeout, assume existing user to prevent blocking on InitUser page
      AppLogger.w(
          'UserService: checkRegistration TIMEOUT exception - assuming existing user: $e',
          category: LogCategory.auth);
      AppLogger.w('🔐 checkRegistration: timeout - assuming existing user',
          category: LogCategory.auth);
      overallStopwatch.stop();
      AppLogger.i('🔐 checkRegistration: completed with timeout',
          category: LogCategory.auth,
          data: {'totalMs': overallStopwatch.elapsedMilliseconds});
      return false; // false = existing user (safer default on timeout)
    } catch (e, stackTrace) {
      AppLogger.e(
          'UserService: checkRegistration FAILED with error: $e',
          category: LogCategory.auth);
      AppLogger.e(
          'UserService: checkRegistration stackTrace: $stackTrace',
          category: LogCategory.auth);
      AppLogger.w('🔐 checkRegistration failed',
          category: LogCategory.database, data: {'error': e.toString()});
      overallStopwatch.stop();
      AppLogger.i('🔐 checkRegistration: completed with error',
          category: LogCategory.auth,
          data: {'totalMs': overallStopwatch.elapsedMilliseconds});
      return false; // false = existing user (safer default on error)
    }
  }

  Future<bool> registerNewUser(
    String name,
    String nickname,
    String? displayPicture,
  ) async {
    try {
      // CRITICAL: Check for duplicate phone number with different UID
      // This can happen if Auth account was deleted but Firestore doc remains
      final phoneNumber = user?.phoneNumber;
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        final existingUsers = await firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: phoneNumber)
            .limit(5) // Check up to 5 (should only be 0 or 1)
            .get();

        // Filter out current user's own document (in case of re-registration)
        final duplicates =
            existingUsers.docs.where((doc) => doc.id != user?.uid).toList();

        if (duplicates.isNotEmpty) {
          // Found existing account with same phone but different UID
          final existingUid = duplicates.first.id;
          final existingData = duplicates.first.data();

          AppLogger.e('Duplicate phone number detected during registration',
              category: LogCategory.auth,
              data: {
                'currentUid': user?.uid,
                'existingUid': existingUid,
                'phoneNumber': phoneNumber,
                'existingNickname': existingData['nickname'],
                'existingName': existingData['name'],
              });

          // Throw error to prevent duplicate registration
          throw Exception(
              'This phone number is already registered to another account. '
              'If you believe this is an error, please contact support.');
        }
      }

      // Set nickname pair
      await nicknameCollection.doc('pairs').set({
        nickname: {'name': name, 'uid': user?.uid}
      }, SetOptions(merge: true));

      String downloadURL = '';
      if (displayPicture != null) {
        downloadURL = await uploadDisplayPictureInternal(displayPicture) ?? '';
      }

      // Create user document (no profile gram - using new follow system)
      await userCollection.doc(user?.uid).set({
        'name': name,
        'nickname': nickname,
        'displayPicture': downloadURL,
        'phoneNumber':
            user?.phoneNumber, // Store phone number for contact discovery
        'followerCount': 0, // New follow system
        'followingCount': 0, // New follow system
        'auraScore': 0, // Initialize aura score for leaderboard
        "timestamp": Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));

      // Save FCM token (non-blocking - don't fail registration if this fails)
      try {
        String? token;
        if (kIsWeb) {
          // On web, check permission first and handle gracefully
          try {
            final permission =
                await FirebaseMessaging.instance.requestPermission(
              alert: true,
              badge: true,
              sound: true,
            );
            if (permission.authorizationStatus ==
                    AuthorizationStatus.authorized ||
                permission.authorizationStatus ==
                    AuthorizationStatus.provisional) {
              token = await FirebaseMessaging.instance
                  .getToken()
                  .timeout(const Duration(seconds: 10));
            }
          } catch (e) {
            // Web push token registration failed - log but don't fail registration
            AppLogger.w(
                'Web FCM token registration failed during user registration (non-blocking)',
                category: LogCategory.messaging,
                data: {'error': e.toString()});
          }
        } else {
          // Mobile: get token directly
          token = await FirebaseMessaging.instance
              .getToken()
              .timeout(const Duration(seconds: 10));
        }

        if (token != null) {
          await saveFcmToken(token);
        }
      } catch (e) {
        // FCM token registration failed - log but don't fail user registration
        // Token can be registered later by NotificationService
        AppLogger.w(
            'FCM token registration failed during user registration (non-blocking)',
            category: LogCategory.messaging,
            data: {'error': e.toString()});
      }

      // Save phone index for contact discovery
      if (user?.phoneNumber != null) {
        await savePhoneIndex(user!.phoneNumber!);
      }

      return true;
    } catch (e) {
      AppLogger.e('User registration failed',
          category: LogCategory.auth, error: e);
      return false;
    }
  }
}
