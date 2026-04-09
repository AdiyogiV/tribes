import 'package:flutter/foundation.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/services/media/audio/audio_recorder.dart';

// Conditional imports for mobile-only features
import 'dart:io' if (dart.library.html) 'package:aurogram/platform/io_stub.dart';
import 'package:permission_handler/permission_handler.dart'
    if (dart.library.html) 'package:aurogram/platform/permission_handler_stub.dart';
import 'package:geolocator/geolocator.dart'
    if (dart.library.html) 'package:aurogram/platform/geolocator_stub.dart';

/// Result of permission initialization
class AudioPermissionResult {
  final bool success;
  final String? errorMessage;

  const AudioPermissionResult({required this.success, this.errorMessage});

  static const AudioPermissionResult ok =
      AudioPermissionResult(success: true);

  factory AudioPermissionResult.error(String message) =>
      AudioPermissionResult(success: false, errorMessage: message);
}

/// Handles audio-related permission requests (microphone, speech, location)
/// and platform-specific initialization flows.
class AudioPermissions {
  const AudioPermissions._();

  /// Initialize permissions and recorder for the current platform.
  ///
  /// On mobile: requests microphone, speech (iOS), and location permissions,
  /// then initializes the recorder and speech-to-text availability.
  /// On web: only initializes the recorder (browser handles permissions).
  ///
  /// Returns [AudioPermissionResult] indicating success or an error message.
  static Future<AudioPermissionResult> initializePermissions({
    required AppAudioRecorder recorder,
  }) async {
    try {
      if (kIsWeb) {
        return _initializeForWeb(recorder: recorder);
      }

      // Request all necessary permissions first
      final micPermission = await Permission.microphone.request();
      if (micPermission != PermissionStatus.granted) {
        return AudioPermissionResult.error('Microphone permission denied');
      }

      // Request speech recognition permission explicitly on iOS
      if (Platform.isIOS) {
        final speechPermission = await Permission.speech.request();
        if (speechPermission != PermissionStatus.granted) {
          return AudioPermissionResult.error(
              'Speech recognition permission denied');
        }
      }

      // Request location permission upfront (non-blocking)
      await _requestLocationPermission();

      AppLogger.d('Audio permissions granted, initializing components',
          category: LogCategory.voice);

      // Initialize the cross-platform recorder
      final recorderInitialized = await recorder.initialize();
      if (!recorderInitialized) {
        return AudioPermissionResult.error(
            'Audio recording permission denied');
      }

      return AudioPermissionResult.ok;
    } catch (e) {
      AppLogger.e('Failed to initialize audio permissions',
          category: LogCategory.voice, error: e);
      return AudioPermissionResult.error('Failed to initialize: $e');
    }
  }

  /// Web-specific initialization
  static Future<AudioPermissionResult> _initializeForWeb({
    required AppAudioRecorder recorder,
  }) async {
    try {
      final recorderInitialized = await recorder.initialize();
      if (!recorderInitialized) {
        return AudioPermissionResult.error('Microphone permission denied');
      }

      AppLogger.d('Web audio service initialized (speech-to-text disabled)',
          category: LogCategory.voice);
      return AudioPermissionResult.ok;
    } catch (e) {
      AppLogger.e('Failed to initialize web audio service',
          category: LogCategory.voice, error: e);
      return AudioPermissionResult.error('Failed to initialize: $e');
    }
  }

  /// Request location permission upfront (non-blocking).
  ///
  /// This prevents the location permission dialog from interrupting
  /// audio processing later.
  static Future<void> _requestLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.d('Location services disabled, skipping permission request',
            category: LogCategory.voice);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.d('Location permission denied (optional)',
              category: LogCategory.voice);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.d('Location permission permanently denied (optional)',
            category: LogCategory.voice);
        return;
      }

      AppLogger.d('Location permission granted', category: LogCategory.voice);
    } catch (e) {
      // Location is optional - don't fail audio init if this errors
      AppLogger.d('Location permission check failed (optional): $e',
          category: LogCategory.voice);
    }
  }
}
