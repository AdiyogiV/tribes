import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';

/// A utility class for optimizing network operations
class NetworkOptimizer {
  // Singleton instance
  static final NetworkOptimizer _instance = NetworkOptimizer._internal();
  factory NetworkOptimizer() => _instance;
  NetworkOptimizer._internal();

  // Network quality tracking
  bool _isLowBandwidth = false;
  bool _isHighLatency = false;
  List<ConnectivityResult> _currentConnectivity = [ConnectivityResult.none];

  // Network quality thresholds
  static const int _highLatencyThresholdMs = 300;
  static const double _lowBandwidthThresholdMbps = 1.0;

  // Batch request handling
  final Map<String, List<Function>> _pendingRequests = {};
  final Map<String, Timer> _batchTimers = {};

  // Subscription to connectivity changes
  StreamSubscription? _connectivitySubscription;

  /// Initialize the network optimizer
  Future<void> initialize() async {
    if (kIsWeb) return; // Web platform doesn't support all features

    try {
      // Initial connectivity check
      final connectivityResult = await Connectivity().checkConnectivity();
      _currentConnectivity = connectivityResult;

      // Subscribe to connectivity changes
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen((results) {
        _updateConnectivity(results);
      });

      // Perform network quality check
      _checkNetworkQuality();

      AppLogger.i('NetworkOptimizer initialized',
          category: LogCategory.network,
          data: {'connectivity': _currentConnectivity.toString()});
    } catch (e) {
      AppLogger.w('Failed to initialize NetworkOptimizer',
          category: LogCategory.network, data: {'error': e.toString()});
    }
  }

  /// Cleanup resources
  void dispose() {
    _connectivitySubscription?.cancel();
    for (var timer in _batchTimers.values) {
      timer.cancel();
    }
    _batchTimers.clear();
    _pendingRequests.clear();
  }

  /// Update connectivity status
  void _updateConnectivity(List<ConnectivityResult> results) {
    final previousConnectivity = _currentConnectivity;
    _currentConnectivity = results;

    // Log connectivity changes
    AppLogger.d(
        'Connectivity changed: $previousConnectivity -> $_currentConnectivity',
        category: LogCategory.network);

    // Check network quality on connection change
    if (!_hasNoConnectivity()) {
      _checkNetworkQuality();
    } else {
      // No connection
      _isLowBandwidth = true;
      _isHighLatency = true;
    }
  }

  /// Check if there is no connectivity
  bool _hasNoConnectivity() {
    return _currentConnectivity.isEmpty ||
        (_currentConnectivity.length == 1 &&
            _currentConnectivity.contains(ConnectivityResult.none));
  }

  /// Check network quality
  Future<void> _checkNetworkQuality() async {
    if (kIsWeb || _hasNoConnectivity()) return;

    try {
      // Check latency
      final latency = await _measureLatency();
      _isHighLatency = latency > _highLatencyThresholdMs;

      // Check bandwidth
      final bandwidth = await _estimateBandwidth();
      _isLowBandwidth = bandwidth < _lowBandwidthThresholdMbps;

      AppLogger.d('Network quality check',
          category: LogCategory.network,
          data: {
            'latency': '$latency ms',
            'bandwidth': '$bandwidth Mbps',
            'isHighLatency': _isHighLatency,
            'isLowBandwidth': _isLowBandwidth,
          });
    } catch (e) {
      AppLogger.w('Failed to check network quality',
          category: LogCategory.network, data: {'error': e.toString()});
    }
  }

  /// Measure network latency
  Future<int> _measureLatency() async {
    final String host = 'google.com'; // Use a reliable host
    try {
      final stopwatch = Stopwatch()..start();
      final result = await InternetAddress.lookup(host);
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        stopwatch.stop();
        return stopwatch.elapsedMilliseconds;
      }
      return _highLatencyThresholdMs +
          100; // Assume high latency if lookup fails
    } catch (e) {
      return _highLatencyThresholdMs + 100; // Assume high latency on error
    }
  }

  /// Estimate bandwidth (simple implementation)
  Future<double> _estimateBandwidth() async {
    // This is a simplified implementation
    // In a real app, you might download a small sample file and measure the time
    if (_hasWifiConnectivity()) {
      return 5.0; // Assume WiFi has decent bandwidth
    } else if (_hasMobileConnectivity()) {
      return 1.0; // Conservative estimate for mobile
    } else {
      return 0.5; // Poor connectivity
    }
  }

  /// Check if WiFi is available
  bool _hasWifiConnectivity() {
    return _currentConnectivity.contains(ConnectivityResult.wifi);
  }

  /// Check if mobile data is available
  bool _hasMobileConnectivity() {
    return _currentConnectivity.contains(ConnectivityResult.mobile);
  }

  /// Get image quality based on network conditions
  /// Returns a value between 0.0 (lowest) and 1.0 (highest)
  double getOptimalImageQuality() {
    if (_isLowBandwidth) {
      return 0.6; // Lower quality for low bandwidth
    } else if (_isHighLatency) {
      return 0.8; // Slightly lower quality for high latency
    } else {
      return 1.0; // Full quality for good connection
    }
  }

  /// Get video quality based on network conditions
  /// Returns a string like 'low', 'medium', 'high'
  String getOptimalVideoQuality() {
    if (_isLowBandwidth) {
      return 'low';
    } else if (_isHighLatency) {
      return 'medium';
    } else {
      return 'high';
    }
  }

  /// Should prefetch images based on network conditions
  bool shouldPrefetchImages() {
    return !_isLowBandwidth && !_isHighLatency && !_hasNoConnectivity();
  }

  /// Should parallelize requests based on network conditions
  int getOptimalParallelRequests() {
    if (_isLowBandwidth || _isHighLatency) {
      return 2; // Limit parallel requests on poor networks
    } else if (_hasWifiConnectivity()) {
      return 6; // More parallel requests on WiFi
    } else {
      return 4; // Default for decent connection
    }
  }

  /// Add a request to be batched with similar requests
  void batchRequest(String batchKey, Function callback, {Duration? delay}) {
    final batchDelay = delay ?? const Duration(milliseconds: 300);

    // Add request to pending batch
    _pendingRequests[batchKey] ??= [];
    _pendingRequests[batchKey]!.add(callback);

    // Cancel existing timer for this batch
    _batchTimers[batchKey]?.cancel();

    // Create new timer
    _batchTimers[batchKey] = Timer(batchDelay, () {
      // Execute batch
      final callbacks = _pendingRequests[batchKey]!;
      _pendingRequests[batchKey] = [];
      _batchTimers.remove(batchKey);

      AppLogger.d('Executing batched request',
          category: LogCategory.network,
          data: {'batchKey': batchKey, 'count': callbacks.length});

      // Call all callbacks
      for (final callback in callbacks) {
        try {
          callback();
        } catch (e) {
          AppLogger.w('Error in batched request',
              category: LogCategory.network, data: {'error': e.toString()});
        }
      }
    });
  }

  /// Check if network is connected
  bool get isConnected => !_hasNoConnectivity();

  /// Check if network is WiFi
  bool get isWifi => _hasWifiConnectivity();

  /// Check if network is mobile data
  bool get isMobile => _hasMobileConnectivity();

  /// Check if network has low bandwidth
  bool get isLowBandwidth => _isLowBandwidth;

  /// Check if network has high latency
  bool get isHighLatency => _isHighLatency;
}
