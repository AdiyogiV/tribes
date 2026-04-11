import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/shared/presentation/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/media/media_type_selector.dart';
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
    context.push(
      '/user/connections/$navUid',
      extra: {
        'userName': navCachedProfileData?['name'] as String?,
        'initialTabIndex': initialTabIndex,
      },
    );
  }

  void openLeaderboard() {
    context.push('/leaderboard');
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
    context.push('/settings');
  }

  void editProfile() async {
    if (navCurrentUser == null || navUid == null) {
      showLoginBottomSheet(context);
      return;
    }
    final result = await context.push('/profile/edit/$navUid');
    if (result == true) {
      navHandleRefresh();
    }
  }

  void showInvites() {
    context.push('/invites');
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
    final result = await context.push('/stories/compose');
    if (result == true && mounted) {
      // Story was posted, could refresh profile if needed
    }
  }

  void openNotifications() {
    context.push('/notifications');
  }

  void openNamasteHistory() {
    context.push('/namaste/history');
  }
}
