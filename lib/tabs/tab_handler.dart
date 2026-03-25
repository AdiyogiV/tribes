import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:aurogram/pages/helpers/flash.dart';
import 'package:aurogram/pages/login/init_user.dart';
import 'package:aurogram/pages/login/login.dart';
import 'package:aurogram/pages/onboarding/ftue_welcome.dart';
import 'package:aurogram/pages/tabs/feed.dart';
import 'package:aurogram/pages/tabs/grams.dart';
import 'package:aurogram/pages/tabs/holycow.dart';
import 'package:aurogram/pages/tabs/messages.dart';
import 'package:aurogram/pages/ai/recent_conversations_page.dart';
import 'package:aurogram/providers/ai_chat_provider.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/pages/helpers/user_settings.dart';
import 'package:aurogram/pages/helpers/gram_creation_page.dart'
    show SpaceCreationPage;
import 'package:aurogram/pages/creation/creation_hub_page.dart';
import 'package:aurogram/pages/uploads/uploads_page.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/services/media/media_compression_service.dart';
import 'package:aurogram/services/notification_service.dart';
import 'package:aurogram/services/onboarding_service.dart';
import 'package:aurogram/tabs/widgets/notification_permission_sheet.dart';
import 'package:aurogram/tabs/widgets/tab_bottom_nav.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/memory/memory_manager.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/layout/responsive_shell.dart';
import 'package:aurogram/utils/keyboard_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Main tab handler for the application
class TabHandler extends StatefulWidget {
  /// Global key to access TabHandlerState from anywhere (e.g., pushed pages)
  static final GlobalKey<TabHandlerState> globalKey =
      GlobalKey<TabHandlerState>();

  TabHandler({Key? key}) : super(key: key ?? globalKey);

  /// Static method to switch tabs from anywhere in the app
  static void switchTab(int index) {
    globalKey.currentState?.switchToTab(index);
  }

  @override
  TabHandlerState createState() => TabHandlerState();
}

class TabHandlerState extends State<TabHandler>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  int _selectedIndex = 0;
  StreamSubscription? _uploadProgressSubscription;
  bool _isInitialized = false;

  /// PageController for swipe navigation between tabs (mobile only)
  PageController? _pageController;

  /// Bar visibility: ValueNotifier so we don't setState during scroll (avoids scroll jank).
  final ValueNotifier<bool> _feedHidesBottomBarNotifier =
      ValueNotifier<bool>(false);

  // Flag to track if we've consumed the initial tab from auth service
  bool _hasConsumedInitialTab = false;

  // Flag to track if notification prompt check has been done post-FTUE
  bool _notificationPromptChecked = false;

  // Keep track of last active uploads to avoid unnecessary rebuilds
  int _lastActiveUploads = 0;

  // Track previous auth status to avoid repeated logs
  Status? _previousStatus;

  // Use PageStorageKey to preserve state of tabs when switching
  final PageStorageBucket _bucket = PageStorageBucket();

  // Lazy load tabs as they're accessed the first time
  final Map<int, Widget> _cachedAuthenticatedTabs = {};
  final Map<int, Widget> _cachedUnauthenticatedTabs = {};

  MediaCompressionService _getMediaService() {
    if (locator.isRegistered<MediaCompressionService>()) {
      return locator<MediaCompressionService>();
    }
    AppLogger.w('MediaCompressionService not registered, using fallback',
        category: LogCategory.general);
    return MediaCompressionService();
  }

  @override
  bool get wantKeepAlive => true; // Keep this widget alive to preserve state

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize PageController for mobile swipe navigation
    // PageView index 0 = CreationHubPage (not a tab)
    // PageView index 1 = Feed tab (selectedIndex 0)
    // So initialPage should be _selectedIndex + 1
    if (!kIsWeb) {
      _pageController = PageController(initialPage: _selectedIndex + 1);
    }

    // Defer initialization to after first frame to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTabHandler();
    });
  }

  Future<void> _initializeTabHandler() async {
    if (_isInitialized) return;

    // Start checking for active uploads after UI is visible
    _startUploadCheck();

    _isInitialized = true;
  }

  /// Check and show notification prompt after FTUE completion
  /// Called from build when we detect main UI is showing post-FTUE
  void _maybeShowNotificationPrompt() {
    AppLogger.i('_maybeShowNotificationPrompt called',
        category: LogCategory.general,
        data: {'alreadyChecked': _notificationPromptChecked});

    if (_notificationPromptChecked) return;

    final onboardingService = OnboardingService();
    final pending = onboardingService.notificationPromptPending;

    AppLogger.i('Notification prompt check',
        category: LogCategory.general,
        data: {
          'pending': pending,
          'initialized': onboardingService.isInitialized
        });

    if (!pending) return;

    _notificationPromptChecked = true;

    // Delay to let UI settle after FTUE navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPromptPending();
    });
  }

  /// Show notification permission prompt if user just completed onboarding
  Future<void> _checkNotificationPromptPending() async {
    final onboardingService = OnboardingService();

    // Only show if pending (set after onboarding completion)
    if (!onboardingService.notificationPromptPending) {
      AppLogger.i('Notification prompt not pending, skipping',
          category: LogCategory.general);
      return;
    }

    final notificationService = NotificationService();

    // Skip if already have permission
    final hasPermission = await notificationService.hasPermission();
    if (hasPermission) {
      AppLogger.i('Already have notification permission, clearing flag',
          category: LogCategory.general);
      await onboardingService.clearNotificationPromptPending();
      return;
    }

    // Small delay to let the UI settle after navigation
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    AppLogger.i('Showing notification permission prompt',
        category: LogCategory.general);

    // Show the notification permission prompt
    final shouldRequest = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => NotificationPermissionSheet(
        isDark: Theme.of(ctx).brightness == Brightness.dark,
      ),
    );

    // Clear the pending flag regardless of user choice
    await onboardingService.clearNotificationPromptPending();

    if (shouldRequest == true) {
      await notificationService.requestPermissions();
    }
  }

  void _startUploadCheck() {
    // TRULY EVENT-DRIVEN: Listen to MediaCompressionService progress stream (NO TIMER!)
    final mediaService = _getMediaService();

    // Cancel any existing subscription
    _uploadProgressSubscription?.cancel();

    // Subscribe to progress events and count active uploads reactively
    _uploadProgressSubscription = mediaService.progressStream.listen((event) {
      if (!mounted) return;
      _updateActiveUploadCount();
    });

    // Get initial count
    _updateActiveUploadCount();
  }

  Future<void> _updateActiveUploadCount() async {
    try {
      if (!mounted) return;

      final mediaService = _getMediaService();
      final uploads = await mediaService.getUploadProgress();

      final activeCount = uploads
          .where((item) =>
              item['status'] != 'completed' &&
              item['status'] != 'failed' &&
              item['status'] != 'cancelled')
          .length;

      // Only update state if count changed to avoid unnecessary rebuilds
      if (mounted && activeCount != _lastActiveUploads) {
        setState(() {
          _lastActiveUploads = activeCount;
        });
      }
    } catch (e) {
      AppLogger.e('Error checking uploads',
          category: LogCategory.general, error: e);
    }
  }

  // Get an authenticated tab with lazy instantiation
  Widget _getAuthenticatedTab(int index, String? userId) {
    // Return from cache if already instantiated
    if (_cachedAuthenticatedTabs.containsKey(index)) {
      return _cachedAuthenticatedTabs[index]!;
    }

    // Create tab based on index
    Widget tab;
    switch (index) {
      case 0:
        tab = Feed(
          key: const PageStorageKey('feed_auth'),
          onScrollHidesBottomBar: (hide) =>
              _feedHidesBottomBarNotifier.value = hide,
          barHiddenNotifier: _feedHidesBottomBarNotifier,
        );
        break;
      case 1:
        tab = MessagesPage();
        break;
      case 2:
        tab = HolyCowPage(key: const PageStorageKey('holycow_auth'));
        break;
      case 3:
        tab = Grams(key: const PageStorageKey('grams_auth'));
        break;
      case 4:
        tab = UserProfilePage(uid: userId);
        break;
      default:
        tab = Feed(
          key: const PageStorageKey('feed_auth'),
          onScrollHidesBottomBar: (hide) =>
              _feedHidesBottomBarNotifier.value = hide,
          barHiddenNotifier: _feedHidesBottomBarNotifier,
        );
    }

    // Cache for future use
    _cachedAuthenticatedTabs[index] = tab;
    return tab;
  }

  // Get an unauthenticated tab with lazy instantiation
  Widget _getUnauthenticatedTab(int index) {
    // Return from cache if already instantiated
    if (_cachedUnauthenticatedTabs.containsKey(index)) {
      return _cachedUnauthenticatedTabs[index]!;
    }

    // Create tab based on index
    Widget tab;
    switch (index) {
      case 0:
        tab = Feed(
          key: const PageStorageKey('feed_unauth'),
          onScrollHidesBottomBar: (hide) =>
              _feedHidesBottomBarNotifier.value = hide,
          barHiddenNotifier: _feedHidesBottomBarNotifier,
        );
        break;
      case 1:
        tab = const LoginPage(showBackButton: false);
        break;
      case 2:
        tab = HolyCowPage(key: const PageStorageKey('holycow_unauth'));
        break;
      case 3:
        tab = Grams(key: const PageStorageKey('grams_unauth'));
        break;
      case 4:
        tab = const UserSettingsPage(showBackButton: false);
        break;
      default:
        tab = Feed(
          key: const PageStorageKey('feed_unauth'),
          onScrollHidesBottomBar: (hide) =>
              _feedHidesBottomBarNotifier.value = hide,
          barHiddenNotifier: _feedHidesBottomBarNotifier,
        );
    }

    // Cache for future use
    _cachedUnauthenticatedTabs[index] = tab;
    return tab;
  }

  // Reset caches when user auth state changes
  void _resetTabCaches() {
    // Clear caches except for non-auth related tabs
    // Keep feed and discovery as they're not auth-dependent
    final keysToKeep = [0, 1];

    _cachedAuthenticatedTabs.removeWhere((key, _) => !keysToKeep.contains(key));
    _cachedUnauthenticatedTabs
        .removeWhere((key, _) => !keysToKeep.contains(key));

    // Free memory if available
    if (locator.isRegistered<MemoryManager>()) {
      locator<MemoryManager>()
          .clearMemoryCaches(cleanupType: CleanupType.light);
    }
  }

  @override
  void dispose() {
    _feedHidesBottomBarNotifier.dispose();
    _uploadProgressSubscription?.cancel();
    _pageController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // EVENT-DRIVEN: No timers needed, just refresh counts when app resumes
    if (state == AppLifecycleState.resumed) {
      // Refresh upload count when app is resumed
      _updateActiveUploadCount();
    } else if (state == AppLifecycleState.detached) {
      // Clean up stream subscription and resources when app is detached
      _uploadProgressSubscription?.cancel();
      _cachedAuthenticatedTabs.clear();
      _cachedUnauthenticatedTabs.clear();
    }
  }

  // NOTE: Permission requests removed from startup
  // All permissions now requested contextually when user needs the feature:
  // - Camera: When user tries to capture photo/video (PostComposer, AvatarPicker)
  // - Storage: Not needed with scoped storage on modern Android/iOS
  // - Microphone: When user tries to record audio (AudioInputService)
  // - Notifications: When user views Daily Insights (NotificationService)
  // This improves UX by not bombarding new users with permission prompts

  void _onItemTapped(int index, bool isAuthenticated) {
    // When logged out, last two tabs are Login and Settings (both tappable)
    if (mounted && _selectedIndex != index) {
      // On web, clear cached tabs that contain OverlayPortals to prevent
      // hit test errors from unmounted overlay portals
      if (kIsWeb) {
        // Clear the old tab from cache to fully dispose its OverlayPortals
        _cachedAuthenticatedTabs.remove(_selectedIndex);
        _cachedUnauthenticatedTabs.remove(_selectedIndex);
      }

      // On mobile, animate PageView to the selected tab
      // PageView index = tab index + 1 (because CreationHubPage is at index 0)
      if (!kIsWeb && _pageController != null && _pageController!.hasClients) {
        final pageViewIndex = index + 1; // Convert tab index to PageView index
        _pageController!.animateToPage(
          pageViewIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        setState(() {
          _selectedIndex = index;
        });
      }
    }
  }

  /// Public method to switch to a specific tab (used by other pages to navigate)
  void switchToTab(int index) {
    if (mounted && _selectedIndex != index && index >= 0 && index <= 4) {
      // On mobile, animate PageView to the selected tab
      // PageView index = tab index + 1 (because CreationHubPage is at index 0)
      if (!kIsWeb && _pageController != null && _pageController!.hasClients) {
        final pageViewIndex = index + 1; // Convert tab index to PageView index
        _pageController!.animateToPage(
          pageViewIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        setState(() {
          _selectedIndex = index;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Listen to both AuthService and OnboardingService for rebuilds
    return ListenableBuilder(
      listenable: OnboardingService(),
      builder: (context, _) {
        return Consumer<AuthService>(
          builder: (context, auth, child) {
            final Status newStatus = auth.status;

            // Log status for debugging startup issues
            if (_previousStatus != newStatus) {
              AppLogger.i('TabHandler: Auth status changed',
                  category: LogCategory.auth,
                  data: {
                    'from': _previousStatus?.toString(),
                    'to': newStatus.toString()
                  });
            }

            // Reset caches when status changes
            if (_previousStatus != newStatus) {
              _resetTabCaches();
              _previousStatus = newStatus;
              // Reset initial tab consumption flag when status changes
              _hasConsumedInitialTab = false;
              // When switching to unauthenticated, show Feed (not Login/Settings)
              if (newStatus == Status.Unauthenticated && _selectedIndex > 2) {
                _selectedIndex = 0;
              }

              // Trigger notification check ONCE on status change to Authenticated/Unauthenticated
              // This prevents the spam from calling it on every rebuild
              if ((newStatus == Status.Authenticated ||
                      newStatus == Status.Unauthenticated) &&
                  !_notificationPromptChecked) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _maybeShowNotificationPrompt();
                });
              }
            }

            // Consume initial tab index from auth service (set during onboarding)
            _maybeConsumeInitialTab(auth);

            // Handle auth status
            switch (newStatus) {
              case Status.Unauthenticated:
                // Check if first-time user should see FTUE
                final onboardingService = OnboardingService();
                if (onboardingService.shouldShowFtue()) {
                  return const FtueWelcome();
                }
                // Notification prompt now triggered via status change above
                return _buildTabsContainer(context, auth, false);
              case Status.Undetermined:
              case Status.Authenticating:
                // Return simple loading indicator instead of a separate FlashScreen
                return _buildLoadingScreen();
              case Status.Uninitialized:
                // New user needs to complete registration
                return InitUser();
              case Status.Authenticated:
                // Notification prompt now triggered via status change above
                return _buildTabsContainer(context, auth, true);
            }
          },
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    // On web, HTML splash in index.html already showed the branded splash screen
    // while Flutter downloaded. Show a minimal loading state to avoid double splash.
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldDarkColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 100,
                width: 100,
                child: Image.asset(
                  'assets/images/icon_transparent.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              // Subtle loading indicator - matches HTML splash position
              const ShimmerText(
                text: 'aurogram',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
              ),
            ],
          ),
        ),
      );
    }
    // On mobile, show the full animated FlashScreen
    return const FlashScreen();
  }

  Widget _buildTabsContainer(
      BuildContext context, AuthService auth, bool isAuthenticated) {
    // On web, avoid PageView/IndexedStack because it builds all children upfront.
    // TextFields in hidden tabs create OverlayPortal widgets that never get
    // laid out, causing hit test failures that block ALL clicks.
    // Instead, only render the currently selected tab on web.
    final Widget tabContent;
    if (kIsWeb) {
      // Web: Only build the visible tab to avoid OverlayPortal layout issues
      tabContent = isAuthenticated
          ? _getAuthenticatedTab(_selectedIndex, auth.userId)
          : _getUnauthenticatedTab(_selectedIndex);
    } else {
      // Mobile: Use PageView for swipe navigation between tabs
      // PageView automatically handles gesture conflicts with vertical scrolling
      // Add CreationHubPage as first page (index 0), then regular tabs (index 1-6)
      final tabs = isAuthenticated
          ? <Widget>[
              // Index 0: CreationHubPage (swipe right from Feed to access)
              const CreationHubPage(),
              // Index 1: Feed (actual tab index 0)
              _getAuthenticatedTab(0, auth.userId),
              // Index 2: Messages (actual tab index 1)
              _getAuthenticatedTab(1, auth.userId),
              // Index 3: HolyCow (actual tab index 2)
              _getAuthenticatedTab(2, auth.userId),
              // Index 4: Grams (actual tab index 3)
              _getAuthenticatedTab(3, auth.userId),
              // Index 5: Profile (actual tab index 4)
              _getAuthenticatedTab(4, auth.userId),
              // Index 6: Settings (swipe right from Profile to access, not a tab)
              const UserSettingsPage(showBackButton: false),
            ]
          : <Widget>[
              // Index 0: CreationHubPage (swipe right from Feed to access)
              const CreationHubPage(),
              // Index 1: Feed (actual tab index 0)
              _getUnauthenticatedTab(0),
              // Index 2: Login (actual tab index 1)
              _getUnauthenticatedTab(1),
              // Index 3: HolyCow (actual tab index 2)
              _getUnauthenticatedTab(2),
              // Index 4: Grams (actual tab index 3)
              _getUnauthenticatedTab(3),
              // Index 5: Settings (actual tab index 4)
              _getUnauthenticatedTab(4),
            ];

      // Ensure PageController is initialized
      // PageView index 0 = CreationHubPage (not a tab)
      // PageView index 1 = Feed tab (selectedIndex 0)
      // So initialPage should be _selectedIndex + 1
      if (_pageController == null) {
        _pageController = PageController(initialPage: _selectedIndex + 1);
      } else if (_pageController!.hasClients) {
        // If controller exists but page changed, update it
        final currentPage =
            _pageController!.page?.round() ?? (_selectedIndex + 1);
        if (currentPage != _selectedIndex + 1) {
          _pageController!.jumpToPage(_selectedIndex + 1);
        }
      }

      tabContent = PageView(
        controller: _pageController,
        onPageChanged: (pageIndex) {
          // Convert PageView index to tab index
          // PageView index 0 = CreationHubPage (not a tab, ignore)
          // PageView index 1 = Feed (tab index 0)
          // PageView index 2 = Messages (tab index 1)
          // PageView index 3 = HolyCow (tab index 2)
          // PageView index 4 = Grams (tab index 3)
          // PageView index 5 = Profile (tab index 4)
          // PageView index 6 = Settings (not a tab, ignore)
          if (pageIndex == 0) {
            // User swiped to CreationHubPage - don't update selectedIndex
            // CreationHubPage is not a tab, it's a special page
            return;
          }

          if (pageIndex == 6 && isAuthenticated) {
            // User swiped to Settings - don't update selectedIndex
            // Settings is not a tab, it's a special page accessible via swipe
            return;
          }

          final tabIndex = pageIndex - 1;
          if (mounted &&
              _selectedIndex != tabIndex &&
              tabIndex >= 0 &&
              tabIndex <= 4) {
            setState(() {
              _selectedIndex = tabIndex;
            });
          }
        },
        physics:
            const ClampingScrollPhysics(), // Enable swipe navigation, prevent going to negative indices
        children: tabs,
      );
    }

    // Bar visibility from notifier (no setState) so scroll stays smooth during hide/show
    final barNotifier = _feedHidesBottomBarNotifier;

    // Build the shell with responsive layout
    final shell = ResponsiveShell(
      selectedIndex: _selectedIndex,
      isAuthenticated: isAuthenticated,
      userId: auth.userId,
      onTabChanged: (index) => _onItemTapped(index, isAuthenticated),
      tabActionBuilder: _buildTabActionBuilder(context, isAuthenticated),
      mobileBuilder: (child) => Scaffold(
        extendBody: true,
        body: child,
        // Fixed-height slot so layout never changes during hide — avoids cancelling the active scroll gesture.
        bottomNavigationBar: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate proper height: bar (70px) + bottom padding (10px) + safe area
            final bottomPadding = MediaQuery.of(context).padding.bottom;
            final totalHeight = 70 + 10 + bottomPadding;

            return SizedBox(
              height: totalHeight,
              child: ClipRect(
                clipBehavior: Clip.hardEdge,
                child: ValueListenableBuilder<bool>(
                  valueListenable: barNotifier,
                  builder: (context, feedHidesBar, _) {
                    final feedBarHidden = feedHidesBar && _selectedIndex == 0;
                    return AnimatedSlide(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                      offset: feedBarHidden ? const Offset(0, 1) : Offset.zero,
                      child: TabBottomNav(
                        selectedIndex: _selectedIndex,
                        isAuthenticated: isAuthenticated,
                        userId: auth.userId,
                        onTap: (index) => _onItemTapped(index, isAuthenticated),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
      child: tabContent,
    );

    // Use PageStorage to maintain scroll position when switching tabs
    // Wrap with keyboard shortcuts for desktop web
    return PageStorage(
      bucket: _bucket,
      child: AppShortcuts.wrapWithShortcuts(
        onSwitchTab: (index) => _onItemTapped(index, isAuthenticated),
        onGoBack: () {
          // Handle escape key - go back if possible
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
        child: shell,
      ),
    );
  }

  Widget _webTap({
    required VoidCallback onTap,
    required Widget child,
  }) {
    if (!kIsWeb) {
      return InkWell(onTap: onTap, child: child);
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  /// Build tab-specific action builder for sidebar (desktop web only)
  /// Disabled - these actions are now available in tab headers and nested views
  Widget Function(bool isCollapsed)? _buildTabActionBuilder(
      BuildContext context, bool isAuthenticated) {
    // Actions removed from sidebar - available in tab-specific headers instead
    return null;
  }

  /// Build the action button for Grams tab (Create Gram + Upload indicator)
  Widget _buildGramsTabAction(BuildContext context, bool isCollapsed) {
    // When collapsed, show only icon button
    if (isCollapsed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Upload indicator (compact)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getMediaService().getUploadProgress(),
            builder: (context, snapshot) {
              final activeUploads = snapshot.data
                      ?.where((item) =>
                          item['status'] != 'completed' &&
                          item['status'] != 'failed' &&
                          item['status'] != 'cancelled')
                      .length ??
                  0;

              if (activeUploads > 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    child: _webTap(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => UploadsPage()),
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$activeUploads',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Create Gram icon button
          Material(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(10),
            child: _webTap(
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  CupertinoPageRoute(builder: (context) => SpaceCreationPage()),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(Icons.add, color: Colors.white, size: AppHeaderStyle.headerIconSize),
              ),
            ),
          ),
        ],
      );
    }

    // Expanded view - full buttons
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Upload progress indicator (if any active uploads)
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _getMediaService().getUploadProgress(),
          builder: (context, snapshot) {
            final activeUploads = snapshot.data
                    ?.where((item) =>
                        item['status'] != 'completed' &&
                        item['status'] != 'failed' &&
                        item['status'] != 'cancelled')
                    .length ??
                0;

            if (activeUploads > 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  child: _webTap(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => UploadsPage()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_upload,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$activeUploads uploading...',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        // Create Gram button
        _webTap(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              CupertinoPageRoute(builder: (context) => SpaceCreationPage()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 20, color: Colors.white),
                SizedBox(width: 8),
                Text('Create Gram', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build the action buttons for HolyCow tab (New Chat + History)
  Widget _buildHolyCowTabAction(BuildContext context, bool isCollapsed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // When collapsed, show only icon buttons
    if (isCollapsed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // New Chat icon button
          Consumer<AiChatProvider>(
            builder: (context, provider, _) {
              final hasRealConversation =
                  provider.messages.isNotEmpty && !provider.hasOnlyGreeting;

              if (!hasRealConversation) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: _webTap(
                    onTap: () {
                      provider.startNewSession();
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.add,
                          color: AppTheme.primaryColor, size: 22),
                    ),
                  ),
                ),
              );
            },
          ),
          // History icon button
          Material(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            child: _webTap(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RecentConversationsPage(),
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  Icons.history,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Expanded view - full buttons with labels
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // New Chat button
        Consumer<AiChatProvider>(
          builder: (context, provider, _) {
            final hasRealConversation =
                provider.messages.isNotEmpty && !provider.hasOnlyGreeting;

            if (!hasRealConversation) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _webTap(
                onTap: () {
                  provider.startNewSession();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'New Chat',
                        style: TextStyle(color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        // History button
        Material(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          child: _webTap(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RecentConversationsPage(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.black.withValues(alpha: 0.6),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Past Conversations',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.3),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _maybeConsumeInitialTab(AuthService auth) {
    if (_hasConsumedInitialTab || auth.initialTabIndex == null) {
      return;
    }

    final int tabIndex = auth.initialTabIndex!.clamp(0, 4).toInt();
    _hasConsumedInitialTab = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Use switchToTab to properly animate PageView
      switchToTab(tabIndex);
      auth.clearInitialTabIndex();
    });
  }

  // CreationHubPage is now integrated into PageView - no separate method needed
}
