import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/profile/domain/contact_service.dart';
import 'package:aurogram/shared/models/contact_match.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

/// Shows the contact permission explanation dialog.
/// Returns true if the user tapped "Find Friends", false otherwise.
Future<bool> showContactPermissionDialog(BuildContext context) async {
  return await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Padding(
            padding: EdgeInsets.only(bottom: AppDimensions.paddingSm),
            child: Column(
              children: [
                Image.asset(
                  'assets/icons/namaste.png',
                  width: 48,
                  height: 48,
                ),
                SizedBox(height: AppDimensions.spacingMd),
                Text('Find Friends'),
              ],
            ),
          ),
          content: Text(
            'Aurogram will check your contacts to show who\'s already here.\n\nYour contacts are never stored on our servers - only a secure hash is used for matching.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;
}

/// Handles syncing contacts with permission check, loading state, and error handling.
/// Returns the updated [ContactSyncResult] or null on failure.
Future<ContactSyncResult?> syncContactsWithUI({
  required BuildContext context,
  required ContactService contactService,
  required bool hasRequestedPermission,
  required bool showPermissionDialog,
  required bool Function() isMounted,
  required void Function(bool loading) setLoading,
  required void Function(ContactSyncResult result, bool hasRequested) onResult,
  bool forceRefresh = false,
}) async {
  // Show permission explanation dialog first (if first time)
  if (showPermissionDialog && !hasRequestedPermission) {
    final shouldProceed = await showContactPermissionDialog(context);
    if (!shouldProceed) return null;
  }

  setLoading(true);
  HapticFeedback.lightImpact();

  try {
    final result = await contactService.sync(forceRefresh: forceRefresh);
    if (!isMounted()) return null;

    HapticFeedback.mediumImpact();
    onResult(result, true);

    // Show success feedback
    if (!context.mounted) return result;
    if (result.hasPermission && !result.isEmpty) {
      final onAppCount = result.onApp.length;
      final message = onAppCount > 0
          ? 'Found $onAppCount ${onAppCount == 1 ? 'friend' : 'friends'} on Aurogram!'
          : 'Contacts synced! Invite friends to join.';

      showCustomSnackBar(context, message: message, backgroundColor: onAppCount > 0 ? AppTheme.grassGreen : AppTheme.primaryColor, duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating);
    } else if (!result.hasPermission) {
      showCustomSnackBar(context, message: 'Contact permission is required to find friends', backgroundColor: AppTheme.warningColor, action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () {
              // Open app settings
            },
          ), behavior: SnackBarBehavior.floating);
    }
    return result;
  } catch (e) {
    AppLogger.e('Error syncing contacts', category: LogCategory.ui, error: e);
    if (isMounted() && context.mounted) {
      setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: AppDimensions.spacingMd),
              Expanded(child: Text('Failed to sync contacts')),
              TextButton(
                onPressed: () => syncContactsWithUI(
                  context: context,
                  contactService: contactService,
                  hasRequestedPermission: true,
                  showPermissionDialog: false,
                  isMounted: isMounted,
                  setLoading: setLoading,
                  onResult: onResult,
                  forceRefresh: true,
                ),
                child: Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 4),
        ),
      );
    }
    return null;
  }
}
