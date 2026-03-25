/// Platform abstraction layer for Aurogram
/// 
/// This module provides a unified interface for platform-specific features,
/// allowing the app to compile and run on both mobile and web platforms.
/// 
/// Usage:
/// ```dart
/// import 'package:aurogram/platform/platform.dart';
/// 
/// // In main.dart, before runApp:
/// initializePlatformServices();
/// 
/// // Then anywhere in the app:
/// if (PlatformServices.instance.isCallingSupported) {
///   // Show calling UI
/// }
/// ```

library platform;

export 'platform_interface.dart';

// Conditional export for initialization function
export 'platform_init_stub.dart'
    if (dart.library.io) 'platform_init_mobile.dart'
    if (dart.library.html) 'platform_init_web.dart';
