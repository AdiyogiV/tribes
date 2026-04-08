import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/features/settings/presentation/pages/user_settings.dart';
import 'package:aurogram/shared/presentation/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/features/profile/presentation/pages/edit_user_profile.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/profile/presentation/pages/social/invites.dart';
import 'package:aurogram/features/notifications/presentation/pages/notifications.dart';
import 'package:aurogram/features/profile/presentation/pages/social/aura_leaderboard.dart';
import 'package:aurogram/features/profile/presentation/pages/social/namaste_history.dart';
import 'package:aurogram/features/profile/presentation/pages/social/followers_following_page.dart';
import 'package:aurogram/shared/presentation/widgets/media/media_type_selector.dart';
import 'package:aurogram/features/stories/pages/story_composer_page.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_creation_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Mixin providing navigation and action methods for the user profile page.
mixin ProfileNavigation<T extends StatefulWidget> on State<T> {
  /// Subclass must provide these
  String? get navUid;
  User? get navCurrentUser;
  Map<String, dynamic>? get navCachedProfileData;
  Future<void> Function() get navHandleRefresh;

  void openStatsPage({int initialTabIndex = 0}) {
    if (navUid == null) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => FollowersFollowingPage(
          userId: navUid!,
          userName: navCachedProfileData?['name'] as String?,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  void openLeaderboard() {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => AuraLeaderboardPage(),
      ),
    );
  }

  void showProfileOptions() {
    final primaryColor = AppTheme.primaryColor;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: Text(
              "Edit Profile",
              style: TextStyle(color: primaryColor),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              editProfile();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              "Gram Invites",
              style: TextStyle(color: primaryColor),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              showInvites();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              "App Settings",
              style: TextStyle(color: primaryColor),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              showSettings();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(
            'Cancel',
            style: TextStyle(color: primaryColor),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void showSettings() {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (context) => UserSettingsPage()),
    );
  }

  void editProfile() async {
    if (navCurrentUser == null || navUid == null) {
      showLoginBottomSheet(context);
      return;
    }
    final result = await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => EditProfile(uid: navUid!),
      ),
    );
    if (result == true) {
      navHandleRefresh();
    }
  }

  void showInvites() {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (context) => Invites()),
    );
  }

  void addPost() {
    if (navCurrentUser == null) {
      showLoginBottomSheet(context);
      return;
    }
    showCreateSelectionDialogAction();
  }

  void showCreateSelectionDialogAction() {
    showCreateSelectionDialog(
      context,
      onCreatePost: createPost,
      onCreateStory: createStory,
    );
  }

  void createPost() {
    MediaTypeSelector.showMediaTypeSelection(
      context: context,
      space: 'profile',
      isProfilePost: true,
    );
  }

  void createStory() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const StoryComposerPage(),
      ),
    );
    if (result == true && mounted) {
      // Story was posted, could refresh profile if needed
    }
  }

  void openNotifications() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => Notifications(),
      ),
    );
  }

  void openNamasteHistory() {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => NamasteHistoryPage(),
      ),
    );
  }
}
