import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/services/follow_service.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Mixin providing follow/unfollow, accept/decline follow request logic
/// for the user profile page.
mixin ProfileFollowLogic<T extends StatefulWidget> on State<T> {
  /// Subclass must provide these
  String? get followTargetUid;
  User? get followCurrentUser;
  FollowService get followService;

  bool get isFollowing;
  set isFollowing(bool value);
  bool get isFollowLoading;
  set isFollowLoading(bool value);
  String? get followStatus;
  set followStatus(String? value);
  bool get theyFollowMe;
  set theyFollowMe(bool value);
  bool get isPrivateProfile;
  set isPrivateProfile(bool value);
  bool get hasPendingRequestToMe;
  set hasPendingRequestToMe(bool value);
  bool get isAcceptingRequest;
  set isAcceptingRequest(bool value);
  int get followerCount;
  set followerCount(int value);
  int get followingCount;
  set followingCount(int value);

  /// Called after successful follow to refresh compatibility, etc.
  void onFollowChanged();

  /// Loads follow relationship data (not counts - those come from stream)
  Future<void> loadFollowData({bool forceRefresh = false}) async {
    if (followTargetUid == null) return;

    try {
      // For other users' profiles, load relationship data in parallel
      if (followTargetUid != followCurrentUser?.uid) {
        final results = await Future.wait([
          followService.getFollowStatus(followTargetUid!),
          followService.isFollowedBy(followTargetUid!),
          followService.hasPendingRequestToMe(followTargetUid!),
          UserService().isPrivateProfile(followTargetUid),
        ]);

        if (mounted) {
          setState(() {
            followStatus = results[0] as String?;
            isFollowing = followStatus != null;
            theyFollowMe = results[1] as bool;
            hasPendingRequestToMe = results[2] as bool;
            isPrivateProfile = results[3] as bool;
          });
        }
      } else {
        // Own profile - just check privacy setting
        final isPrivate = await UserService().isPrivateProfile(followTargetUid);
        if (mounted) {
          setState(() => isPrivateProfile = isPrivate);
        }
      }
    } catch (e) {
      AppLogger.w('Error loading follow data: $e');
    }
  }

  Future<void> handleFollowTap() async {
    if (followTargetUid == null || isFollowLoading) return;
    if (followCurrentUser == null) {
      showLoginBottomSheet(context);
      return;
    }

    setState(() => isFollowLoading = true);

    try {
      bool success;
      final wasFollowing = isFollowing;

      if (isFollowing) {
        // Unfollow or cancel request
        final wasConfirmedFollower =
            followStatus == FollowService.statusFollowing;
        success = await followService.unfollowUser(followTargetUid!);
        if (success && mounted) {
          setState(() {
            isFollowing = false;
            followStatus = null;
            if (wasConfirmedFollower) {
              followerCount -= 1;
            }
          });
        }
      } else {
        // Follow - pass whether target is private so correct status is written
        success = await followService.followUser(followTargetUid!,
            targetIsPrivate: isPrivateProfile);
        if (success && mounted) {
          setState(() {
            isFollowing = true;
            followStatus = isPrivateProfile
                ? FollowService.statusPending
                : FollowService.statusFollowing;
          });
        }
      }

      // After successful follow, update compatibility badge immediately
      if (success && !wasFollowing && mounted) {
        onFollowChanged();
      }
    } catch (e) {
      AppLogger.e('Error handling follow tap', error: e);
    } finally {
      if (mounted) {
        setState(() => isFollowLoading = false);
      }
    }
  }

  /// Accept a pending follow request from this user
  Future<void> acceptFollowRequest() async {
    if (followTargetUid == null || isAcceptingRequest) return;

    setState(() => isAcceptingRequest = true);
    HapticFeedback.lightImpact();

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('acceptFollowRequest');
      await callable.call({'followerId': followTargetUid});

      HapticFeedback.mediumImpact();

      if (mounted) {
        setState(() {
          hasPendingRequestToMe = false;
          theyFollowMe = true;
          isAcceptingRequest = false;
          followerCount += 1;
        });
        onFollowChanged();
      }
    } catch (e) {
      AppLogger.e('Error accepting follow request', error: e);
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => isAcceptingRequest = false);
      }
    }
  }

  /// Decline a pending follow request from this user
  Future<void> declineFollowRequest() async {
    if (followTargetUid == null || isAcceptingRequest) return;

    setState(() => isAcceptingRequest = true);
    HapticFeedback.lightImpact();

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('rejectFollowRequest');
      await callable.call({'followerId': followTargetUid});

      if (mounted) {
        setState(() {
          hasPendingRequestToMe = false;
          isAcceptingRequest = false;
        });
      }
    } catch (e) {
      AppLogger.e('Error declining follow request', error: e);
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => isAcceptingRequest = false);
      }
    }
  }
}
