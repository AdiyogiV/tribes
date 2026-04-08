import 'package:flutter/cupertino.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';

/// Dialog helpers for the UserSettingsPage.
/// Contains delete account, cache cleared, logout, reauth, and generic dialogs.
class SettingsDialogs {
  SettingsDialogs._();

  static void showDeleteConfirmationDialog(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;
    final errorColor = AppTheme.errorColor;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Container();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        String confirmationText = '';
        bool isDeleting = false;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.sheetDarkColor : Colors.white,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
                            decoration: BoxDecoration(
                              color: errorColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.delete_forever_rounded,
                              color: errorColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),
                          // Title
                          Text(
                            'Delete Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingMd),
                          if (!isDeleting) ...[
                            // Warning text
                            Text(
                              'This action cannot be undone. All your data will be permanently deleted.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: primaryColor.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingXl),
                            // Input field
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.1),
                                ),
                              ),
                              child: TextField(
                                autofocus: true,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Type "delete" to confirm',
                                  hintStyle: TextStyle(
                                    color: primaryColor.withValues(alpha: 0.35),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                onChanged: (value) {
                                  confirmationText = value;
                                },
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingXxl),
                            // Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(
                                            alpha: 0.08),
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                      ),
                                      child: Text(
                                        'Cancel',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.spacingMd),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (confirmationText.toLowerCase() ==
                                          'delete') {
                                        HapticFeedback.mediumImpact();
                                        setState(() {
                                          isDeleting = true;
                                        });
                                        await _deleteUserAccount(context);
                                      } else {
                                        HapticFeedback.heavyImpact();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      decoration: BoxDecoration(
                                        color: errorColor,
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                      ),
                                      child: const Text(
                                        'Delete',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // Deleting state
                            const SizedBox(height: AppDimensions.spacingSm),
                            const PulsingDots(size: 10),
                            const SizedBox(height: AppDimensions.spacingLg),
                            Text(
                              'Deleting your account...',
                              style: TextStyle(
                                fontSize: 14,
                                color: primaryColor.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingSm),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  static void showCacheConfirmationDialog(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.sheetDarkColor : Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
                        decoration: BoxDecoration(
                          color: AppTheme.grassGreen.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: AppTheme.grassGreen,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXl),
                      Text(
                        'Cache Cleared',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      Text(
                        'Storage space has been freed up',
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXxl),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: Text(
                            'Done',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static void showLogoutConfirmationDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            textStyle: TextStyle(color: AppTheme.primaryColor),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop(); // Close the dialog
              await Provider.of<AuthService>(context, listen: false)
                  .signOut();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            textStyle: TextStyle(color: AppTheme.errorColor),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  static Future<void> showReauthenticationRequired(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final navigator = Navigator.of(context);
    final primaryColor = AppTheme.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.sheetDarkColor : Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
                        decoration: BoxDecoration(
                          color: AppTheme.honeyAmber.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          color: AppTheme.honeyAmber,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXl),
                      Text(
                        'Re-login Required',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingMd),
                      Text(
                        'For security, please log out and log in again before deleting your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXxl),
                      GestureDetector(
                        onTap: () async {
                          Navigator.of(context).pop();
                          await authService.signOut();
                          navigator.popUntil((route) => route.isFirst);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: const Text(
                            'Log Out',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static void showMinimalDialog(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonText,
    VoidCallback? onPressed,
  }) {
    final primaryColor = AppTheme.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.sheetDarkColor : Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 28),
                      ),
                      const SizedBox(height: AppDimensions.spacingXl),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingMd),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXxl),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            onPressed?.call();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                            child: Text(
                              buttonText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------

  static Future<void> _deleteUserAccount(BuildContext context) async {
    UserService userService = UserService();
    try {
      bool success = await userService.deleteUser();
      if (success) {
        await _handleSuccessfulDeletion(context);
      }
    } catch (e) {
      if (e is NeedsReauthenticationException) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close deletion dialog
        }
        if (context.mounted) {
          await showReauthenticationRequired(context);
        }
      } else {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close deletion dialog
          showMinimalDialog(
            context,
            icon: Icons.error_outline_rounded,
            iconColor: AppTheme.errorColor,
            title: 'Something went wrong',
            message: 'Failed to delete account. Please try again later.',
            buttonText: 'OK',
          );
        }
      }
    }
  }

  static Future<void> _handleSuccessfulDeletion(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Text(
                'Account deleted. All your data has been removed.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm)),
        duration: const Duration(seconds: 4),
      ),
    );

    try {
      await Provider.of<AuthService>(context, listen: false).signOut();
    } catch (_) {
      // Ignore - user is already deleted
    }
  }
}
