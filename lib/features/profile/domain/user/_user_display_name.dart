import 'package:aurogram/core/logging/app_logger.dart';

import '../user_service.dart';

/// Extension on [UserService] for display name resolution and caching.
extension UserDisplayName on UserService {
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
  Future<String> getUserDisplayName(String userId,
      {String? cachedName}) async {
    if (userId.isEmpty) {
      return 'User';
    }

    final isAuthenticated = user != null;

    // Fast path: If we have a cached name and it's still valid, use it
    if (cachedName != null &&
        cachedName.isNotEmpty &&
        cachedName != UserService.deletedUserLabel) {
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
    if (UserService.displayNameCache.containsKey(userId)) {
      final cached = UserService.displayNameCache[userId]!;
      final timestamp = UserService.displayNameCacheTimestamps[userId];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < UserService.cacheExpiry) {
        return cached;
      }
    }

    // Check deletedUsers cache
    if (UserService.deletedUserCache.containsKey(userId)) {
      final timestamp = UserService.deletedUserCacheTimestamps[userId];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < UserService.cacheExpiry) {
        if (UserService.deletedUserCache[userId] == true) {
          UserService.displayNameCache[userId] = UserService.deletedUserLabel;
          UserService.displayNameCacheTimestamps[userId] = DateTime.now();
          return UserService.deletedUserLabel;
        }
      }
    }

    // Fetch from users collection - profiles are PUBLIC, readable when logged out
    AppLogger.d('Fetching user name from Firestore',
        category: LogCategory.database,
        data: {
          'userId': userId,
          'authenticated': isAuthenticated,
          'hasCache': UserService.displayNameCache.containsKey(userId),
          'cachedName': UserService.displayNameCache.containsKey(userId)
              ? UserService.displayNameCache[userId]
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
        UserService.displayNameCache[userId] = name;
        UserService.displayNameCacheTimestamps[userId] = DateTime.now();
        UserService.deletedUserCache[userId] = false;
        UserService.deletedUserCacheTimestamps[userId] = DateTime.now();
        return name;
      } else {
        AppLogger.w('User document does not exist in users collection',
            category: LogCategory.database,
            data: {'userId': userId, 'authenticated': isAuthenticated});
      }
    } catch (e) {
      // Log detailed error - profiles should be public, so this shouldn't happen
      final errorStr = e.toString();
      final isPermissionError =
          errorStr.toLowerCase().contains('permission') ||
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
            'hasCache': UserService.displayNameCache.containsKey(userId)
          });

      // Only use cache as fallback if fetch truly failed
      if (UserService.displayNameCache.containsKey(userId)) {
        final cached = UserService.displayNameCache[userId]!;
        if (cached != UserService.deletedUserLabel) {
          AppLogger.d('Using cached name due to fetch error',
              category: LogCategory.database,
              data: {
                'userId': userId,
                'cachedName': cached,
                'wasPermissionError': isPermissionError
              });
          return cached;
        }
      }
    }

    // Check deletedUsers collection - ONLY if authenticated
    if (isAuthenticated) {
      try {
        final deletedDoc =
            await firestore.collection('deletedUsers').doc(userId).get();
        if (deletedDoc.exists) {
          AppLogger.d('User found in deletedUsers collection',
              category: LogCategory.database, data: {'userId': userId});
          UserService.deletedUserCache[userId] = true;
          UserService.deletedUserCacheTimestamps[userId] = DateTime.now();
          UserService.displayNameCache[userId] = UserService.deletedUserLabel;
          UserService.displayNameCacheTimestamps[userId] = DateTime.now();
          return UserService.deletedUserLabel;
        }
        UserService.deletedUserCache[userId] = false;
        UserService.deletedUserCacheTimestamps[userId] = DateTime.now();
      } catch (e) {
        AppLogger.w('Error checking deletedUsers collection',
            category: LogCategory.database,
            data: {'userId': userId, 'error': e.toString()});
      }
    }

    // Fallback: user doesn't exist
    // Check cache one more time before showing generic fallback
    if (UserService.displayNameCache.containsKey(userId)) {
      final cached = UserService.displayNameCache[userId]!;
      if (cached != UserService.deletedUserLabel ||
          UserService.deletedUserCache[userId] == true) {
        AppLogger.d('Using cached name as final fallback',
            category: LogCategory.database,
            data: {
              'userId': userId,
              'cachedName': cached,
              'authenticated': isAuthenticated
            });
        return cached;
      }
    }

    AppLogger.w(
        'User not found and no cache available - returning generic fallback',
        category: LogCategory.database,
        data: {
          'userId': userId,
          'authenticated': isAuthenticated,
          'hasCache': UserService.displayNameCache.containsKey(userId),
          'cacheKeys': UserService.displayNameCache.keys
              .toList()
              .take(5)
              .toList() // Sample of cache keys for debugging
        });
    return 'User';
  }

  /// Clears the display name cache for a specific user.
  /// Useful when user data changes or account is deleted.
  void clearDisplayNameCache(String userId) {
    UserService.displayNameCache.remove(userId);
    UserService.displayNameCacheTimestamps.remove(userId);
    UserService.deletedUserCache.remove(userId);
    UserService.deletedUserCacheTimestamps.remove(userId);
  }

  /// Clears all display name caches.
  /// Useful for testing or memory management.
  void clearAllDisplayNameCaches() {
    UserService.displayNameCache.clear();
    UserService.displayNameCacheTimestamps.clear();
    UserService.deletedUserCache.clear();
    UserService.deletedUserCacheTimestamps.clear();
  }
}
