import 'package:aurogram/services/startup/startup_auth.dart';
import 'package:aurogram/services/startup/startup_config.dart';
import 'package:aurogram/services/startup/startup_services.dart';

// Re-export the top-level background notification handler so existing
// references to the old file still compile.
export 'package:aurogram/services/startup/startup_services.dart'
    show onBackgroundNotificationTapped;

/// Handles app startup, Firebase initialization, and performance tracking.
///
/// Implementation is split across three mixins for maintainability:
/// - [StartupAuthMixin]     -- Firebase init, Crashlytics, Firestore config
/// - [StartupConfigMixin]   -- background tasks, updates, assets, lifecycle, perf
/// - [StartupServicesMixin] -- FCM, local notifications, deep links, messaging
class StartupService
    with StartupAuthMixin, StartupConfigMixin, StartupServicesMixin {
  // Performance tracking
  final DateTime _startTime = DateTime.now();
  DateTime? _firebaseInitTime;
  DateTime? _dependencyInitTime;
  DateTime? _firstFrameTime;

  // Record app startup time
  void recordStartTime() {
    // Already recorded in constructor
  }

  // Callback from StartupAuthMixin after Firebase is initialized
  @override
  void onFirebaseInitialized() {
    _firebaseInitTime = DateTime.now();
  }

  // Record Firebase initialization time (legacy external callers)
  void recordFirebaseInitTime() {
    _firebaseInitTime = DateTime.now();
  }

  // Record dependency initialization time
  void recordDependencyInitTime() {
    _dependencyInitTime = DateTime.now();
  }

  // Record first frame time
  void recordFirstFrameTime() {
    _firstFrameTime = DateTime.now();
  }

  Duration get totalStartupTime => _firstFrameTime != null
      ? _firstFrameTime!.difference(_startTime)
      : Duration.zero;

  Duration get firebaseInitDuration => _firebaseInitTime != null
      ? _firebaseInitTime!.difference(_startTime)
      : Duration.zero;

  /// Report startup performance metrics (delegates to mixin).
  void reportStartupPerformance() {
    reportStartupPerformanceWithTiming(
      totalStartupTime: totalStartupTime,
      firebaseInitDuration: firebaseInitDuration,
      firstFrameTime: _firstFrameTime,
      firebaseInitTime: _firebaseInitTime,
      dependencyInitTime: _dependencyInitTime,
    );
  }
}
