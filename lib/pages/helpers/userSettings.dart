import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/services/notification_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/providers/theme_provider.dart';
import 'package:aurogram/pages/uploads/uploadsPage.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({Key? key}) : super(key: key);

  @override
  UserSettingsPageState createState() => UserSettingsPageState();
}

class UserSettingsPageState extends State<UserSettingsPage> {
  bool _isPrivateProfile = false;
  bool _isLoadingPrivacy = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySetting();
  }

  Future<void> _loadPrivacySetting() async {
    final userService = UserService();
    final isPrivate = await userService.isPrivateProfile(userService.user?.uid);
    if (mounted) {
      setState(() {
        _isPrivateProfile = isPrivate;
        _isLoadingPrivacy = false;
      });
    }
  }

  Future<void> _togglePrivateProfile(bool value) async {
    HapticFeedback.lightImpact();
    setState(() => _isPrivateProfile = value);
    
    final userService = UserService();
    final success = await userService.setPrivateProfile(value);
    
    if (!success && mounted) {
      // Revert on failure
      setState(() => _isPrivateProfile = !value);
    }
  }
  
  Future<void> _fixNotifications() async {
    HapticFeedback.lightImpact();
    
    final notificationService = NotificationService();
    
    // Show loading dialog
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CupertinoAlertDialog(
        title: Text('Fixing Notifications'),
        content: Padding(
          padding: EdgeInsets.only(top: 16),
          child: CupertinoActivityIndicator(),
        ),
      ),
    );
    
    try {
      // First request permissions if not already granted
      await notificationService.requestPermissions();
      
      // Force re-register the FCM token
      await notificationService.forceReRegisterToken();
      
      // Run diagnostics
      final diagnostics = await notificationService.runDiagnostics();
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      
      // Show results
      final hasToken = diagnostics['hasFcmToken'] == true;
      final tokenSaved = diagnostics['tokenInFirestore'] == true;
      final hasApns = diagnostics['hasApnsToken'] ?? true; // Default true for Android
      
      String message;
      if (hasToken && tokenSaved && hasApns) {
        message = '✅ Notifications fixed!\n\nYour device is now registered for push notifications.';
      } else {
        message = '⚠️ Some issues found:\n\n';
        if (!hasApns) message += '• APNs token missing (iOS issue)\n';
        if (!hasToken) message += '• FCM token missing\n';
        if (!tokenSaved) message += '• Token not saved to server\n';
        message += '\nPlease check your notification permissions in iOS Settings > Aurogram.';
      }
      
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(hasToken && tokenSaved ? 'Success' : 'Attention'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(message),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('Failed to fix notifications: $e'),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          // Transparent header matching app style
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).scaffoldBackgroundColor.withValues(alpha: isDark ? 0.98 : 0.97),
                  Theme.of(context).scaffoldBackgroundColor.withValues(alpha: isDark ? 0.92 : 0.90),
                ],
                stops: const [0.0, 0.5, 0.8, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 60,
                alignment: Alignment.center,
                child: AppHeaderStyle.buildUniversalHeaderContent(
                  title: 'settings',
                  leadingWidget: IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: primaryColor, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              children: [
                // App Section
                _buildSectionHeader(context, 'App'),
                const SizedBox(height: 8),
                _buildThemeToggleTile(context),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.cloud_upload_outlined,
                  iconColor: AppTheme.skyBlue,
                  title: 'Uploads',
                  subtitle: 'View upload progress',
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (context) => UploadsPage()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.cleaning_services_outlined,
                  iconColor: AppTheme.grassGreen,
                  title: 'Clear Cache',
                  subtitle: 'Free up storage space',
                  onTap: () {
                    final cacheService = locator<CacheService>();
                    cacheService.clearCache();
                    _showCacheConfirmationDialog();
                  },
                ),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.notifications_active_outlined,
                  iconColor: AppTheme.honeyAmber,
                  title: 'Fix Notifications',
                  subtitle: 'Re-register push notifications',
                  onTap: _fixNotifications,
                ),
                const SizedBox(height: 24),

                // Privacy Section
                _buildSectionHeader(context, 'Privacy'),
                const SizedBox(height: 8),
                _buildPrivateProfileToggle(context),
                const SizedBox(height: 24),

                // Account Section
                _buildSectionHeader(context, 'Account'),
                const SizedBox(height: 8),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.logout,
                  iconColor: AppTheme.honeyAmber,
                  title: 'Log Out',
                  subtitle: 'Sign out of your account',
                  onTap: _showLogoutConfirmationDialog,
                ),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.delete_forever,
                  iconColor: AppTheme.errorColor,
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account',
                  onTap: _showDeleteConfirmationDialog,
                  isDestructive: true,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final primaryColor = AppTheme.primaryColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: primaryColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// Use TransparentToolbox.buildCard() for consistent card styling
  static const EdgeInsets _settingsCardPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
  static const EdgeInsets _settingsCardMargin = EdgeInsets.symmetric(horizontal: 16);

  Widget _buildThemeToggleTile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.primaryColor;

    return TransparentToolbox.buildCard(
      context: context,
      padding: _settingsCardPadding,
      margin: _settingsCardMargin,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDark ? 'Dark Mode' : 'Light Mode',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDark ? 'Switch to light theme' : 'Switch to dark theme',
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: isDark,
            activeTrackColor: primaryColor,
            onChanged: (value) {
              HapticFeedback.lightImpact();
              Provider.of<ThemeProvider>(context, listen: false).toggle();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateProfileToggle(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;

    return TransparentToolbox.buildCard(
      context: context,
      padding: _settingsCardPadding,
      margin: _settingsCardMargin,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isPrivateProfile ? CupertinoIcons.lock_fill : CupertinoIcons.globe,
              color: primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private Profile',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isPrivateProfile
                      ? 'Only followers can see your posts'
                      : 'Anyone can see your posts',
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          _isLoadingPrivacy
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CupertinoActivityIndicator(color: primaryColor),
                )
              : CupertinoSwitch(
                  value: _isPrivateProfile,
                  activeTrackColor: primaryColor,
                  onChanged: _togglePrivateProfile,
                ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final primaryColor = AppTheme.primaryColor;

    return TransparentToolbox.buildCard(
      context: context,
      padding: _settingsCardPadding,
      margin: _settingsCardMargin,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDestructive ? AppTheme.errorColor : primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: primaryColor.withValues(alpha: 0.4),
            size: 20,
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
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
                    color: isDark 
                        ? const Color(0xFF1C1C1E) 
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                            padding: const EdgeInsets.all(14),
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
                          const SizedBox(height: 20),
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
                          const SizedBox(height: 12),
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
                            const SizedBox(height: 20),
                            // Input field
                            Container(
                              decoration: BoxDecoration(
                                color: isDark 
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
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
                            const SizedBox(height: 24),
                            // Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (confirmationText.toLowerCase() == 'delete') {
                                        HapticFeedback.mediumImpact();
                                        setState(() {
                                          isDeleting = true;
                                        });
                                        await _deleteUserAccount();
                                      } else {
                                        HapticFeedback.heavyImpact();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        color: errorColor,
                                        borderRadius: BorderRadius.circular(12),
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
                            const SizedBox(height: 8),
                            const PulsingDots(size: 10),
                            const SizedBox(height: 16),
                            Text(
                              'Deleting your account...',
                              style: TextStyle(
                                fontSize: 14,
                                color: primaryColor.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
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

  void _showCacheConfirmationDialog() {
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
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                        padding: const EdgeInsets.all(14),
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
                      const SizedBox(height: 20),
                      Text(
                        'Cache Cleared',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Storage space has been freed up',
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
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

  void _showLogoutConfirmationDialog() {
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
              if (mounted) {
                await Provider.of<AuthService>(context, listen: false).signOut();
                // Pop the settings page to go back to the main tabs
                if (mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            textStyle: TextStyle(color: AppTheme.errorColor),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUserAccount() async {
    UserService userService = UserService();
    try {
      bool success = await userService.deleteUser();
      if (success) {
        await _handleSuccessfulDeletion();
      }
    } catch (e) {
      if (e is NeedsReauthenticationException) {
        await _handleReauthenticationRequired();
      } else {
        // Show error dialog for other failures
        if (mounted) {
          Navigator.of(context).pop(); // Close deletion dialog
          _showMinimalDialog(
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

  Future<void> _handleSuccessfulDeletion() async {
    // Get scaffold messenger before navigation (context may become invalid)
    final messenger = ScaffoldMessenger.of(context);
    
    // Navigate away first to prevent UI from trying to access deleted user data
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    
    // Show confirmation snackbar after navigation
    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
    
    // Clear local caches - the auth state listener will handle the rest
    // Note: user.delete() already invalidated auth, so signOut just cleans up local state
    try {
      await Provider.of<AuthService>(context, listen: false).signOut();
    } catch (_) {
      // Ignore errors - user is already deleted, just cleaning up local state
    }
  }

  Future<void> _handleReauthenticationRequired() async {
    // Close the deletion dialog first
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Store references before showing dialog
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
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                        padding: const EdgeInsets.all(14),
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
                      const SizedBox(height: 20),
                      Text(
                        'Re-login Required',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'For security, please log out and log in again before deleting your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () async {
                          Navigator.of(context).pop();
                          await authService.signOut();
                          navigator.popUntil((route) => route.isFirst);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(12),
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

  void _showMinimalDialog({
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
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 28),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          onPressed?.call();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
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
}
