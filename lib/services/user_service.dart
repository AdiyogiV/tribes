import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:aurogram/services/contact_service.dart';
import 'package:aurogram/platform/file_helper.dart' as file_helper;
import 'package:aurogram/utils/firestore/firestore_recovery.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? get user => _auth.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference userCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference nicknameCollection =
      FirebaseFirestore.instance.collection('nicknames');
  final CollectionReference blockCollection =
      FirebaseFirestore.instance.collection('blocks');

  // Cache for deleted user status to avoid repeated queries
  static final Map<String, bool> _deletedUserCache = {};
  static final Map<String, DateTime> _deletedUserCacheTimestamps = {};
  static final Map<String, String> _displayNameCache = {};
  static final Map<String, DateTime> _displayNameCacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 15);
  static const String _deletedUserLabel = 'Deleted User';

  /// Saves FCM token to Firestore with multi-device support.
  /// Adds token to fcmTokens array and also sets legacy fcmToken field.
  Future<void> saveFcmToken(String token) async {
    if (user != null) {
      try {
        final userDoc = userCollection.doc(user!.uid);
        final snapshot = await userDoc.get();

        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          final existingTokens =
              (data?['fcmTokens'] as List<dynamic>?)?.cast<String>() ?? [];

          if (!existingTokens.contains(token)) {
            // Add new token to array
            await userDoc.update({
              'fcmToken': token,
              'fcmTokens': FieldValue.arrayUnion([token]),
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
          } else {
            // Token exists, just update timestamp
            await userDoc.update({
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
          }
        } else {
          // Create new document with token
          await userDoc.set({
            'fcmToken': token,
            'fcmTokens': [token],
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (e) {
        AppLogger.e('Error saving FCM token',
            category: LogCategory.messaging, error: e);
        // Fallback to simple set for backward compatibility
        await userCollection.doc(user!.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      }
    }
  }

  // Add this method to get FCM token
  Future<String?> getFcmToken() async {
    if (user != null) {
      DocumentSnapshot doc = await userCollection.doc(user!.uid).get();
      return doc.get('fcmToken') as String?;
    }
    return null;
  }

  // sayNamaste() has been moved to NamasteService (backend-first approach)
  // Use NamasteService().sendNamaste() instead

  Future<DocumentSnapshot> getUser(String user) async {
    return await FirebaseFirestore.instance.collection('users').doc(user).get();
  }

  /// Gets display name for a user, handling deleted accounts.
  ///
  /// This method:
  /// 1. Fetches from Firestore (user profiles are public, readable when logged out)
  /// 2. Uses cache only for performance optimization (not required)
  /// 3. Checks deletedUsers collection if user doesn't exist (only when authenticated)
  /// 4. Returns "Deleted User" ONLY when confirmed in deletedUsers collection
  ///
  /// [userId] - The user ID to get display name for
  /// [cachedName] - Optional cached name to validate (optimization)
  ///
  /// Returns the user's display name, "Deleted User" if confirmed deleted, or "User" for errors
  Future<String> getUserDisplayName(String userId, {String? cachedName}) async {
    if (userId.isEmpty) {
      return 'User';
    }

    final isAuthenticated = user != null;

    // Fast path: If we have a cached name and it's still valid, use it
    if (cachedName != null &&
        cachedName.isNotEmpty &&
        cachedName != _deletedUserLabel) {
      // Quick check: is user still valid?
      try {
        final userDoc = await userCollection.doc(userId).get();
        if (userDoc.exists) {
          // User still exists, cached name is valid
          return cachedName;
        }
        // User deleted, fall through to check deletedUsers
      } catch (e) {
        // On error, fall through to full check (will try to fetch fresh data)
        AppLogger.w('Error validating cached name',
            category: LogCategory.database,
            data: {'userId': userId, 'error': e.toString()});
      }
    }

    // Check display name cache first (performance optimization only)
    if (_displayNameCache.containsKey(userId)) {
      final cachedName = _displayNameCache[userId]!;
      final timestamp = _displayNameCacheTimestamps[userId];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        return cachedName;
      }
    }

    // Check deletedUsers cache
    if (_deletedUserCache.containsKey(userId)) {
      final timestamp = _deletedUserCacheTimestamps[userId];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        if (_deletedUserCache[userId] == true) {
          _displayNameCache[userId] = _deletedUserLabel;
          _displayNameCacheTimestamps[userId] = DateTime.now();
          return _deletedUserLabel;
        }
      }
    }

    // Fetch from users collection - profiles are PUBLIC, readable when logged out
    AppLogger.d('Fetching user name from Firestore',
        category: LogCategory.database,
        data: {
          'userId': userId,
          'authenticated': isAuthenticated,
          'hasCache': _displayNameCache.containsKey(userId),
          'cachedName': _displayNameCache.containsKey(userId)
              ? _displayNameCache[userId]
              : null
        });

    try {
      final userDoc = await userCollection.doc(userId).get();
      AppLogger.d('Firestore fetch completed',
          category: LogCategory.database,
          data: {
            'userId': userId,
            'exists': userDoc.exists,
            'authenticated': isAuthenticated
          });

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        final name =
            data?['name'] as String? ?? data?['nickname'] as String? ?? 'User';
        AppLogger.d('User name fetched successfully',
            category: LogCategory.database,
            data: {
              'userId': userId,
              'name': name,
              'hasName': data?.containsKey('name') ?? false,
              'hasNickname': data?.containsKey('nickname') ?? false
            });
        // Cache for performance
        _displayNameCache[userId] = name;
        _displayNameCacheTimestamps[userId] = DateTime.now();
        _deletedUserCache[userId] = false;
        _deletedUserCacheTimestamps[userId] = DateTime.now();
        return name;
      } else {
        AppLogger.w('User document does not exist in users collection',
            category: LogCategory.database,
            data: {'userId': userId, 'authenticated': isAuthenticated});
      }
    } catch (e) {
      // Log detailed error - profiles should be public, so this shouldn't happen
      final errorStr = e.toString();
      final isPermissionError = errorStr.toLowerCase().contains('permission') ||
          errorStr.toLowerCase().contains('permission-denied') ||
          errorStr.toLowerCase().contains('unauthenticated');

      AppLogger.e('Error fetching user name - profiles should be public',
          category: LogCategory.database,
          error: e,
          data: {
            'userId': userId,
            'authenticated': isAuthenticated,
            'error': errorStr,
            'isPermissionError': isPermissionError,
            'errorType': e.runtimeType.toString(),
            'hasCache': _displayNameCache.containsKey(userId)
          });

      // Only use cache as fallback if fetch truly failed
      if (_displayNameCache.containsKey(userId)) {
        final cachedName = _displayNameCache[userId]!;
        if (cachedName != _deletedUserLabel) {
          AppLogger.d('Using cached name due to fetch error',
              category: LogCategory.database,
              data: {
                'userId': userId,
                'cachedName': cachedName,
                'wasPermissionError': isPermissionError
              });
          return cachedName;
        }
      }
    }

    // Check deletedUsers collection - ONLY if authenticated
    if (isAuthenticated) {
      try {
        final deletedDoc =
            await _firestore.collection('deletedUsers').doc(userId).get();
        if (deletedDoc.exists) {
          AppLogger.d('User found in deletedUsers collection',
              category: LogCategory.database, data: {'userId': userId});
          _deletedUserCache[userId] = true;
          _deletedUserCacheTimestamps[userId] = DateTime.now();
          _displayNameCache[userId] = _deletedUserLabel;
          _displayNameCacheTimestamps[userId] = DateTime.now();
          return _deletedUserLabel;
        }
        _deletedUserCache[userId] = false;
        _deletedUserCacheTimestamps[userId] = DateTime.now();
      } catch (e) {
        AppLogger.w('Error checking deletedUsers collection',
            category: LogCategory.database,
            data: {'userId': userId, 'error': e.toString()});
      }
    }

    // Fallback: user doesn't exist
    // Check cache one more time before showing generic fallback
    if (_displayNameCache.containsKey(userId)) {
      final cachedName = _displayNameCache[userId]!;
      if (cachedName != _deletedUserLabel ||
          _deletedUserCache[userId] == true) {
        AppLogger.d('Using cached name as final fallback',
            category: LogCategory.database,
            data: {
              'userId': userId,
              'cachedName': cachedName,
              'authenticated': isAuthenticated
            });
        return cachedName;
      }
    }

    AppLogger.w(
        'User not found and no cache available - returning generic fallback',
        category: LogCategory.database,
        data: {
          'userId': userId,
          'authenticated': isAuthenticated,
          'hasCache': _displayNameCache.containsKey(userId),
          'cacheKeys': _displayNameCache.keys
              .toList()
              .take(5)
              .toList() // Sample of cache keys for debugging
        });
    return 'User';
  }

  /// Clears the display name cache for a specific user.
  /// Useful when user data changes or account is deleted.
  void clearDisplayNameCache(String userId) {
    _displayNameCache.remove(userId);
    _displayNameCacheTimestamps.remove(userId);
    _deletedUserCache.remove(userId);
    _deletedUserCacheTimestamps.remove(userId);
  }

  /// Clears all display name caches.
  /// Useful for testing or memory management.
  void clearAllDisplayNameCaches() {
    _displayNameCache.clear();
    _displayNameCacheTimestamps.clear();
    _deletedUserCache.clear();
    _deletedUserCacheTimestamps.clear();
  }

  /// Save phone index for contact discovery
  Future<void> _savePhoneIndex(String phoneNumber) async {
    if (user == null) return;
    try {
      await ContactService.savePhoneIndex(phoneNumber, user!.uid);
    } catch (e) {
      AppLogger.w('Failed to save phone index',
          category: LogCategory.database, data: {'error': e.toString()});
    }
  }

  /// Ensure current user's phone is indexed (call on app startup for backfill)
  Future<void> ensurePhoneIndexed() async {
    if (user?.phoneNumber == null) {
      AppLogger.d('Cannot index phone - user phone is null',
          category: LogCategory.database);
      return;
    }

    try {
      final normalized = _normalizePhone(user!.phoneNumber!);
      if (normalized == null) {
        AppLogger.w('Cannot normalize phone for indexing',
            category: LogCategory.database, data: {'phone': user!.phoneNumber});
        return;
      }

      final hash = _hashPhone(normalized);

      // 1. Ensure phone is in user document (backfill for old users)
      final userDoc = await userCollection.doc(user!.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null && userData['phoneNumber'] == null) {
          await userCollection.doc(user!.uid).update({
            'phoneNumber': user!.phoneNumber,
          });
          AppLogger.i('Backfilled phone number in user document',
              category: LogCategory.database, data: {'phone': normalized});
        }
      }

      // 2. Ensure phone is in phoneIndex
      final indexDoc =
          await _firestore.collection('phoneIndex').doc(hash).get();
      if (!indexDoc.exists) {
        await ContactService.savePhoneIndex(user!.phoneNumber!, user!.uid);
        AppLogger.i('Backfilled phone index for current user',
            category: LogCategory.database,
            data: {'hash': hash, 'phone': normalized});
      } else {
        AppLogger.d('Phone already indexed',
            category: LogCategory.database, data: {'hash': hash});
      }
    } catch (e) {
      AppLogger.e('Failed to ensure phone indexed',
          category: LogCategory.database, error: e);
    }
  }

  /// Normalize phone number for consistent hashing
  String? _normalizePhone(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final digitCount = digits.replaceAll('+', '').length;
    if (digitCount < 10) return null;
    if (!digits.startsWith('+')) {
      if (digits.length == 10) {
        digits = '+91$digits';
      } else if (digits.startsWith('91') && digits.length == 12) {
        digits = '+$digits';
      } else if (digits.length > 10) {
        digits = '+$digits';
      }
    }
    return digits;
  }

  /// Hash phone number for privacy
  /// Returns full 64-character SHA256 hash for collision resistance
  String _hashPhone(String phone) {
    final bytes = utf8.encode(phone);
    final digest = sha256.convert(bytes);
    return digest.toString(); // Full 64-char hash
  }

  Future<void> blockUser(String blockedUserId) async {
    if (user == null) return;

    await blockCollection
        .doc(user!.uid)
        .collection('blocked')
        .doc(blockedUserId)
        .set({
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String unblockedUserId) async {
    if (user == null) return;

    await blockCollection
        .doc(user!.uid)
        .collection('blocked')
        .doc(unblockedUserId)
        .delete();
  }

  Future<bool> isUserBlocked(String userId) async {
    if (user == null) return false;

    final blockDoc = await blockCollection
        .doc(user!.uid)
        .collection('blocked')
        .doc(userId)
        .get();

    return blockDoc.exists;
  }

  Future<bool> isBlockedByUser(String userId) async {
    if (user == null) return false;

    final blockDoc = await blockCollection
        .doc(userId)
        .collection('blocked')
        .doc(user!.uid)
        .get();

    return blockDoc.exists;
  }

  Future<List<String>> getBlockedUsers() async {
    if (user == null) return [];

    final querySnapshot =
        await blockCollection.doc(user!.uid).collection('blocked').get();

    return querySnapshot.docs.map((doc) => doc.id).toList();
  }

  /// Gets list of users who have blocked the current user.
  /// Uses collectionGroup query for efficiency instead of reading all users.
  /// IMPORTANT: Requires a Firestore composite index on blocks/{userId}/blocked
  Future<List<String>> getBlockedByUsers() async {
    if (user == null) return [];

    try {
      // Use collectionGroup query to find all 'blocked' docs where doc.id == current user
      // This is O(k) where k = number of users who blocked this user, instead of O(n) for all users
      final querySnapshot = await _firestore
          .collectionGroup('blocked')
          .where(FieldPath.documentId, isEqualTo: user!.uid)
          .get();

      // Extract the parent document IDs (the users who blocked this user)
      final blockedByUsers = querySnapshot.docs
          .map((doc) {
            // Path is: blocks/{blockerId}/blocked/{blockedUserId}
            // We need to extract {blockerId}
            final pathSegments = doc.reference.path.split('/');
            // pathSegments = ['blocks', '{blockerId}', 'blocked', '{blockedUserId}']
            if (pathSegments.length >= 2) {
              return pathSegments[1]; // Return the blocker's userId
            }
            return null;
          })
          .whereType<String>()
          .toList();

      return blockedByUsers;
    } catch (e) {
      AppLogger.e('Error getting blocked-by users',
          category: LogCategory.database, error: e);
      // Fallback: return empty list rather than failing
      return [];
    }
  }

  /// Checks if the currently authenticated user is registered (has a nickname).
  Future<bool> checkRegistration() async {
    final currentUser = _auth.currentUser;
    final overallStopwatch = Stopwatch()..start();
    print('🔐 AUTH: checkRegistration starting - uid: ${currentUser?.uid}');
    AppLogger.i('🔐 checkRegistration: starting',
        category: LogCategory.auth,
        data: {'uid': currentUser?.uid, 'hasUser': currentUser != null});

    if (currentUser?.uid == null) {
      print('🔐 AUTH: checkRegistration - no user, returning true (new user)');
      AppLogger.i('🔐 checkRegistration: no user, returning true (new user)',
          category: LogCategory.auth);
      overallStopwatch.stop();
      return true; // No authenticated user = new user
    }

    // CRITICAL: Check if user is deleted BEFORE checking registration
    // This prevents deleted users from logging in
    try {
      final deletedStopwatch = Stopwatch()..start();
      final deletedDoc = await _firestore
          .collection('deletedUsers')
          .doc(currentUser!.uid)
          .get()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        throw TimeoutException('deletedUsers check timed out');
      });
      deletedStopwatch.stop();
      AppLogger.i('🔐 checkRegistration: deletedUsers fetch completed',
          category: LogCategory.auth,
          data: {'ms': deletedStopwatch.elapsedMilliseconds});
      if (deletedDoc.exists) {
        final deletionData = deletedDoc.data();
        final status = deletionData?['status'] as String?;

        // IMPORTANT: Only block if deletion actually COMPLETED successfully
        // Allow login if deletion is still pending (might be stuck) or failed
        // The scheduled Cloud Function will retry cleanup for pending/failed deletions
        if (status == 'completed') {
          print(
              '🔐 AUTH: checkRegistration - user deletion completed, signing out');
          AppLogger.w(
              '🔐 checkRegistration: user deletion completed, blocking login',
              category: LogCategory.auth,
              data: {'status': status, 'deletionData': deletionData});
          // Sign out the deleted user
          await _auth.signOut();
          throw Exception('Account has been deleted');
        } else {
          // Deletion is pending or failed - allow login but log warning
          print(
              '🔐 AUTH: checkRegistration - found deletedUsers record with status: $status, allowing login');
          AppLogger.w(
              '🔐 checkRegistration: deletedUsers record exists but not completed, allowing login',
              category: LogCategory.auth,
              data: {'status': status, 'uid': currentUser.uid});
        }
      }
    } on TimeoutException catch (e) {
      AppLogger.w(
          '🔐 checkRegistration: deletedUsers check timed out, continuing',
          category: LogCategory.auth,
          data: {'error': e.toString()});
    } catch (e) {
      // If error checking deletedUsers, log but continue (don't block on network issues)
      if (e.toString().contains('deleted')) {
        rethrow; // Re-throw deletion exception
      }
      AppLogger.w(
          '🔐 checkRegistration: error checking deletedUsers, continuing',
          category: LogCategory.auth,
          data: {'error': e.toString()});
    }

    try {
      print(
          '🔐 AUTH: checkRegistration - about to fetch user doc from CACHE first...');
      AppLogger.i('🔐 checkRegistration: fetching user doc...',
          category: LogCategory.auth);

      // CRITICAL: Try cache first to avoid hanging on network issues
      // Firestore with persistence can hang indefinitely waiting for server
      DocumentSnapshot? snapshot;

      try {
        // First try: Get from cache only (instant, no network)
        final cacheStopwatch = Stopwatch()..start();
        print('🔐 AUTH: Trying cache-only fetch...');
        snapshot = await userCollection
            .doc(currentUser!.uid)
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 2));
        cacheStopwatch.stop();
        AppLogger.i('🔐 checkRegistration: cache fetch completed',
            category: LogCategory.auth,
            data: {'ms': cacheStopwatch.elapsedMilliseconds});
        print('🔐 AUTH: Cache hit! exists: ${snapshot.exists}');
      } catch (cacheError) {
        print('🔐 AUTH: Cache miss or error: $cacheError');
        // Cache miss - try server with short timeout
        try {
          final serverStopwatch = Stopwatch()..start();
          print('🔐 AUTH: Trying server fetch with 3s timeout...');
          snapshot = await userCollection
              .doc(currentUser!.uid)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 3));
          serverStopwatch.stop();
          AppLogger.i('🔐 checkRegistration: server fetch completed',
              category: LogCategory.auth,
              data: {'ms': serverStopwatch.elapsedMilliseconds});
          print('🔐 AUTH: Server fetch succeeded! exists: ${snapshot.exists}');
        } catch (serverError) {
          print(
              '🔐 AUTH: Server fetch failed: $serverError - assuming existing user');
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

      print(
          '🔐 AUTH: checkRegistration - user doc fetched, exists: ${snapshot.exists}');
      AppLogger.i('🔐 checkRegistration: user doc fetched',
          category: LogCategory.auth, data: {'exists': snapshot.exists});

      if (!snapshot.exists) {
        print('🔐 AUTH: checkRegistration - user doc does not exist, new user');
        AppLogger.i('🔐 checkRegistration: user doc does not exist, new user',
            category: LogCategory.auth);
        return true; // New user
      }

      Map<String, dynamic>? userData = snapshot.data() as Map<String, dynamic>?;
      if (userData == null) {
        print('🔐 AUTH: checkRegistration - user data is null, new user');
        AppLogger.i('🔐 checkRegistration: user data is null, new user',
            category: LogCategory.auth);
        return true; // New user
      }

      // Check if 'nickname' field exists and is not empty
      final hasNickname = userData.containsKey('nickname') &&
          userData['nickname'] != null &&
          userData['nickname'].toString().trim().isNotEmpty;

      print(
          '🔐 AUTH: checkRegistration completed - hasNickname: $hasNickname, isNewUser: ${!hasNickname}');
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
      print(
          '🔐 AUTH: checkRegistration TIMEOUT exception - assuming existing user: $e');
      AppLogger.w('🔐 checkRegistration: timeout - assuming existing user',
          category: LogCategory.auth);
      overallStopwatch.stop();
      AppLogger.i('🔐 checkRegistration: completed with timeout',
          category: LogCategory.auth,
          data: {'totalMs': overallStopwatch.elapsedMilliseconds});
      return false; // false = existing user (safer default on timeout)
    } catch (e, stackTrace) {
      print('🔐 AUTH: checkRegistration FAILED with error: $e');
      print('🔐 AUTH: checkRegistration stackTrace: $stackTrace');
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
        final existingUsers = await _firestore
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
        downloadURL = await _uploadDisplayPicture(displayPicture) ?? '';
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
        await _savePhoneIndex(user!.phoneNumber!);
      }

      return true;
    } catch (e) {
      AppLogger.e('User registration failed',
          category: LogCategory.auth, error: e);
      return false;
    }
  }

  /// Upload display picture - handles both file path (mobile) and bytes (web)
  /// [source] can be a String file path (mobile) or Uint8List bytes (web)
  Future<String?> _uploadDisplayPicture(dynamic source) async {
    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference storageRef =
          storage.ref().child('users/${user?.uid}/displayPicture.jpg');

      if (source is Uint8List) {
        // Web: upload from bytes
        await storageRef.putData(
            source, SettableMetadata(contentType: 'image/jpeg'));
      } else if (source is String && !kIsWeb) {
        // Mobile: upload from file path
        await storageRef.putFile(file_helper.createIOFile(source));
      } else {
        AppLogger.e('Invalid display picture source type',
            category: LogCategory.auth);
        return null;
      }

      return await storageRef.getDownloadURL();
    } catch (e) {
      AppLogger.e('Error uploading display picture',
          category: LogCategory.auth, error: e);
      return null;
    }
  }

  /// Upload display picture from bytes (for web and cross-platform use)
  Future<String?> uploadDisplayPictureFromBytes(Uint8List bytes) async {
    return await _uploadDisplayPicture(bytes);
  }

  /// Update user's private profile setting
  Future<bool> setPrivateProfile(bool isPrivate) async {
    try {
      if (user == null) return false;
      await userCollection.doc(user!.uid).set({
        'isPrivateProfile': isPrivate,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      AppLogger.e('Error updating private profile setting',
          category: LogCategory.auth, error: e);
      return false;
    }
  }

  /// Get user's private profile setting
  Future<bool> isPrivateProfile(String? userId) async {
    try {
      if (userId == null) return false;
      final doc = await userCollection.doc(userId).get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['isPrivateProfile'] as bool? ?? false;
    } catch (e) {
      AppLogger.e('Error getting private profile setting',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  Future<bool> updateUserProfile({
    String? name,
    String? nickname,
    String? displayPicture,
  }) async {
    try {
      Map<String, dynamic> updateData = {};

      if (name != null) {
        updateData['name'] = name;
      }

      if (nickname != null) {
        updateData['nickname'] = nickname;
        // Get the current name if not provided
        String nameForNickname;
        if (name != null) {
          nameForNickname = name;
        } else {
          DocumentSnapshot userDoc = await userCollection.doc(user?.uid).get();
          Map<String, dynamic>? userData =
              userDoc.data() as Map<String, dynamic>?;
          nameForNickname = userData?['name'] ?? '';
        }
        // Update nickname in the nicknameCollection
        await nicknameCollection.doc('pairs').set({
          nickname: {'name': nameForNickname, 'uid': user?.uid}
        }, SetOptions(merge: true));
      }

      if (displayPicture != null) {
        String? downloadURL = await _uploadDisplayPicture(displayPicture);
        if (downloadURL != null) {
          updateData['displayPicture'] = downloadURL;
        }
      }

      if (updateData.isNotEmpty) {
        updateData["lastUpdated"] = Timestamp.fromDate(DateTime.now());
        await userCollection
            .doc(user?.uid)
            .set(updateData, SetOptions(merge: true));
      }

      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Error updating user profile',
          category: LogCategory.auth, error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Deletes the user's account.
  ///
  /// This method performs a lightweight frontend operation:
  /// 1. Validates recent authentication (Firebase requirement)
  /// 2. Stores deletion metadata for audit purposes
  /// 3. Deletes the Firebase Auth user
  ///
  /// The actual data cleanup is handled by a Cloud Function (onUserDeleted)
  /// that is automatically triggered when the auth user is deleted.
  /// This ensures reliable, complete cleanup even if the app is closed.
  ///
  /// Throws [NeedsReauthenticationException] if re-authentication is required.
  Future<bool> deleteUser() async {
    if (user == null) return false;

    // Check if sign-in is recent enough.
    // Firebase requires recent authentication for sensitive operations like account deletion.
    final lastSignIn = user?.metadata.lastSignInTime;
    if (lastSignIn == null) {
      throw NeedsReauthenticationException();
    }

    final minutesSinceSignIn = DateTime.now().difference(lastSignIn).inMinutes;
    if (minutesSinceSignIn >= 3) {
      // Sign-in is too old - require re-authentication
      AppLogger.i(
          'Delete account requires re-auth: last sign-in was $minutesSinceSignIn minutes ago',
          category: LogCategory.auth);
      throw NeedsReauthenticationException();
    }

    try {
      // Store deletion metadata for audit trail and Cloud Function reference
      // Cloud Function (onUserDeleted) will update this with completion status
      await _storeDeletedUserReference();

      AppLogger.i('Initiating account deletion for user: ${user!.uid}',
          category: LogCategory.auth);

      // Delete the Firebase Auth user
      // This triggers the onUserDeleted Cloud Function which handles ALL data cleanup:
      // - User document + subcollections (dailyInsights, auraHistory, etc.)
      // - Posts and media files
      // - Follow relationships (both directions)
      // - Space memberships
      // - DM conversations
      // - Indices (phoneIndex, nicknames)
      // - Storage files
      await user?.delete();

      AppLogger.i(
          'Account deletion initiated successfully - Cloud Function will complete cleanup',
          category: LogCategory.auth);

      return true;
    } on FirebaseAuthException catch (e) {
      // CRITICAL FIX: Remove deletedUsers record on failure to prevent permanent login block
      AppLogger.w('Auth deletion failed, rolling back deletedUsers record',
          category: LogCategory.auth);
      await _removeDeletedUserReference();

      AppLogger.e('Firebase Auth error during deletion',
          category: LogCategory.auth, error: e);
      if (e.code == 'requires-recent-login') {
        throw NeedsReauthenticationException();
      }
      rethrow;
    } catch (e) {
      // CRITICAL FIX: Remove deletedUsers record on failure to prevent permanent login block
      AppLogger.w('Account deletion failed, rolling back deletedUsers record',
          category: LogCategory.general);
      await _removeDeletedUserReference();

      AppLogger.e('Error during account deletion',
          category: LogCategory.general, error: e);
      // Check if it's a Firebase Auth error requiring re-login
      if (e.toString().contains('requires-recent-login')) {
        throw NeedsReauthenticationException();
      }
      rethrow;
    }
  }

  /// Stores deletion reference for audit trail.
  /// The Cloud Function will update this document with cleanup status.
  Future<void> _storeDeletedUserReference() async {
    await _firestore.collection('deletedUsers').doc(user?.uid).set({
      'phoneNumber': user?.phoneNumber,
      'email': user?.email,
      'deletionRequestedAt': FieldValue.serverTimestamp(),
      'status':
          'pending', // Cloud Function will update to 'completed' or 'failed'
      'requestedFrom': 'app',
    });
  }

  /// Removes deletion reference if account deletion fails.
  /// This prevents users from being permanently blocked if Auth deletion fails.
  Future<void> _removeDeletedUserReference() async {
    try {
      await _firestore.collection('deletedUsers').doc(user?.uid).delete();
      AppLogger.i('Removed deletedUsers record after failed deletion',
          category: LogCategory.auth);
    } catch (e) {
      AppLogger.e('Failed to remove deletedUsers record',
          category: LogCategory.auth, error: e);
      // Don't rethrow - we're already in error handling
    }
  }

  Future<void> reauthenticateUser(String password) async {
    if (user == null) throw Exception("No user is currently signed in");

    try {
      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: password,
      );

      await user!.reauthenticateWithCredential(credential);
    } catch (e) {
      AppLogger.e('Failed to reauthenticate user',
          category: LogCategory.auth, error: e);
      throw Exception("Failed to reauthenticate user");
    }
  }
}

class NeedsReauthenticationException implements Exception {
  @override
  String toString() => 'User needs to reauthenticate before deleting account';
}
