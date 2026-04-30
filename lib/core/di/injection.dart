import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:aurogram/shared/services/media/media_compression_service.dart';
import 'package:aurogram/shared/services/media/media_storage_service.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/features/feed/domain/post_service.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/features/spaces/domain/space_service.dart';
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/shared/services/cache_service.dart';
import 'package:aurogram/core/config/app_config.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/routing/app_navigator.dart';
import 'package:aurogram/core/storage/memory_manager.dart';
// Timer coordination removed - using event-driven architecture instead
import 'package:aurogram/core/network/network_manager.dart';
import 'package:aurogram/core/network/network_optimizer.dart';
import 'package:aurogram/features/feed/data/datasources/firebase_post_repository.dart';
import 'package:aurogram/features/feed/data/datasources/post_repository.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:aurogram/shared/services/locale_service.dart';
import 'package:aurogram/features/feed/data/datasources/space_db_service.dart';
import 'package:aurogram/shared/services/media/global_audio_service.dart';
import 'package:aurogram/features/feed/domain/feed_video_focus_service.dart';
import 'package:aurogram/shared/services/media/video_controller_pool.dart';
import 'package:aurogram/shared/services/media/audio_player_pool.dart';
import 'package:aurogram/features/feed/domain/feed_state_manager.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_service.dart';
import 'package:aurogram/shared/services/location_service.dart';
import 'package:aurogram/shared/services/media/audio_input_service.dart';
import 'package:aurogram/shared/services/batch_data_loader.dart';
import 'package:aurogram/core/routing/dynamic_link_navigator.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/shared/data/repositories/notification_repository.dart';

// Global GetIt instance
final GetIt locator = GetIt.instance;

// Flag to track dependencies setup
bool _coreSetupComplete = false;
bool _fullSetupComplete = false;

/// Initialize core services required for app startup
Future<void> setupCoreDependencies() async {
  try {
    // Skip if already initialized
    if (_coreSetupComplete) {
      AppLogger.d('Core dependencies already initialized',
          category: LogCategory.general);
      return;
    }

    AppLogger.i('Initializing core dependencies',
        category: LogCategory.general);

    // Firebase Auth and Firestore - core dependencies
    locator.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);
    locator.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);

    // Core utilities needed immediately
    // Use the SAME navigator key from DynamicLinkNavigator to avoid duplicate GlobalKey errors
    final navigatorKey = DynamicLinkNavigator.navigatorKey;

    // Register logger first since it's used by other services
    if (!locator.isRegistered<AppLogger>()) {
      final appLogger = AppLogger();
      locator.registerSingleton<AppLogger>(appLogger);
    }

    // Log platform information
    AppLogger.i('Platform information',
        category: LogCategory.general,
        data: {'platform': kIsWeb ? 'Web' : 'Native'});

    // Essential navigation
    locator.registerSingleton<GlobalKey<NavigatorState>>(navigatorKey);
    final appNavigator = AppNavigator(navigatorKey);
    locator.registerSingleton<AppNavigator>(appNavigator);

    // Register minimal config needed for startup
    final appConfig = AppConfig();
    locator.registerSingleton<AppConfig>(appConfig);

    // Basic memory management
    final memoryManager = MemoryManager();
    locator.registerSingleton<MemoryManager>(memoryManager);
    memoryManager.initialize(enableAutoCleanup: false); // Minimal init first

    // Register network manager - start network detection early
    final networkManager = NetworkManager();
    locator.registerSingleton<NetworkManager>(networkManager);

    // Register network optimizer but don't initialize yet
    locator.registerSingleton<NetworkOptimizer>(NetworkOptimizer());

    // Timer coordination removed - replaced with event-driven architecture

    // Register UserRepository early — single source of truth for user lookups
    if (!locator.isRegistered<UserRepository>()) {
      locator.registerLazySingleton<UserRepository>(
        () => UserRepository(),
        dispose: (repo) => repo.dispose(),
      );
    }

    // Register NotificationRepository — wraps notifications subcollection
    if (!locator.isRegistered<NotificationRepository>()) {
      locator.registerLazySingleton<NotificationRepository>(
          () => NotificationRepository());
    }

    // Register UserService early as AuthService depends on it
    if (!locator.isRegistered<UserService>()) {
      locator.registerLazySingleton<UserService>(() => UserService());
    }

    // Register auth service - needed for initial screens
    if (!locator.isRegistered<AuthService>()) {
      locator.registerSingleton<AuthService>(AuthService.instance());
    }

    // PostDbService is needed by early widgets (PostSwitcher, tiles).
    if (!locator.isRegistered<PostDbService>()) {
      locator.registerLazySingleton<PostDbService>(() => PostDbService());
    }

    // MediaCompressionService is touched by TabHandler at first build (well
    // before setupRemainingDependencies runs) — register it here so the
    // 'not registered, using fallback' warning never fires. It's a lazy
    // singleton so registration is essentially free.
    if (!locator.isRegistered<MediaCompressionService>()) {
      locator.registerLazySingleton<MediaCompressionService>(
          () => MediaCompressionService());
    }

    // Register AI Chat services early for provider initialization with timeout safety
    locator.registerLazySingleton<LocationService>(() {
      AppLogger.d('Initializing LocationService lazily');
      return LocationService();
    });
    locator.registerLazySingleton<AiChatService>(() {
      AppLogger.d('Initializing AiChatService lazily');
      return AiChatService();
    });

    _coreSetupComplete = true;
    AppLogger.i('Core dependencies initialized', category: LogCategory.general);
  } catch (e, stack) {
    AppLogger.e('Error initializing core dependencies',
        category: LogCategory.general, error: e, stackTrace: stack);

    // Rethrow in debug mode
    if (kDebugMode) rethrow;
  }
}

/// Initialize all remaining services
Future<void> setupRemainingDependencies() async {
  try {
    // Skip if already fully initialized
    if (_fullSetupComplete) {
      AppLogger.d('Full dependencies already initialized',
          category: LogCategory.general);
      return;
    }

    // Make sure core dependencies are initialized
    if (!_coreSetupComplete) {
      await setupCoreDependencies();
    }

    AppLogger.i('Initializing remaining dependencies',
        category: LogCategory.general);

    // Register Firebase Storage and Analytics now
    if (!locator.isRegistered<FirebaseStorage>()) {
      locator.registerSingleton<FirebaseStorage>(FirebaseStorage.instance);
    }

    // Analytics can be initialized later
    if (!locator.isRegistered<FirebaseAnalytics>()) {
      locator.registerSingleton<FirebaseAnalytics>(FirebaseAnalytics.instance);
    }

    // Enable full memory manager features now
    final memoryManager = locator<MemoryManager>();
    await memoryManager.enableFullFeatures();

    // Initialize cache services
    await _registerCacheService();

    // Timer coordination removed - using event-driven patterns instead

    // CacheOptimizer periodic cleanup removed - cache cleanup now event-driven

    // Services that have no dependencies - register lazily for better performance
    locator.registerLazySingleton<MediaStorageService>(
        () => MediaStorageService());
    // MediaCompressionService is now registered earlier in
    // setupCoreDependencies() (see comment there). Skip re-registration to
    // avoid get_it 'already registered' assertion in dev.
    if (!locator.isRegistered<MediaCompressionService>()) {
      locator.registerLazySingleton<MediaCompressionService>(
          () => MediaCompressionService());
    }
    if (!locator.isRegistered<PostDbService>()) {
      locator.registerLazySingleton<PostDbService>(() => PostDbService());
    }
    locator.registerLazySingleton<SpaceService>(() => SpaceService());
    // Register SpaceDbService
    locator.registerLazySingleton<SpaceDbService>(() => SpaceDbService());

    // Register Global Audio Service for managing global mute state
    locator
        .registerLazySingleton<GlobalAudioService>(() => GlobalAudioService());

    // Register Feed Video Focus Service (one playing video at a time in feed)
    locator.registerLazySingleton<FeedVideoFocusService>(
        () => FeedVideoFocusService());

    // Register resource pools for memory management (production-grade approach)
    locator.registerSingleton<VideoControllerPool>(VideoControllerPool());
    locator.registerSingleton<AudioPlayerPool>(AudioPlayerPool());
    locator.registerSingleton<FeedStateManager>(FeedStateManager());

    // Register batch data loader for optimized counter and user/space loading
    locator.registerSingleton<BatchDataLoader>(BatchDataLoader());

    // Register Audio Input Service for voice messages
    // NOTE: Don't auto-initialize here - permission should be requested only when user
    // actually tries to use voice features (better UX - no early permission prompts)
    if (!locator.isRegistered<AudioInputService>()) {
      locator
          .registerLazySingleton<AudioInputService>(() => AudioInputService());
      AppLogger.d(
          'Audio input service registered (will initialize on first use)',
          category: LogCategory.voice);
    }

    // Services with dependencies
    locator.registerLazySingleton<PostService>(() => PostService(
          user: FirebaseAuth.instance.currentUser,
          compressionService: locator<MediaCompressionService>(),
          storageService: locator<MediaStorageService>(),
          postDbService: locator<PostDbService>(),
          firestore: locator<FirebaseFirestore>(),
        ));

    // Repositories
    locator
        .registerLazySingleton<PostRepository>(() => FirebasePostRepository());

    // Register localization services
    _setupLocalizationServices();

    _fullSetupComplete = true;
    AppLogger.i('Full dependencies initialization complete',
        category: LogCategory.general);
  } catch (e, stack) {
    AppLogger.e('Error initializing remaining dependencies',
        category: LogCategory.general, error: e, stackTrace: stack);

    // Don't rethrow to allow partial initialization
  }
}

/// Legacy method for backward compatibility
Future<void> setupDependencies() async {
  if (_fullSetupComplete) return;

  // First set up core dependencies
  await setupCoreDependencies();

  // Then set up remaining dependencies
  await setupRemainingDependencies();
}

/// Register the cache service
Future<void> _registerCacheService() async {
  if (!locator.isRegistered<CacheService>()) {
    locator.registerSingleton<CacheService>(
      CacheService(
        memoryManager: locator<MemoryManager>(),
      ),
    );
  }
}

/// Sets up localization services
void _setupLocalizationServices() {
  // Register Locale Service
  if (!locator.isRegistered<LocaleService>()) {
    locator.registerSingletonAsync<LocaleService>(() async {
      final service = LocaleService();
      await service.initialize();
      return service;
    });
  }
}

/// Gets a registered dependency
T getDependency<T extends Object>() {
  return locator<T>();
}

/// Checks if a dependency is registered
bool isRegistered<T extends Object>() {
  return locator.isRegistered<T>();
}

/// Convenience getters for commonly accessed dependencies
AppNavigator get navigator => locator<AppNavigator>();
AppLogger get logger => locator<AppLogger>();
PostRepository get postRepository => locator<PostRepository>();
AuthService get authService => locator<AuthService>();
PostService get postService => locator<PostService>();
UserService get userService => locator<UserService>();
UserRepository get userRepo => locator<UserRepository>();
