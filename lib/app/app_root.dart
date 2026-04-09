import 'dart:async' show unawaited;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/storage/memory_manager.dart';
import 'package:aurogram/core/network/network_manager.dart';
import 'package:aurogram/core/routing/page_factory.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/core/startup/startup_service.dart';
import 'package:aurogram/shared/services/cache_service.dart';
import 'package:aurogram/shared/providers/theme_provider.dart';
import 'package:aurogram/shared/presentation/widgets/flash.dart';
import 'package:aurogram/features/notifications/domain/notification_service.dart';
import 'package:aurogram/features/calling/domain/call_service.dart';
import 'package:aurogram/platform/platform.dart';
import 'package:aurogram/app/tabs/tab_handler.dart';
import 'package:aurogram/app/app_bootstrap.dart' show initialDependenciesLoaded;

/// Root widget — MaterialApp + lifecycle observer + deferred init.
class AppRoot extends StatefulWidget {
  final StartupService startupService;
  final GlobalKey<NavigatorState> navigatorKey;

  const AppRoot({
    super.key,
    required this.startupService,
    required this.navigatorKey,
  });

  @override
  AppRootState createState() => AppRootState();
}

class AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  bool _appInitialized = false;
  final NotificationService _notificationService = NotificationService();
  final CallService _callService = CallService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
  }

  // ── Deferred init ──────────────────────────────────────────────────────

  Future<void> _initializeApp() async {
    if (mounted && !_appInitialized) {
      setState(() => _appInitialized = true);
    }

    try {
      if (!initialDependenciesLoaded) {
        await WidgetsBinding.instance.endOfFrame;
      }

      unawaited(Future(() async {
        await _initializeNotifications();
        await _initializeNetwork();
        await WidgetsBinding.instance.endOfFrame;
        await _initializeMemory();
        _notificationService.cleanupOldNotifications();
        AppLogger.i('App initialization complete',
            category: LogCategory.general);
      }));
    } catch (e) {
      AppLogger.e('Error during app initialization',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      await _initializeCallService();
      if (!kIsWeb && PlatformServices.instance.isMobile) {
        await _notificationService.initialize(widget.navigatorKey);
        await widget.startupService.setupFirebaseMessaging(widget.navigatorKey);
      } else if (kIsWeb) {
        AppLogger.i(
            'Web platform: CallService initialized, skipping mobile notifications',
            category: LogCategory.messaging);
      }
    } catch (e) {
      AppLogger.w('Notification init error',
          category: LogCategory.messaging, data: {'error': e.toString()});
    }
  }

  Future<void> _initializeCallService() async {
    try {
      AppLogger.i('📞 Initializing CallService (isWeb: $kIsWeb)',
          category: LogCategory.general);

      await _callService.initialize();

      _callService.setMessageCallback((message) {
        final nav = widget.navigatorKey.currentState;
        if (nav != null) {
          ScaffoldMessenger.of(nav.context).showSnackBar(
            SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
          );
        }
      });

      _callService.onIncomingCall = (call) {
        AppLogger.i('📞 onIncomingCall triggered!',
            category: LogCategory.general,
            data: {
              'callId': call.id,
              'callerId': call.callerId,
              'callerName': call.callerName,
              'callType': call.type.toString(),
              'isWeb': kIsWeb,
            });

        final nav = widget.navigatorKey.currentState;
        if (nav == null) {
          AppLogger.e('📞 Cannot show incoming call: Navigator state is null!',
              category: LogCategory.general);
          return;
        }

        nav.push(
          PageFactory.route(RouteNames.incomingCall, arguments: {'call': call}),
        );
      };

      AppLogger.i('📞 CallService fully initialized',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('📞 CallService init error',
          category: LogCategory.general, error: e);
    }
  }

  Future<void> _initializeNetwork() async {
    try {
      await widget.startupService.setupDynamicLinks(widget.navigatorKey);
    } catch (e) {
      AppLogger.w('Network init error',
          category: LogCategory.network, data: {'error': e.toString()});
    }
  }

  Future<void> _initializeMemory() async {
    try {
      if (locator.isRegistered<CacheService>()) {
        unawaited(locator<CacheService>().pruneCache());
      }
    } catch (e) {
      AppLogger.w('Memory init error',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.startupService.handleAppLifecycleChange(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (locator.isRegistered<MemoryManager>()) {
        final mm = locator<MemoryManager>();
        final type = state == AppLifecycleState.paused
            ? CleanupType.normal
            : CleanupType.light;
        mm.clearMemoryCaches(cleanupType: type);
      }
    }

    if (state == AppLifecycleState.resumed) {
      if (locator.isRegistered<NetworkManager>()) {
        locator<NetworkManager>().checkInternetAccess().then((isOnline) {
          if (isOnline) {
            AppLogger.d('App resumed with internet, refreshing data',
                category: LogCategory.network);
          }
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      title: 'Aurogram',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getMaterialTheme(isDarkMode: isDark),
      builder: (context, child) => CupertinoTheme(
        data: AppTheme.getCupertinoTheme(isDarkMode: isDark),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.0),
          ),
          child: child!,
        ),
      ),
      home: _appInitialized ? TabHandler() : const FlashScreen(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationService.dispose();
    _callService.dispose();
    super.dispose();
  }
}
