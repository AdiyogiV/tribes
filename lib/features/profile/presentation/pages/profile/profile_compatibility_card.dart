import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/astrology/presentation/widgets/compatibility_badge.dart';

/// Compatibility card for viewing astrological compatibility with another user.
class ProfileCompatibilityCard extends StatelessWidget {
  final bool isDark;
  final String otherUserId;
  final String? followStatus;
  final bool theyFollowMe;
  final Map<String, dynamic>? cachedProfileData;
  final GlobalKey<dynamic> compatibilityBadgeKey;

  const ProfileCompatibilityCard({
    super.key,
    required this.isDark,
    required this.otherUserId,
    required this.followStatus,
    required this.theyFollowMe,
    required this.cachedProfileData,
    required this.compatibilityBadgeKey,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Get other user info from cached profile data
    final otherUserName = cachedProfileData?['name'] as String? ??
        cachedProfileData?['nickname'] as String?;
    final otherUserPhotoUrl =
        cachedProfileData?['displayPicture'] as String? ??
            cachedProfileData?['profilePictureUrl'] as String?;

    // Get other user's sign data from cached profile
    final otherUserSun = cachedProfileData?['sunSign'] as String?;
    final otherUserMoon = cachedProfileData?['moonSign'] as String?;
    final otherUserRising = cachedProfileData?['ascendant'] as String?;

    // Get current user info - use displayName first, fallback to fetching from Firestore
    final currentUserName = user?.displayName;
    final currentUserPhotoUrl = user?.photoURL;

    return FutureBuilder<Map<String, String?>>(
      future: _getCurrentUserData(user),
      builder: (context, snapshot) {
        final userData = snapshot.data ?? {};
        final resolvedCurrentUserName = currentUserName ?? userData['name'];
        final resolvedCurrentUserPhotoUrl =
            currentUserPhotoUrl ?? userData['profilePictureUrl'];

        return CompatibilityBadge(
          key: compatibilityBadgeKey,
          otherUserId: otherUserId,
          followStatus: followStatus,
          theyFollowYou: theyFollowMe,
          currentUserName: resolvedCurrentUserName,
          otherUserName: otherUserName,
          currentUserPhotoUrl: resolvedCurrentUserPhotoUrl,
          otherUserPhotoUrl: otherUserPhotoUrl,
          currentUserSun: userData['sunSign'],
          currentUserMoon: userData['moonSign'],
          currentUserRising: userData['ascendant'],
          otherUserSun: otherUserSun,
          otherUserMoon: otherUserMoon,
          otherUserRising: otherUserRising,
        );
      },
    );
  }

  Future<Map<String, String?>> _getCurrentUserData(User? user) async {
    if (user == null) return {};

    try {
      final doc = await locator<UserRepository>().getUser(user.uid);
      if (doc.exists) {
        final data = doc.data();
        return {
          'name': user.displayName ??
              data?['name'] as String? ??
              data?['nickname'] as String?,
          'profilePictureUrl': data?['displayPicture'] as String? ??
              data?['profilePictureUrl'] as String?,
          'sunSign': data?['sunSign'] as String?,
          'moonSign': data?['moonSign'] as String?,
          'ascendant': data?['ascendant'] as String?,
        };
      }
    } catch (_) {
      AppLogger.w('ProfileCompatibilityCard: failed to fetch user data', category: LogCategory.general);
    }

    return {
      'name': user.displayName,
    };
  }
}
