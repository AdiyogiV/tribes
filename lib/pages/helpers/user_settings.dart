import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/providers/theme_provider.dart';
import 'package:aurogram/pages/uploads/uploads_page.dart';
import 'package:aurogram/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/services/anonymous_message_settings_service.dart';
import 'package:aurogram/pages/helpers/settings/settings_dialogs.dart';
import 'package:aurogram/pages/helpers/settings/settings_tiles.dart';

// Re-export sub-widgets so existing imports continue to work
export 'package:aurogram/pages/helpers/settings/settings_exports.dart';

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
  bool _isAnonymousMessagesEnabled = true; // ignore: unused_field
  bool _isLoadingAnonymousMessages = true; // ignore: unused_field

  @override
  void initState() {
    super.initState();
    _loadPrivacySetting();
    _loadAnonymousMessagesSetting();
  }

  Future<void> _loadPrivacySetting() async {
    final userService = UserService();
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
    final userService = UserService();
    if (userService.user == null) return;

    HapticFeedback.lightImpact();
    setState(() => _isPrivateProfile = value);

    final success = await userService.setPrivateProfile(value);

    if (!success && mounted) {
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

  // ignore: unused_element
  Future<void> _toggleAnonymousMessages(bool value) async {
    HapticFeedback.lightImpact();
    setState(() => _isAnonymousMessagesEnabled = value);

    final service = AnonymousMessageSettingsService();
    await service.initialize();
    final success = await service.setEnabled(value);

    if (!success && mounted) {
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
          final bool isDesktop =
              constraints.maxWidth >= Responsive.tabletBreakpoint;
          final bool isTablet =
              constraints.maxWidth >= Responsive.mobileBreakpoint &&
                  constraints.maxWidth < Responsive.tabletBreakpoint;

          final double maxWidth = isDesktop
              ? 650
              : isTablet
                  ? 550
                  : double.infinity;

          final double verticalPadding = isDesktop ? 24 : 12;
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
                            bottom: verticalPadding + 100,
                            left: isDesktop ? 8 : 0,
                            right: isDesktop ? 8 : 0,
                          ),
                          children: [
                            // App Section - Always visible
                            _buildSectionHeader(context, 'App', isDesktop),
                            SizedBox(height: isDesktop ? 12 : 8),
                            _buildThemeToggleTile(context, isDesktop),
                            const SizedBox(height: AppDimensions.spacingMd),
                            // Uploads - only for logged in users
                            if (isLoggedIn) ...[
                              SettingsTiles.buildSettingsTile(
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
                              const SizedBox(height: AppDimensions.spacingMd),
                            ],
                            SettingsTiles.buildSettingsTile(
                              context: context,
                              icon: Icons.cleaning_services_outlined,
                              iconColor: AppTheme.grassGreen,
                              title: 'Clear Cache',
                              subtitle: 'Free up storage space',
                              isDesktop: isDesktop,
                              onTap: () {
                                final cacheService = locator<CacheService>();
                                cacheService.clearCache();
                                SettingsDialogs.showCacheConfirmationDialog(context);
                              },
                            ),
                            SizedBox(height: sectionSpacing),

                            // Privacy Section - Only for logged in users
                            if (isLoggedIn) ...[
                              _buildSectionHeader(
                                  context, 'Privacy', isDesktop),
                              SizedBox(height: isDesktop ? 12 : 8),
                              _buildPrivateProfileToggle(context, isDesktop),
                              SizedBox(height: sectionSpacing),
                            ],

                            // Account Section
                            _buildSectionHeader(context, 'Account', isDesktop),
                            SizedBox(height: isDesktop ? 12 : 8),
                            if (isLoggedIn) ...[
                              SettingsTiles.buildSettingsTile(
                                context: context,
                                icon: Icons.logout,
                                iconColor: AppTheme.honeyAmber,
                                title: 'Log Out',
                                subtitle: 'Sign out of your account',
                                isDesktop: isDesktop,
                                onTap: () => SettingsDialogs.showLogoutConfirmationDialog(context),
                              ),
                              const SizedBox(height: AppDimensions.spacingMd),
                              SettingsTiles.buildSettingsTile(
                                context: context,
                                icon: Icons.delete_forever,
                                iconColor: AppTheme.errorColor,
                                title: 'Delete Account',
                                subtitle: 'Permanently delete your account',
                                isDesktop: isDesktop,
                                onTap: () => SettingsDialogs.showDeleteConfirmationDialog(context),
                                isDestructive: true,
                              ),
                            ] else ...[
                              SettingsTiles.buildSettingsTile(
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

  Widget _buildThemeToggleTile(BuildContext context, bool isDesktop) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final isAutomatic = themeProvider.isAutomatic;
    final primaryColor = AppTheme.primaryColor;

    return Column(
      children: [
        // Auto Theme Toggle
        SettingsTiles.buildToggleCard(
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
          const SizedBox(height: AppDimensions.spacingMd),
          SettingsTiles.buildToggleCard(
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

  Widget _buildPrivateProfileToggle(BuildContext context, bool isDesktop) {
    final primaryColor = AppTheme.primaryColor;

    return HoverableCard(
      isDesktop: isDesktop,
      child: TransparentToolbox.buildCard(
        context: context,
        padding: SettingsTiles.getCardPadding(isDesktop),
        margin: SettingsTiles.getCardMargin(isDesktop),
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
}
