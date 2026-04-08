import 'package:flutter/foundation.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Global service to manage audio state across all video players
class GlobalAudioService extends ChangeNotifier {
  static final GlobalAudioService _instance = GlobalAudioService._internal();
  factory GlobalAudioService() => _instance;
  GlobalAudioService._internal();

  bool _isGloballyMuted = false;
  double _globalVolume = 1.0;

  /// Get the current global mute state
  bool get isGloballyMuted => _isGloballyMuted;

  /// Get the current global volume level
  double get globalVolume => _globalVolume;

  /// Toggle global mute state for all videos
  void toggleGlobalMute() {
    _isGloballyMuted = !_isGloballyMuted;

    AppLogger.i('Global audio state changed',
        category: LogCategory.media,
        data: {'isGloballyMuted': _isGloballyMuted});

    // Notify all listeners (video players) about the state change
    notifyListeners();
  }

  /// Set global mute state directly
  void setGlobalMute(bool muted) {
    if (_isGloballyMuted == muted) return;

    _isGloballyMuted = muted;

    AppLogger.i('Global audio mute set',
        category: LogCategory.media,
        data: {'isGloballyMuted': _isGloballyMuted});

    notifyListeners();
  }

  /// Set global volume level (0.0 to 1.0)
  void setGlobalVolume(double volume) {
    if (volume < 0.0 || volume > 1.0) {
      AppLogger.w('Invalid volume level',
          category: LogCategory.media, data: {'volume': volume});
      return;
    }

    _globalVolume = volume.clamp(0.0, 1.0);

    AppLogger.d('Global volume changed',
        category: LogCategory.media, data: {'globalVolume': _globalVolume});

    notifyListeners();
  }

  /// Get the effective volume (considering mute state)
  double getEffectiveVolume() {
    return _isGloballyMuted ? 0.0 : _globalVolume;
  }

  /// Initialize the service
  Future<void> initialize() async {
    try {
      AppLogger.i('Global Audio Service initialized successfully',
          category: LogCategory.general);
    } catch (e) {
      AppLogger.e('Failed to initialize Global Audio Service',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }
}
