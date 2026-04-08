import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:aurogram/core/config/app_config.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Extension on Stream to add debounce functionality
extension StreamDebounceExtension<T> on Stream<T> {
  /// Debounces a stream to emit values after a delay
  Stream<T> debounce(Duration duration) {
    Timer? timer;
    return transform(
      StreamTransformer<T, T>.fromHandlers(
        handleData: (data, sink) {
          timer?.cancel();
          timer = Timer(duration, () => sink.add(data));
        },
        handleDone: (sink) {
          timer?.cancel();
          sink.close();
        },
      ),
    );
  }
}

/// Network connection type
enum NetworkType {
  wifi,
  mobile,
  none,
  unknown,
}

/// Manages network connectivity and optimizes network requests
class NetworkManager {
  // Singleton instance
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  // Current network status
  NetworkType _currentNetworkType = NetworkType.unknown;
  bool _isOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Stream controllers to notify listeners of network changes
  final _networkStatusController = StreamController<NetworkType>.broadcast();
  final _onlineStatusController = StreamController<bool>.broadcast();

  /// Initialize the network manager
  Future<void> initialize() async {
    try {
      // Start connectivity monitoring first
      await initializeConnectivityListeners();

      // Set initial state to prevent UI jumping back and forth
      // Optimistically assume we're online during initialization for WiFi and mobile connections
      _isOnline = _currentNetworkType == NetworkType.wifi ||
          _currentNetworkType == NetworkType.mobile;

      // Only if we think we're connected, verify with an internet check
      if (_isOnline) {
        // Schedule an internet check without blocking the UI
        _scheduleInternetCheck(initialCheck: true);
      }

      AppLogger.i('Network manager initialized',
          category: LogCategory.network,
          data: {
            'isOnline': _isOnline,
            'networkType': _currentNetworkType.toString()
          });
    } catch (e) {
      AppLogger.e('Error initializing network manager',
          category: LogCategory.network, error: e);
    }
  }

  /// Initialize connectivity monitoring
  Future<void> initializeConnectivityListeners() async {
    // Cancel any existing subscription to avoid duplicates
    _connectivitySubscription?.cancel();

    // Get initial connectivity state immediately
    try {
      final results = await Connectivity().checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      AppLogger.w('Error checking initial connectivity',
          category: LogCategory.network, data: {'error': e.toString()});
      // Default to unknown
      _currentNetworkType = NetworkType.unknown;
    }

    // Listen for connectivity changes with debounce to avoid rapid toggling
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .debounce(const Duration(milliseconds: 500))
        .listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });

    // Start less frequent periodic internet checks
    _startPeriodicInternetChecks();
  }

  // ELIMINATED: No timer needed for pure reactive architecture

  /// ELIMINATED: No periodic internet checks needed (PURE REACTIVE APPROACH)
  /// Internet status is now determined by:
  /// 1. Connectivity change events (primary detection)
  /// 2. App lifecycle events (when resuming)
  /// 3. Network request failures (future enhancement)
  void _startPeriodicInternetChecks() {
    // NO-OP: Pure reactive network detection, no timers needed
    AppLogger.i('Network manager using pure reactive detection (no timers)',
        category: LogCategory.network);
  }

  /// Update connection status and notify listeners
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    NetworkType prevNetworkType = _currentNetworkType;
    bool prevIsOnline = _isOnline;

    // Use the first result or default to none if empty
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;

    switch (result) {
      case ConnectivityResult.wifi:
        _currentNetworkType = NetworkType.wifi;
        // Optimistically set online for wifi connections
        _isOnline = true;
        break;
      case ConnectivityResult.mobile:
        _currentNetworkType = NetworkType.mobile;
        // Optimistically set online for mobile connections
        _isOnline = true;
        break;
      case ConnectivityResult.none:
        _currentNetworkType = NetworkType.none;
        _isOnline = false; // Definitely offline
        break;
      default:
        _currentNetworkType = NetworkType.unknown;
        // Try to determine online status for web platforms
        if (kIsWeb) {
          _isOnline = true; // Assume online for web unless proven otherwise
        } else {
          _isOnline = false;
        }
    }

    // For wifi and mobile, verify internet by actually checking connection
    if (result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile) {
      // Schedule the check without awaiting to avoid blocking UI
      _scheduleInternetCheck();
    }

    // Log changes in connection status
    if (prevNetworkType != _currentNetworkType) {
      AppLogger.i('Network connection changed',
          category: LogCategory.network,
          data: {
            'previous': prevNetworkType.toString(),
            'current': _currentNetworkType.toString()
          });

      _networkStatusController.add(_currentNetworkType);
    }

    // Log changes in online status
    if (prevIsOnline != _isOnline) {
      AppLogger.i('Online status changed',
          category: LogCategory.network, data: {'isOnline': _isOnline});

      _onlineStatusController.add(_isOnline);
    }
  }

  /// Schedule an internet check without blocking
  void _scheduleInternetCheck({bool initialCheck = false}) {
    // Use a longer delay for initial check to let the network stabilize
    final delay = initialCheck
        ? Duration(milliseconds: 500)
        : Duration(milliseconds: 200);

    // Use a delayed Future to perform the check
    Future.delayed(delay, () async {
      final hadInternet = _isOnline;

      // Optimistically assume online for initial check when on WiFi, verify later
      if (initialCheck && _currentNetworkType == NetworkType.wifi) {
        _isOnline = true;
      } else {
        _isOnline = await checkInternetAccess();
      }

      // If online status changed, notify listeners
      if (hadInternet != _isOnline) {
        AppLogger.i('Internet connectivity changed after verification',
            category: LogCategory.network, data: {'isOnline': _isOnline});
        _onlineStatusController.add(_isOnline);
      }

      // For initial check on WiFi, perform a second validation after a delay
      if (initialCheck && _currentNetworkType == NetworkType.wifi) {
        Future.delayed(Duration(seconds: 1), () async {
          final verifiedOnline = await checkInternetAccess();
          if (_isOnline != verifiedOnline) {
            _isOnline = verifiedOnline;
            AppLogger.i('Internet status updated after secondary verification',
                category: LogCategory.network, data: {'isOnline': _isOnline});
            _onlineStatusController.add(_isOnline);
          }
        });
      }
    });
  }

  /// Check if device is connected to the internet with optimized hosts
  Future<bool> checkInternetAccess() async {
    if (_currentNetworkType == NetworkType.none) return false;

    try {
      if (kIsWeb) {
        // For web, we don't have a reliable way to check internet
        // Just rely on connectivity status
        return _currentNetworkType != NetworkType.none;
      }

      // Use more reliable and faster hosts
      // Add Cloudflare's 1.1.1.1 which is optimized for speed
      final hosts = ['1.1.1.1', '8.8.8.8', 'google.com', 'apple.com'];

      // Reduce timeout from 3 seconds to 2 seconds for faster detection
      const timeout = Duration(seconds: 2);

      // Try each host in sequence with a short timeout
      for (final host in hosts) {
        try {
          final result = await InternetAddress.lookup(host).timeout(timeout);

          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            return true;
          }
        } catch (_) {
          // Ignore individual host errors
          continue;
        }
      }

      // If all checks fail, we're offline
      return false;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (e) {
      AppLogger.e('Error checking internet connection',
          category: LogCategory.network, error: e);
      return false;
    }
  }

  /// Get the current network type
  NetworkType get networkType => _currentNetworkType;

  /// Check if device is online
  bool get isOnline => _isOnline;

  /// Whether a large download should be started
  bool get canStartLargeDownload {
    if (!_isOnline) return false;

    final appConfig = AppConfig();

    // If on wifi, always allow
    if (_currentNetworkType == NetworkType.wifi) {
      return true;
    }

    // If on mobile, check app config
    if (_currentNetworkType == NetworkType.mobile) {
      return appConfig.getBool('allow_downloads_on_mobile', defaultValue: true);
    }

    return false;
  }

  /// Whether high-quality media should be loaded
  bool get shouldLoadHighQualityMedia {
    if (!_isOnline) return false;

    final appConfig = AppConfig();

    // On wifi, respect user settings
    if (_currentNetworkType == NetworkType.wifi) {
      return appConfig.getBool('load_high_quality_media_on_wifi',
          defaultValue: true);
    }

    // On mobile, also respect user settings but different default
    if (_currentNetworkType == NetworkType.mobile) {
      return appConfig.getBool('load_high_quality_media_on_mobile',
          defaultValue: false);
    }

    return false;
  }

  /// Get a stream of network status changes
  Stream<NetworkType> get onNetworkChanged => _networkStatusController.stream;

  /// Get a stream of online status changes
  Stream<bool> get onOnlineStatusChanged => _onlineStatusController.stream;

  /// Clean up resources
  void dispose() {
    _connectivitySubscription?.cancel();
    // Timer eliminated - using pure reactive architecture
    _networkStatusController.close();
    _onlineStatusController.close();
  }
}
