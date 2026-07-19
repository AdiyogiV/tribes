import 'dart:async' show unawaited, runZonedGuarded, TimeoutException;
import 'package:aurogram/firebase_options.dart';
import 'package:aurogram/core/startup/startup_service.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_service.dart';
import 'package:aurogram/features/onboarding/domain/baba_onboarding_tools.dart';
import 'package:aurogram/features/auth/baba_login_tools.dart';
import 'package:aurogram/features/onboarding/domain/baba_identity_tools.dart';
import 'package:aurogram/features/astrology/domain/baba_astrology_tools.dart';
import 'package:aurogram/features/astrology/domain/baba_cosmic_tools.dart';
import 'package:aurogram/features/astrology/domain/baba_forecast_tools.dart';
import 'package:aurogram/features/astrology/domain/baba_circle_tools.dart';
import 'package:aurogram/features/ayurveda/domain/baba_ayurveda_tools.dart';
import 'package:aurogram/features/baba/domain/baba_memory_tools.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';
import 'package:aurogram/features/baba/domain/baba_tool_catalog.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/storage/app_performance.dart';
import 'package:aurogram/core/startup/app_initializer.dart';
import 'package:aurogram/core/network/network_optimizer.dart';
import 'package:aurogram/shared/services/media/media_compression_service.dart';
import 'package:aurogram/core/routing/dynamic_link_navigator.dart';
import 'package:aurogram/shared/services/watch_service.dart';
import 'package:aurogram/shared/services/local_store.dart';
import 'package:aurogram/features/ayurveda/domain/ayurveda_service.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/platform/platform.dart';
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/notifications/fcm_background_handler.dart';
import 'package:aurogram/app/app_providers.dart';
import 'package:aurogram/app/app_root.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

/// Tracks whether initial dependencies are loaded.
bool initialDependenciesLoaded = false;

/// Global navigator key shared across the app.
final GlobalKey<NavigatorState> navigatorKey = DynamicLinkNavigator.navigatorKey;

/// Two-phase app bootstrap:
///   Phase 1 (blocking): Firebase + core DI → runApp()
///   Phase 2 (background): Firestore config, auth, remaining services
class AppBootstrap {
  AppBootstrap._();

  static void run() {
    runZonedGuarded<Future<void>>(() async {
      final startupService = StartupService();
      startupService.recordStartTime();

      // In debug mode, use MarionetteBinding so AI agents (Wibey, Code Puppy)
      // can inspect widgets, tap, scroll, type, and take screenshots via MCP.
      // In release mode, use the standard binding — zero overhead.
      if (kDebugMode) {
        MarionetteBinding.ensureInitialized();
      } else {
        WidgetsFlutterBinding.ensureInitialized();
      }
      initializePlatformServices();
      _preWarmComponents();
      AppInitializer.setupErrorHandling();
      unawaited(AppPerformance.configurePlatformSettings());

      // Phase 1: blocking – Firebase + core DI
      await _initializeMinimalServices().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          AppLogger.w('Minimal services initialization timed out');
          throw TimeoutException('Minimal services timeout');
        },
      ).catchError((e) async {
        AppLogger.e('Error in minimal services, attempting fallback: $e');
        await _setupMinimalFallback();
      });

      // Show UI immediately
      runApp(AppProviders.wrap(
        child: AppRoot(
          startupService: startupService,
          navigatorKey: navigatorKey,
        ),
      ));

      // Phase 2: background – after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        startupService.recordFirstFrameTime();
        _completeAuthSetup();
        _completeInitialization(startupService);
      });
    }, (error, stack) {
      AppInitializer.handleUnhandledError(error, stack);
    });
  }

  // ── Pre-warm ───────────────────────────────────────────────────────────

  static void _preWarmComponents() {
    if (kIsWeb) {
      PaintingBinding.instance.imageCache.maximumSize = 100;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
    } else {
      // 50 images / 30MB — prevents constant re-decoding during scroll.
      // iOS may further tune in _configureIOSRendering; Android keeps these.
      PaintingBinding.instance.imageCache.maximumSize = 50;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024;
    }
    if (kReleaseMode && !kIsWeb) {
      PaintingBinding.instance.imageCache.clear();
    }
  }

  // ── Phase 1: Minimal services ──────────────────────────────────────────

  static Future<void> _initializeMinimalServices() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).catchError((error, stack) {
      AppLogger.e('Firebase initialization failed',
          category: LogCategory.general, error: error, stackTrace: stack);
      throw error;
    });

    // CRITICAL: Firestore settings must be applied IMMEDIATELY after
    // Firebase.initializeApp() and BEFORE any code touches
    // FirebaseFirestore.instance. The Firestore SDK locks settings on
    // first use and silently ignores any later .settings = assignment.
    // Previously this ran from _completeAuthSetup() (post-runApp), which
    // meant persistenceEnabled was never actually applied — leaving the
    // app with zero offline cache and a 10s wait on every cold read.
    _configureFirestoreSettings();

    // E2E test hook: disable phone-auth reCAPTCHA so headless automation can
    // sign in with a Firebase test number (fixed OTP). Gated by
    // --dart-define=E2E_TEST=true, so const-folded away entirely in real
    // builds — it can never affect production.
    if (const bool.fromEnvironment('E2E_TEST')) {
      try {
        await FirebaseAuth.instance
            .setSettings(appVerificationDisabledForTesting: true);
        AppLogger.w('E2E_TEST: phone-auth app verification DISABLED',
            category: LogCategory.general);
      } catch (e) {
        AppLogger.e('E2E_TEST setSettings failed',
            category: LogCategory.general, error: e);
      }
    }

    // App Check.
    //
    // DEBUG:
    //   • Apple (iOS/macOS) — handled NATIVELY in ios/Runner/AppDelegate.swift
    //     (AppCheckDebugProviderFactory installed BEFORE FirebaseApp.configure()).
    //     We must NOT also activate from Dart there — Dart runs after
    //     configure(), so it would double-activate and lose the startup race.
    //   • Android — NOT handled natively. Firebase auto-inits via its
    //     ContentProvider with no provider installed, so we activate the Debug
    //     provider here from Dart. Without this, Android debug builds log
    //     "No AppCheckProvider installed" and every token exchange starves
    //     Firestore listeners (→ userStream / dailyInsightStream timed out).
    // RELEASE: activate here with App Attest (iOS 14+) + DeviceCheck fallback
    //   (Apple) / Play Integrity (Android).
    //
    // PREREQ either way: the app MUST be registered under App Check in the
    // Firebase Console with a provider configured, otherwise every token
    // exchange returns 400 "App not registered" and starves Firestore
    // listeners (→ dailyInsightStream timed out).
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    // Skip Dart activation only on Apple debug builds (handled natively).
    final skipAppCheck = kIsWeb || (kDebugMode && !isAndroid);
    if (!skipAppCheck) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
        // Do not eagerly call getToken(), even without force-refresh. Firebase
        // consumers fetch lazily, while an eager cold-start exchange can add to
        // the SDK backoff after a debug-token or Play Integrity rejection.
        AppLogger.i('App Check activated',
            category: LogCategory.general, data: {'debug': kDebugMode});
      } catch (e) {
        AppLogger.w('App Check activation failed: $e',
            category: LogCategory.general);
      }
    } else {
      AppLogger.i('App Check: Dart activation skipped (Apple debug handled natively, or web)',
          category: LogCategory.general);
    }

    // FCM background handler (mobile only)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    await setupCoreDependencies();
  }

  // ── Phase 2a: Auth ─────────────────────────────────────────────────────

  static Future<void> _completeAuthSetup() async {
    try {
      // Register Baba's tool catalog once (core nav tools + onboarding
      // declarations). Composition root wires baba + features together so
      // baba/ never depends on a feature. Idempotent.
      BabaToolCatalog.registerCore();
      BabaToolRegistry.instance.registerAll(BabaOnboardingTools.declarations());
      BabaToolRegistry.instance.registerAll(BabaIdentityTools.declarations());
      // Baba can fill a guest's phone number into the login screen (declaration
      // global + stable; LoginPage binds the live handler while mounted).
      BabaToolRegistry.instance.registerAll(BabaLoginTools.declarations());
      // Baba's on-demand chart-facts tool (compact, avoids CX token bloat).
      BabaToolRegistry.instance.register(BabaAstrologyTools.declaration());
      // Depth tools: today's shared sky + live gochar (no auth), personal
      // Ayurveda, and cross-call memory. These give Baba fresh, varied material
      // every call instead of looping on the daily insight.
      BabaToolRegistry.instance.registerAll(BabaCosmicTools.declarations());
      BabaToolRegistry.instance.register(BabaAyurvedaTools.declaration());
      // Personal forecast: the SAME real day-alignments + woven story the wheel
      // shows, so voice + wheel + card never contradict each other.
      BabaToolRegistry.instance.register(BabaForecastTools.declaration());
      // The user's CIRCLE: friends' vibes + the transit "cosmic weather for the
      // two of you today" (same data the dashboard's friend cards show), so
      // Aurobhatt can talk about the bond, not just the user's own sky.
      BabaToolRegistry.instance.registerAll(BabaCircleTools.declarations());
      BabaToolRegistry.instance.register(BabaMemoryTools.declaration());
      // NOTE: knowledge/RAG is now NATIVE in CX - the 'vedicCanon' Data Store
      // Tool grounds meanings server-side (see voice-relay/tools/
      // provision_cx_datastore). No app-side knowledge tool needed.

      await OnboardingService().initialize();

      AppLogger.d('Marking AuthService as ready (background)',
          category: LogCategory.auth);
      locator<AuthService>().markReady();
      initialDependenciesLoaded = true;

      AppLogger.i('Auth setup completed in background',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Error completing auth setup: $e',
          category: LogCategory.general);
      initialDependenciesLoaded = true;
      try {
        locator<AuthService>().markReady();
      } catch (_) {
        AppLogger.w('Failed to mark auth ready after error',
            category: LogCategory.general);
      }
    }
  }

  static void _configureFirestoreSettings() {
    try {
      int cacheSizeBytes;
      if (kIsWeb) {
        cacheSizeBytes = 10 * 1024 * 1024; // 10 MB – browser quota limited
      } else if (PlatformServices.instance.isIOS) {
        cacheSizeBytes = 100 * 1024 * 1024; // 100 MB – was 20 MB, too small for chat-heavy app
      } else {
        cacheSizeBytes = 100 * 1024 * 1024; // 100 MB
      }

      FirebaseFirestore.instance.settings = Settings(
        // E2E_TEST: use in-memory cache (no IndexedDB) to dodge the Firebase-JS
        // 'INTERNAL ASSERTION FAILED (ca9)' persistence bug that fires in
        // fresh headless automation contexts. Prod keeps persistence on.
        persistenceEnabled: !const bool.fromEnvironment('E2E_TEST'),
        cacheSizeBytes: cacheSizeBytes,
        sslEnabled: !kIsWeb,
        // Force long-polling on web. Firestore's default WebChannel streaming
        // gets mangled by corporate/VPN proxies, which drives the firebase-js
        // 12.x 'INTERNAL ASSERTION FAILED (ca9)' state and blanks the app after
        // login. Long-polling is proxy-safe and fixes the blank-screen crash.
        webExperimentalForceLongPolling: kIsWeb ? true : null,
        ignoreUndefinedProperties: true,
      );
      AppLogger.d('Firestore configured',
          category: LogCategory.database,
          data: {'cacheSizeBytes': cacheSizeBytes, 'isWeb': kIsWeb});
    } catch (e) {
      AppLogger.w('Firestore configuration failed, using defaults',
          category: LogCategory.database, data: {'error': e.toString()});
    }
  }

  // ── Phase 2b: Remaining services ───────────────────────────────────────

  static Future<void> _completeInitialization(
      StartupService startupService) async {
    unawaited(Future(() async {
      try {
        await AppInitializer.initializeAppConfig();

        await WidgetsBinding.instance.endOfFrame;
        await setupRemainingDependencies();

        await WidgetsBinding.instance.endOfFrame;
        if (locator.isRegistered<NetworkOptimizer>()) {
          unawaited(locator<NetworkOptimizer>().initialize());
        }

        await WidgetsBinding.instance.endOfFrame;
        if (locator.isRegistered<MediaCompressionService>()) {
          locator<MediaCompressionService>().migrateAndCleanupUploads();
        }

        // Initialize local health DB (offline-first, before watch bridge)
        // sqflite is not available on web — skip initialization
        if (!kIsWeb) {
          await LocalStore.instance.initialize();
          LocalStore.instance.startSyncTimer();
        }

        // Initialize Apple Watch companion bridge (iOS only, no-op elsewhere)
        WatchService.instance.initialize();
        AyurvedaService().listenForWatchNadi();

        // Proactively load sky positions and send to watch.
        // This ensures applicationContext is populated BEFORE the watch
        // requests fullSync (watch waits 4s after launch).
        unawaited(_sendSkyToWatch());

        startupService.reportStartupPerformance();

        AppInitializer.safelyRunBackgroundTasks(startupService);
      } catch (e) {
        AppLogger.e('Error during background initialization: $e');
      }
    }));
  }

  // ── Watch sky sync ─────────────────────────────────────────────────────

  /// Load sky positions, muhurat, and panchang from cache/backend
  /// and push to watch via applicationContext BEFORE the watch asks.
  /// Also listens for fullSync requests at the app level.
  ///
  /// Note on the previous `isWatchPaired()` gate: the WCSession activation
  /// snapshot is racy at cold launch — `isWatchAppInstalled` is frequently
  /// `false` even when the watch app is installed. Gating the entire push
  /// on it meant a freshly-launched phone never populated
  /// `applicationContext`, and the watch's own `requestSync()` arrives before
  /// the phone is reachable, so the watch stayed empty until the next launch.
  ///
  /// Instead we always do the work on iOS:
  ///   * sky/muhurat fetches are needed for the in-app dashboard anyway.
  ///   * `updateApplicationContext` is cheap, queued by the OS, and survives
  ///     the watch app being uninstalled/asleep — no harm if there is no watch.
  ///   * the fullSync listener also handles re-pushes when
  ///     `sessionWatchStateDidChange` / `sessionReachabilityDidChange` fire
  ///     on the phone side (see WatchSessionManager.swift).
  static Future<void> _sendSkyToWatch() async {
    try {
      final skyService = SkyPositionsService();
      final skyOk = await skyService.fetchPositions();
      final muhuratOk = await skyService.fetchGlobalMuhurat();

      if (!skyOk) {
        AppLogger.w('Bootstrap: Sky fetch failed — watch will have no sky data',
            category: LogCategory.general);
      }

      // On non-iOS, sky/muhurat are still loaded above for in-app use.
      // Skip the watch bridge entirely (channel calls would just throw
      // MissingPluginException anyway).
      if (kIsWeb || !PlatformServices.instance.isIOS) return;

      Future<void> pushSky() async {
        if (!skyOk) return;
        final positions = skyService.getPositionsForDate(DateTime.now());
        if (positions != null && positions.isNotEmpty) {
          AppLogger.i('Bootstrap: Sending sky to watch',
              category: LogCategory.general,
              data: {'planetCount': positions.length});
          await WatchService.instance.sendSkyPositions(positions);
        }
        final panchang = skyService.getTodayPanchang();
        if (panchang != null) {
          AppLogger.i('Bootstrap: Sending panchang to watch',
              category: LogCategory.general);
          await WatchService.instance.sendPanchang(panchang);
        }
      }

      Future<void> pushMuhurat() async {
        if (!muhuratOk) return;
        final muhurat = skyService.globalMuhurat;
        if (muhurat == null) return;
        final windows = WatchService.extractMuhuratWindows(muhurat);
        if (windows.isNotEmpty) {
          AppLogger.i('Bootstrap: Sending muhurat to watch',
              category: LogCategory.general,
              data: {'windowCount': windows.length});
          await WatchService.instance.sendMuhurat(windows);
        }
      }

      // Initial push. applicationContext is persisted by WatchConnectivity
      // and delivered to the watch the next time it launches, so this is
      // safe to call regardless of current watch reachability/installation.
      await pushSky();
      await pushMuhurat();

      // Re-push on fullSync requests. These are emitted both by the watch
      // (when it explicitly requests data) and by the phone-side
      // WatchSessionManager when isWatchAppInstalled flips true or the
      // watch becomes reachable post-launch.
      WatchService.instance.onWatchData.listen((data) {
        if (data['request'] == 'fullSync') {
          AppLogger.i('Bootstrap: Watch requested fullSync',
              category: LogCategory.general);
          unawaited(pushSky());
          unawaited(pushMuhurat());
        }
      });
    } catch (e) {
      AppLogger.w('Bootstrap: Failed to send data to watch',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  // ── Fallback ───────────────────────────────────────────────────────────

  static Future<void> _setupMinimalFallback() async {
    try {
      AppLogger.w('Setting up minimal fallback configuration');
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      initialDependenciesLoaded = false;
      AppLogger.i('Minimal fallback setup complete');
    } catch (e) {
      AppLogger.e('Even minimal fallback failed: $e');
    }
  }
}
