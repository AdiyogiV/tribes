import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/providers/theme_provider.dart';
import 'package:aurogram/pages/uploads/uploads_page.dart';
import 'package:aurogram/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/services/anonymous_message_settings_service.dart';

class UserSettingsPage extends StatefulWidget {
  /// When true, shows a back button (e.g. when pushed as a route).
  /// When false, no back button (e.g. when used as a tab).
  final bool showBackButton;

  const UserSettingsPage({super.key, this.showBackButton = true});

  @override
  UserSettingsPageState createState() => UserSettingsPageState();
}

class UserSettingsPageState extends State<UserSettingsPage> {
  bool _isPrivateProfile = false;
  bool _isLoadingPrivacy = true;
  bool _isAnonymousMessagesEnabled = true;
  bool _isLoadingAnonymousMessages = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySetting();
    _loadAnonymousMessagesSetting();
  }

  /// Check if user is currently logged in
  bool get _isLoggedIn {
    final authService = Provider.of<AuthService>(context, listen: false);
    return authService.status == Status.Authenticated &&
        authService.user != null;
  }

  Future<void> _loadPrivacySetting() async {
    final userService = UserService();
    // Only load privacy settings if user is logged in
    if (userService.user?.uid == null) {
      if (mounted) {
        setState(() {
          _isPrivateProfile = false;
          _isLoadingPrivacy = false;
        });
      }
      return;
    }
    final isPrivate = await userService.isPrivateProfile(userService.user?.uid);
    if (mounted) {
      setState(() {
        _isPrivateProfile = isPrivate;
        _isLoadingPrivacy = false;
      });
    }
  }

  Future<void> _togglePrivateProfile(bool value) async {
    // Guard: Only allow toggling for logged-in users
    final userService = UserService();
    if (userService.user == null) return;

    HapticFeedback.lightImpact();
    setState(() => _isPrivateProfile = value);

    final success = await userService.setPrivateProfile(value);

    if (!success && mounted) {
      // Revert on failure
      setState(() => _isPrivateProfile = !value);
    }
  }

  Future<void> _loadAnonymousMessagesSetting() async {
    final service = AnonymousMessageSettingsService();
    await service.initialize();
    final enabled = await service.isEnabled();
    if (mounted) {
      setState(() {
        _isAnonymousMessagesEnabled = enabled;
        _isLoadingAnonymousMessages = false;
      });
    }
  }

  Future<void> _toggleAnonymousMessages(bool value) async {
    HapticFeedback.lightImpact();
    setState(() => _isAnonymousMessagesEnabled = value);

    final service = AnonymousMessageSettingsService();
    await service.initialize();
    final success = await service.setEnabled(value);

    if (!success && mounted) {
      // Revert on failure
      setState(() => _isAnonymousMessagesEnabled = !value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use LayoutBuilder for accurate sizing when inside sidebar layout
          final bool isDesktop =
              constraints.maxWidth >= Responsive.tabletBreakpoint;
          final bool isTablet =
              constraints.maxWidth >= Responsive.mobileBreakpoint &&
                  constraints.maxWidth < Responsive.tabletBreakpoint;

          // Responsive max width: wider on larger screens
          final double maxWidth = isDesktop
              ? 650
              : isTablet
                  ? 550
                  : double.infinity;

          // Responsive vertical padding
          final double verticalPadding = isDesktop ? 24 : 12;

          // Responsive section spacing
          final double sectionSpacing = isDesktop ? 32 : 24;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
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
                          Theme.of(context)
                              .scaffoldBackgroundColor
                              .withValues(alpha: isDark ? 0.98 : 0.97),
                          Theme.of(context)
                              .scaffoldBackgroundColor
                              .withValues(alpha: isDark ? 0.92 : 0.90),
                        ],
                        stops: const [0.0, 0.5, 0.8, 1.0],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        height: isDesktop ? 70 : 60,
                        alignment: Alignment.center,
                        child: AppHeaderStyle.buildUniversalHeaderContent(
                          title: 'settings',
                          leadingWidget: widget.showBackButton
                              ? _buildBackButton(primaryColor, isDesktop)
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Consumer<AuthService>(
                      builder: (context, authService, _) {
                        final isLoggedIn =
                            authService.status == Status.Authenticated &&
                                authService.user != null;

                        return ListView(
                          padding: EdgeInsets.only(
                            top: verticalPadding,
                            bottom: verticalPadding + 100, // Extra padding at bottom for easy scroll up
                            // Add horizontal padding on desktop for better spacing
                            left: isDesktop ? 8 : 0,
                            right: isDesktop ? 8 : 0,
                          ),
                          children: [
                            // App Section - Always visible
                            _buildSectionHeader(context, 'App', isDesktop),
                            SizedBox(height: isDesktop ? 12 : 8),
                            _buildThemeToggleTile(context, isDesktop),
                            const SizedBox(height: 12),
                            // Uploads - only for logged in users
                            if (isLoggedIn) ...[
                              _buildSettingsTile(
                                context: context,
                                icon: Icons.cloud_upload_outlined,
                                iconColor: AppTheme.skyBlue,
                                title: 'Uploads',
                                subtitle: 'View upload progress',
                                isDesktop: isDesktop,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                        builder: (context) => UploadsPage()),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            _buildSettingsTile(
                              context: context,
                              icon: Icons.cleaning_services_outlined,
                              iconColor: AppTheme.grassGreen,
                              title: 'Clear Cache',
                              subtitle: 'Free up storage space',
                              isDesktop: isDesktop,
                              onTap: () {
                                final cacheService = locator<CacheService>();
                                cacheService.clearCache();
                                _showCacheConfirmationDialog();
                              },
                            ),
                            SizedBox(height: sectionSpacing),

                            // Privacy Section - Only for logged in users
                            if (isLoggedIn) ...[
                              _buildSectionHeader(
                                  context, 'Privacy', isDesktop),
                              SizedBox(height: isDesktop ? 12 : 8),
                              _buildPrivateProfileToggle(context, isDesktop),
                              const SizedBox(height: 12),
                              _buildAnonymousMessagesToggle(context, isDesktop),
                              SizedBox(height: sectionSpacing),
                            ],

                            // Account Section
                            _buildSectionHeader(context, 'Account', isDesktop),
                            SizedBox(height: isDesktop ? 12 : 8),
                            if (isLoggedIn) ...[
                              // Logged in: Show Log Out and Delete Account
                              _buildSettingsTile(
                                context: context,
                                icon: Icons.logout,
                                iconColor: AppTheme.honeyAmber,
                                title: 'Log Out',
                                subtitle: 'Sign out of your account',
                                isDesktop: isDesktop,
                                onTap: _showLogoutConfirmationDialog,
                              ),
                              const SizedBox(height: 12),
                              _buildSettingsTile(
                                context: context,
                                icon: Icons.delete_forever,
                                iconColor: AppTheme.errorColor,
                                title: 'Delete Account',
                                subtitle: 'Permanently delete your account',
                                isDesktop: isDesktop,
                                onTap: _showDeleteConfirmationDialog,
                                isDestructive: true,
                              ),
                            ] else ...[
                              // Logged out: Show Sign In option
                              _buildSettingsTile(
                                context: context,
                                icon: Icons.login,
                                iconColor: AppTheme.grassGreen,
                                title: 'Sign In',
                                subtitle: 'Log in to your account',
                                isDesktop: isDesktop,
                                onTap: () {
                                  showLoginBottomSheet(context);
                                },
                              ),
                            ],
                            SizedBox(height: isDesktop ? 48 : 32),

                            // Version info at bottom (web-friendly)
                            if (isDesktop) _buildVersionInfo(context),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build back button with hover effect for web
  Widget _buildBackButton(Color primaryColor, bool isDesktop) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        icon: Icon(Icons.arrow_back_ios,
            color: primaryColor, size: isDesktop ? 24 : 22),
        onPressed: () => Navigator.of(context).pop(),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        tooltip: 'Back',
        splashRadius: isDesktop ? 24 : 20,
      ),
    );
  }

  /// Build version info footer for web
  Widget _buildVersionInfo(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'Aurogram',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: primaryColor.withValues(alpha: 0.3),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, bool isDesktop) {
    final primaryColor = AppTheme.primaryColor;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 20,
        isDesktop ? 12 : 8,
        isDesktop ? 24 : 20,
        isDesktop ? 8 : 4,
      ),
      child: Center(
        child: Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 12 : 11,
            fontWeight: FontWeight.w600,
            color: primaryColor,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  /// Get responsive card padding
  EdgeInsets _getCardPadding(bool isDesktop) => EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 16,
        vertical: isDesktop ? 16 : 14,
      );

  /// Get responsive card margin
  EdgeInsets _getCardMargin(bool isDesktop) => EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 16,
      );

  Widget _buildThemeToggleTile(BuildContext context, bool isDesktop) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final isAutomatic = themeProvider.isAutomatic;
    final primaryColor = AppTheme.primaryColor;

    return Column(
      children: [
        // Auto Theme Toggle
        _buildToggleCard(
          context: context,
          isDesktop: isDesktop,
          icon: Icons.schedule_rounded,
          iconColor: primaryColor,
          title: 'Auto Theme',
          subtitle: isAutomatic
              ? 'Light 8AM-4PM, Dark otherwise'
              : 'Manual theme selection',
          value: isAutomatic,
          onChanged: (value) {
            if (!kIsWeb) HapticFeedback.lightImpact();
            themeProvider.toggleAutomatic();
          },
        ),
        // Dark Mode Toggle - only shown when Auto is OFF
        if (!isAutomatic) ...[
          const SizedBox(height: 12),
          _buildToggleCard(
            context: context,
            isDesktop: isDesktop,
            icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            iconColor: primaryColor,
            title: isDark ? 'Dark Mode' : 'Light Mode',
            subtitle: isDark ? 'Switch to light theme' : 'Switch to dark theme',
            value: isDark,
            onChanged: (value) {
              if (!kIsWeb) HapticFeedback.lightImpact();
              themeProvider.setDarkMode(value);
            },
          ),
        ],
      ],
    );
  }

  /// Build a toggle card with hover effect for web
  Widget _buildToggleCard({
    required BuildContext context,
    required bool isDesktop,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final primaryColor = AppTheme.primaryColor;

    return _HoverableCard(
      isDesktop: isDesktop,
      child: TransparentToolbox.buildCard(
        context: context,
        padding: _getCardPadding(isDesktop),
        margin: _getCardMargin(isDesktop),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 12 : 10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: isDesktop ? 24 : 22,
              ),
            ),
            SizedBox(width: isDesktop ? 16 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 15,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 4 : 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isDesktop ? 13 : 12,
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: CupertinoSwitch(
                value: value,
                activeTrackColor: primaryColor,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateProfileToggle(BuildContext context, bool isDesktop) {
    final primaryColor = AppTheme.primaryColor;

    return _HoverableCard(
      isDesktop: isDesktop,
      child: TransparentToolbox.buildCard(
        context: context,
        padding: _getCardPadding(isDesktop),
        margin: _getCardMargin(isDesktop),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 12 : 10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
              ),
              child: Icon(
                _isPrivateProfile
                    ? CupertinoIcons.lock_fill
                    : CupertinoIcons.globe,
                color: primaryColor,
                size: isDesktop ? 24 : 22,
              ),
            ),
            SizedBox(width: isDesktop ? 16 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Private Profile',
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 15,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 4 : 2),
                  Text(
                    _isPrivateProfile
                        ? 'Only followers can see your posts'
                        : 'Anyone can see your posts',
                    style: TextStyle(
                      fontSize: isDesktop ? 13 : 12,
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
                : MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: CupertinoSwitch(
                      value: _isPrivateProfile,
                      activeTrackColor: primaryColor,
                      onChanged: _togglePrivateProfile,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnonymousMessagesToggle(BuildContext context, bool isDesktop) {
    final primaryColor = AppTheme.primaryColor;

    return _HoverableCard(
      isDesktop: isDesktop,
      child: TransparentToolbox.buildCard(
        context: context,
        padding: _getCardPadding(isDesktop),
        margin: _getCardMargin(isDesktop),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 12 : 10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
              ),
              child: Icon(
                _isAnonymousMessagesEnabled
                    ? Icons.mail_outline
                    : Icons.mail_outline,
                color: primaryColor,
                size: isDesktop ? 24 : 22,
              ),
            ),
            SizedBox(width: isDesktop ? 16 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Anonymous Messages',
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 15,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 4 : 2),
                  Text(
                    _isAnonymousMessagesEnabled
                        ? 'Allow others to send you anonymous messages'
                        : 'Anonymous messages are disabled',
                    style: TextStyle(
                      fontSize: isDesktop ? 13 : 12,
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            _isLoadingAnonymousMessages
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CupertinoActivityIndicator(color: primaryColor),
                  )
                : MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: CupertinoSwitch(
                      value: _isAnonymousMessagesEnabled,
                      activeTrackColor: primaryColor,
                      onChanged: _toggleAnonymousMessages,
                    ),
                  ),
          ],
        ),
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
    required bool isDesktop,
    bool isDestructive = false,
  }) {
    final primaryColor = AppTheme.primaryColor;

    return _HoverableCard(
      isDesktop: isDesktop,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: TransparentToolbox.buildCard(
          context: context,
          padding: _getCardPadding(isDesktop),
          margin: _getCardMargin(isDesktop),
          onTap: () {
            if (!kIsWeb) HapticFeedback.lightImpact();
            onTap();
          },
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: isDesktop ? 24 : 22,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 15,
                        fontWeight: FontWeight.w600,
                        color:
                            isDestructive ? AppTheme.errorColor : primaryColor,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 4 : 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isDesktop ? 13 : 12,
                        color: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: primaryColor.withValues(alpha: 0.4),
                size: isDesktop ? 22 : 20,
              ),
            ],
          ),
        ),
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(
                                            alpha: 0.08),
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
                                      if (confirmationText.toLowerCase() ==
                                          'delete') {
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
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
                await Provider.of<AuthService>(context, listen: false)
                    .signOut();
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
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
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

/// A wrapper widget that adds hover effect for web
/// On mobile, it's a no-op wrapper
class _HoverableCard extends StatefulWidget {
  final Widget child;
  final bool isDesktop;

  const _HoverableCard({
    required this.child,
    required this.isDesktop,
  });

  @override
  State<_HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<_HoverableCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Only apply hover effect on web/desktop
    if (!kIsWeb || !widget.isDesktop) {
      return widget.child;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_isHovered ? 1.01 : 1.0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isHovered ? 0.9 : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}
