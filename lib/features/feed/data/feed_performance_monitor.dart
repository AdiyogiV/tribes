import 'package:aurogram/features/feed/presentation/pages/feed_controller.dart';
import 'package:aurogram/shared/services/media/video_controller_pool.dart';
import 'package:aurogram/shared/services/media/audio_player_pool.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Performance metrics for a specific operation
class PerformanceMetric {
  final String operation;
  final int count;
  final double averageMs;
  final int totalMs;
  
  PerformanceMetric({
    required this.operation,
    required this.count,
    required this.averageMs,
    required this.totalMs,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'operation': operation,
      'count': count,
      'averageMs': averageMs.toStringAsFixed(1),
      'totalMs': totalMs,
    };
  }
}

/// Production-grade performance monitoring for feed
/// 
/// Tracks:
/// - Resource pool utilization
/// - Cache hit rates
/// - Initialization times
/// - Memory usage patterns
/// - Viewport efficiency
/// 
/// Used to validate that the viewport-aware architecture is working correctly.
class FeedPerformanceMonitor {
  // Singleton
  static final FeedPerformanceMonitor _instance = FeedPerformanceMonitor._internal();
  factory FeedPerformanceMonitor() => _instance;
  FeedPerformanceMonitor._internal();
  
  // Metrics tracking
  int _videoInitCount = 0;
  int _audioInitCount = 0;
  int _videoPoolHits = 0;
  int _audioPoolHits = 0;
  int _stateRestoreCount = 0;
  
  final List<int> _initTimes = [];
  DateTime? _sessionStartTime;
  
  /// Start monitoring session
  void startSession() {
    _sessionStartTime = DateTime.now();
    _videoInitCount = 0;
    _audioInitCount = 0;
    _videoPoolHits = 0;
    _audioPoolHits = 0;
    _stateRestoreCount = 0;
    _initTimes.clear();
    
    AppLogger.i(
      'FeedPerformanceMonitor: Session started',
      category: LogCategory.performance,
    );
  }
  
  /// Record video initialization
  void recordVideoInit({required bool fromPool, required int durationMs}) {
    _videoInitCount++;
    if (fromPool) _videoPoolHits++;
    _initTimes.add(durationMs);
  }
  
  /// Record audio initialization
  void recordAudioInit({required bool fromPool, required int durationMs}) {
    _audioInitCount++;
    if (fromPool) _audioPoolHits++;
    _initTimes.add(durationMs);
  }
  
  /// Record state restoration
  void recordStateRestore() {
    _stateRestoreCount++;
  }
  
  // recordKeepAliveTransition removed - ViewportTracker simplified
  
  /// Get comprehensive performance report
  Map<String, dynamic> getReport({
    FeedController? feedController,
  }) {
    final videoPool = VideoControllerPool();
    final audioPool = AudioPlayerPool();
    
    final sessionDuration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!)
        : Duration.zero;
    
    // Pool statistics
    final videoPoolStats = videoPool.getStats();
    final audioPoolStats = audioPool.getStats();
    
    // FeedController statistics
    final feedStats = feedController?.getStats() ?? {};
    
    // Calculate averages
    final avgInitTime = _initTimes.isEmpty
        ? 0.0
        : _initTimes.reduce((a, b) => a + b) / _initTimes.length;
    
    final videoPoolHitRate = _videoInitCount > 0
        ? (_videoPoolHits / _videoInitCount * 100)
        : 0.0;
    
    final audioPoolHitRate = _audioInitCount > 0
        ? (_audioPoolHits / _audioInitCount * 100)
        : 0.0;
    
    return {
      'session': {
        'duration': '${sessionDuration.inMinutes}m ${sessionDuration.inSeconds % 60}s',
        'durationMs': sessionDuration.inMilliseconds,
      },
      'initialization': {
        'videoInitCount': _videoInitCount,
        'audioInitCount': _audioInitCount,
        'totalInitCount': _videoInitCount + _audioInitCount,
        'avgInitTimeMs': avgInitTime.toStringAsFixed(1),
      },
      'pooling': {
        'video': {
          'hits': _videoPoolHits,
          'misses': _videoInitCount - _videoPoolHits,
          'hitRate': '${videoPoolHitRate.toStringAsFixed(1)}%',
          'currentSize': videoPoolStats['poolSize'],
          'maxSize': videoPoolStats['maxSize'],
          'utilization': '${videoPoolStats['utilizationPercent']}%',
        },
        'audio': {
          'hits': _audioPoolHits,
          'misses': _audioInitCount - _audioPoolHits,
          'hitRate': '${audioPoolHitRate.toStringAsFixed(1)}%',
          'currentSize': audioPoolStats['poolSize'],
          'maxSize': audioPoolStats['maxSize'],
          'utilization': '${audioPoolStats['utilizationPercent']}%',
        },
      },
      'state': {
        'activeStates': feedStats['activeStates'] ?? 0,
        'cachedStates': feedStats['cachedStates'] ?? 0,
        'totalStates': feedStats['totalStates'] ?? 0,
        'restoreCount': _stateRestoreCount,
      },
    };
  }
  
  /// Print comprehensive performance report to logs
  void logReport({
    FeedController? feedController,
  }) {
    final report = getReport(
      feedController: feedController,
    );
    
    // Simplified report - only log critical metrics
    final simplified = {
      'pool': {
        'video': '${report['pooling']['video']['currentSize']}/${report['pooling']['video']['maxSize']}',
        'audio': '${report['pooling']['audio']['currentSize']}/${report['pooling']['audio']['maxSize']}',
      },
      'states': '${report['state']['activeStates']}/${report['state']['totalStates']}',
    };
    
    AppLogger.i(
      '📊 Feed Status',
      category: LogCategory.performance,
      data: simplified,
    );
  }
  
  /// Get quick stats summary (single line)
  String getQuickSummary({
    FeedController? feedController,
  }) {
    final report = getReport(
      feedController: feedController,
    );
    
    final videoUtil = report['pooling']['video']['utilization'];
    final audioUtil = report['pooling']['audio']['utilization'];
    final initCount = report['initialization']['totalInitCount'];
    
    return 'Video:$videoUtil Audio:$audioUtil Inits:$initCount';
  }
  
  /// Reset all metrics
  void reset() {
    _videoInitCount = 0;
    _audioInitCount = 0;
    _videoPoolHits = 0;
    _audioPoolHits = 0;
    _stateRestoreCount = 0;
    _initTimes.clear();
    _sessionStartTime = null;
  }
}
