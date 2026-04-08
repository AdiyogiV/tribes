import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:aurogram/pages/helpers/flash.dart';
import 'package:aurogram/pages/login/init_user.dart';
import 'package:aurogram/pages/login/login.dart';
import 'package:aurogram/pages/onboarding/ftue_welcome.dart';
import 'package:aurogram/pages/tabs/grams.dart';
import 'package:aurogram/pages/tabs/holycow.dart';
import 'package:aurogram/pages/tabs/messages.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/pages/helpers/user_settings.dart';
import 'package:aurogram/pages/creation/creation_hub_page.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/services/media/media_compression_service.dart';
import 'package:aurogram/services/notification_service.dart';
import 'package:aurogram/services/onboarding_service.dart';
import 'package:aurogram/pages/tabs/widgets/notification_permission_sheet.dart';
import 'package:aurogram/pages/tabs/widgets/tab_bottom_nav.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/memory/memory_manager.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
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
    // PageView index 1 = HolyCow tab (selectedIndex 0)
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
    final shouldRequest = await AppBottomSheet.show<bool>(
      context,
      child: NotificationPermissionSheet(
        isDark: Theme.of(context).brightness == Brightness.dark,
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
    // Tab order: 0=HolyCow, 1=Grams, 2=Messages, 3=Profile
    Widget tab;
    switch (index) {
      case 0:
        tab = HolyCowPage(key: const PageStorageKey('holycow_auth'));
        break;
      case 1:
        tab = Grams(key: const PageStorageKey('grams_auth'));
        break;
      case 2:
        tab = MessagesPage();
        break;
      case 3:
        tab = UserProfilePage(uid: userId);
        break;
      default:
        tab = HolyCowPage(key: const PageStorageKey('holycow_auth'));
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
    // Tab order: 0=HolyCow, 1=Grams, 2=Login, 3=Settings
    Widget tab;
    switch (index) {
      case 0:
        tab = HolyCowPage(key: const PageStorageKey('holycow_unauth'));
        break;
      case 1:
        tab = Grams(key: const PageStorageKey('grams_unauth'));
        break;
      case 2:
        tab = const LoginPage(showBackButton: false);
        break;
      case 3:
        tab = const UserSettingsPage(showBackButton: false);
        break;
      default:
        tab = HolyCowPage(key: const PageStorageKey('holycow_unauth'));
    }

    // Cache for future use
    _cachedUnauthenticatedTabs[index] = tab;
    return tab;
  }

  // Reset caches when user auth state changes
  void _resetTabCaches() {
    // Clear caches except for non-auth related tabs
    // Keep holycow as it's not auth-dependent
    final keysToKeep = [0];

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
    if (mounted && _selectedIndex != index && index >= 0 && index <= 3) {
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
              // When switching to unauthenticated, show HolyCow (not Login/Settings)
              if (newStatus == Status.Unauthenticated && _selectedIndex > 1) {
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
              const SizedBox(height: AppDimensions.spacingXxl),
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
      // Add CreationHubPage as first page (index 0), then regular tabs (index 1-5)
      final tabs = isAuthenticated
          ? <Widget>[
              // Index 0: CreationHubPage (swipe right from HolyCow to access)
              const CreationHubPage(),
              // Index 1: HolyCow (actual tab index 0)
              _getAuthenticatedTab(0, auth.userId),
              // Index 2: Grams (actual tab index 1)
              _getAuthenticatedTab(1, auth.userId),
              // Index 3: Messages (actual tab index 2)
              _getAuthenticatedTab(2, auth.userId),
              // Index 4: Profile (actual tab index 3)
              _getAuthenticatedTab(3, auth.userId),
              // Index 5: Settings (swipe right from Profile to access, not a tab)
              const UserSettingsPage(showBackButton: false),
            ]
          : <Widget>[
              // Index 0: CreationHubPage (swipe right from HolyCow to access)
              const CreationHubPage(),
              // Index 1: HolyCow (actual tab index 0)
              _getUnauthenticatedTab(0),
              // Index 2: Grams (actual tab index 1)
              _getUnauthenticatedTab(1),
              // Index 3: Login (actual tab index 2)
              _getUnauthenticatedTab(2),
              // Index 4: Settings (actual tab index 3)
              _getUnauthenticatedTab(3),
            ];

      // Ensure PageController is initialized
      // PageView index 0 = CreationHubPage (not a tab)
      // PageView index 1 = HolyCow tab (selectedIndex 0)
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
          // PageView index 1 = HolyCow (tab index 0)
          // PageView index 2 = Grams (tab index 1)
          // PageView index 3 = Messages (tab index 2)
          // PageView index 4 = Profile (tab index 3)
          // PageView index 5 = Settings (not a tab, ignore)
          if (pageIndex == 0) {
            // User swiped to CreationHubPage - don't update selectedIndex
            // CreationHubPage is not a tab, it's a special page
            return;
          }

          if (pageIndex == 5 && isAuthenticated) {
            // User swiped to Settings - don't update selectedIndex
            // Settings is not a tab, it's a special page accessible via swipe
            return;
          }

          final tabIndex = pageIndex - 1;
          if (mounted &&
              _selectedIndex != tabIndex &&
              tabIndex >= 0 &&
              tabIndex <= 3) {
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

  // ignore: unused_element
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

  void _maybeConsumeInitialTab(AuthService auth) {
    if (_hasConsumedInitialTab || auth.initialTabIndex == null) {
      return;
    }

    final int tabIndex = auth.initialTabIndex!.clamp(0, 3).toInt();
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
