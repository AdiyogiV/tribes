import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:aurogram/core/logging/app_logger.dart';

enum SpeechState {
  idle,
  listening,
  error,
}

class SpeechRecognitionService extends ChangeNotifier {
  static final SpeechRecognitionService _instance =
      SpeechRecognitionService._internal();
  factory SpeechRecognitionService() => _instance;
  SpeechRecognitionService._internal();

  final SpeechToText _speechToText = SpeechToText();

  SpeechState _state = SpeechState.idle;
  String _currentText = '';
  String _errorMessage = '';
  bool _isInitialized = false;

  // Getters
  SpeechState get state => _state;
  String get currentText => _currentText;
  String get errorMessage => _errorMessage;
  bool get isListening => _state == SpeechState.listening;
  bool get hasError => _state == SpeechState.error;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final available = await _speechToText.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
      );

      if (available) {
        _isInitialized = true;
        AppLogger.i('Speech recognition initialized',
            category: LogCategory.voice);
        return true;
      } else {
        _setError('Speech not available on device');
        return false;
      }
    } catch (e) {
      _setError('Failed to initialize: $e');
      return false;
    }
  }

  /// Start listening
  Future<void> startListening({Function(String)? onResult}) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return;
    }

    if (_speechToText.isListening) {
      await stopListening();
    }

    try {
      _currentText = '';
      _state = SpeechState.listening;
      notifyListeners();

      await _speechToText.listen(
        onResult: (result) {
          _currentText = result.recognizedWords;

          // Call callback with current text
          if (onResult != null) {
            onResult(_currentText);
          }

          notifyListeners();
        },
        listenFor: const Duration(minutes: 5), // Reasonable limit
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );

      AppLogger.i('Started listening', category: LogCategory.voice);
    } catch (e) {
      _setError('Failed to start: $e');
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    _state = SpeechState.idle;
    notifyListeners();
    AppLogger.i('Stopped listening', category: LogCategory.voice);
  }

  /// Cancel listening
  Future<void> cancel() async {
    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }

    _state = SpeechState.idle;
    _currentText = '';
    notifyListeners();
  }

  /// Clear current text
  void clearText() {
    _currentText = '';
    notifyListeners();
  }

  /// Handle speech recognition errors
  void _handleError(dynamic error) {
    String message = error.toString();

    if (message.contains('error_assets_not_installed')) {
      message = 'Speech models not installed on device';
    } else if (message.contains('error_network')) {
      message = 'Network connection required';
    } else if (message.contains('error_no_match')) {
      message = 'No speech detected';
    } else {
      message = 'Speech recognition error';
    }

    _setError(message);
    AppLogger.e('Speech error: $error', category: LogCategory.voice);
  }

  /// Handle speech status changes
  void _handleStatus(String status) {
    AppLogger.d('Speech status: $status', category: LogCategory.voice);

    switch (status) {
      case 'listening':
        _state = SpeechState.listening;
        break;
      case 'notListening':
      case 'done':
        _state = SpeechState.idle;
        break;
    }
    notifyListeners();
  }

  /// Set error state
  void _setError(String message) {
    _errorMessage = message;
    _state = SpeechState.error;
    notifyListeners();

    // Auto-clear error after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (_state == SpeechState.error) {
        _state = SpeechState.idle;
        _errorMessage = '';
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _speechToText.cancel();
    super.dispose();
  }
}
