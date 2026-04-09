import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/services/media/media_storage_service.dart';
import 'package:aurogram/shared/services/media/audio/audio_recorder.dart';
import 'package:aurogram/shared/services/media/audio_input_models.dart';
import 'package:aurogram/shared/services/media/audio_permissions.dart';
import 'package:aurogram/shared/services/media/audio_recording_handler.dart';

// Re-export models so existing importers of audio_input_service.dart still work
export 'package:aurogram/shared/services/media/audio_input_models.dart';

// Conditional imports for mobile-only features
// ignore: unused_import
import 'dart:io' if (dart.library.html) 'package:aurogram/platform/io_stub.dart';

/// Enhanced service that simultaneously records audio and transcribes speech
/// Uses en_IN locale for optimal English/Hindi/Hinglish code-switching support
class AudioInputService extends ChangeNotifier {
  static final AudioInputService _instance = AudioInputService._internal();
  factory AudioInputService() => _instance;
  AudioInputService._internal();

  // Speech-to-text service
  final SpeechToText _speechToText = SpeechToText();

  // Audio recording handler — manages recorder, file I/O, uploads, cleanup
  final AudioRecordingHandler _recordingHandler = AudioRecordingHandler(
    recorder: AppAudioRecorder(),
    storageService: MediaStorageService(),
  );

  // Web-specific: store audio bytes from recording
  Uint8List? _webAudioBytes;

  // State management
  AudioInputState _state = AudioInputState.idle;
  String _currentTranscript = '';
  String? _currentAudioPath;
  String _errorMessage = '';
  bool _isInitialized = false;
  DateTime? _recordingStartTime;
  bool _hasSpeechRecognitionError = false;
  String _speechErrorType = '';

  // Completion callback
  Function(AudioInputResult)? _onResult;

  // Getters
  AudioInputState get state => _state;
  String get currentTranscript => _currentTranscript;
  String get errorMessage => _errorMessage;
  bool get isRecording => _state == AudioInputState.recording;
  bool get isProcessing => _state == AudioInputState.processing;
  bool get hasError => _state == AudioInputState.error;
  bool get hasSpeechRecognitionError => _hasSpeechRecognitionError;
  String get speechErrorType => _speechErrorType;
  DateTime? get recordingStartTime => _recordingStartTime;

  /// Initialize both speech-to-text and audio recording
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Clean up any orphaned temp files from previous sessions (mobile only)
      if (!kIsWeb) {
        await _recordingHandler.cleanupTempFiles();
      }

      // Request permissions and initialize recorder via AudioPermissions
      final permResult = await AudioPermissions.initializePermissions(
        recorder: _recordingHandler.recorder,
      );

      if (!permResult.success) {
        _setError(permResult.errorMessage ?? 'Permission denied');
        return false;
      }

      // On web, skip speech-to-text (rely on Gemini for audio understanding)
      if (kIsWeb) {
        _isInitialized = true;
        return true;
      }

      // Initialize speech-to-text (mobile only)
      final speechAvailable = await _speechToText.initialize(
        onError: _handleSpeechError,
        onStatus: _handleSpeechStatus,
        debugLogging: kDebugMode,
      );

      if (!speechAvailable) {
        _setError('Speech recognition not available');
        return false;
      }

      _isInitialized = true;
      AppLogger.d('Audio service initialized', category: LogCategory.voice);
      return true;
    } catch (e) {
      AppLogger.e('Failed to initialize audio service',
          category: LogCategory.voice, error: e);
      _setError('Failed to initialize: $e');
      return false;
    }
  }

  /// Start recording audio and optionally speech recognition.
  /// Set [skipSpeechRecognition] to true when using Gemini for audio understanding
  /// (On Android, STT and audio recorder conflict for microphone access)
  Future<void> startRecording({
    Function(AudioInputResult)? onResult,
    Function(String)? onTranscriptUpdate,
    bool skipSpeechRecognition = true,
  }) async {
    final success = await initialize();
    if (!success) return;

    if (_state == AudioInputState.recording) {
      await stopRecording();
    }

    try {
      _onResult = onResult;
      _currentTranscript = '';
      _recordingStartTime = DateTime.now();
      _webAudioBytes = null;

      // Reset speech recognition error state
      _hasSpeechRecognitionError = false;
      _speechErrorType = '';

      if (kIsWeb) {
        // Web: use cross-platform recorder directly (no file path needed)
        final started = await _recordingHandler.recorder.startRecording();
        if (!started) {
          _setError('Failed to start audio recording');
          return;
        }
        AppLogger.i('🎙️ Web audio recording started',
            category: LogCategory.voice);
      } else {
        // Mobile: Get temporary file path for audio recording
        _currentAudioPath = await _recordingHandler.generateRecordingPath();

        // Start audio recording first
        final recordingStarted =
            await _recordingHandler.startAudioRecording(_currentAudioPath);
        if (!recordingStarted) {
          _setError('Failed to start audio recording');
          return;
        }

        // Only start speech recognition if NOT skipped (mobile only)
        if (!skipSpeechRecognition) {
          await _startSpeechRecognition(onTranscriptUpdate);
        } else {
          AppLogger.i(
              '🎙️ Audio-only recording mode (Gemini will understand speech)',
              category: LogCategory.voice);
        }
      }

      _state = AudioInputState.recording;
      notifyListeners();
    } catch (e) {
      AppLogger.e('Failed to start recording',
          category: LogCategory.voice, error: e);
      _setError('Failed to start recording: $e');
    }
  }

  /// Start speech recognition with en_IN locale (supports English/Hindi/Hinglish)
  Future<void> _startSpeechRecognition(
      Function(String)? onTranscriptUpdate) async {
    try {
      await _speechToText.listen(
        onResult: (result) {
          _currentTranscript = result.recognizedWords;

          AppLogger.d('🎤 "$_currentTranscript"',
              category: LogCategory.voice,
              data: {
                'final': result.finalResult,
                'confidence': result.confidence,
              });

          if (onTranscriptUpdate != null &&
              _currentTranscript.trim().isNotEmpty) {
            onTranscriptUpdate(_currentTranscript);
          }

          notifyListeners();
        },
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 10),
        localeId: 'en_IN',
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          enableHapticFeedback: true,
          autoPunctuation: true,
        ),
      );
    } catch (e) {
      AppLogger.e('Failed to start speech recognition',
          category: LogCategory.voice, error: e);
      _hasSpeechRecognitionError = true;
      _speechErrorType = 'startup_failed';
    }
  }

  /// Stop recording and transcription, then process the result
  Future<void> stopRecording() async {
    if (_state != AudioInputState.recording) {
      AppLogger.w('⚠️ stopRecording called but state is $_state',
          category: LogCategory.voice);
      return;
    }

    AppLogger.i('🛑 Stopping audio recording...', category: LogCategory.voice);

    try {
      _state = AudioInputState.processing;
      notifyListeners();

      // Calculate duration
      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero;

      if (kIsWeb) {
        _webAudioBytes = await _recordingHandler.stopRecording();

        AppLogger.i('✅ Web audio recording STOPPED',
            category: LogCategory.voice, data: {
              'bytesLength': _webAudioBytes?.length ?? 0,
              'duration': duration.inSeconds,
            });

        await _recordingHandler.processWebResults(
          audioBytes: _webAudioBytes,
          duration: duration,
          onResult: _onResult,
          onError: _setError,
          onAudioUrlUploaded: _onAudioUrlUploaded,
          onAudioUploadSkipped: _onAudioUploadSkipped,
        );
      } else {
        // Mobile: Stop speech-to-text
        if (_speechToText.isListening) {
          await _speechToText.stop();
        }

        // Stop audio recording (returns bytes)
        final audioBytes = await _recordingHandler.stopRecording();
        final audioPath = _currentAudioPath;

        // Save bytes to the expected file path
        if (audioBytes != null && audioBytes.isNotEmpty && audioPath != null) {
          await _recordingHandler.saveAudioToFile(audioBytes, audioPath);
        } else {
          AppLogger.w('⚠️ No audio bytes returned from recorder',
              category: LogCategory.voice, data: {
                'audioBytesNull': audioBytes == null,
                'audioBytesEmpty': audioBytes?.isEmpty ?? true,
                'audioPath': audioPath,
              });
        }

        AppLogger.i('✅ Audio recording STOPPED',
            category: LogCategory.voice, data: {
              'path': audioPath,
              'duration': duration.inSeconds,
              'hasBytes': audioBytes != null && audioBytes.isNotEmpty,
            });

        await _recordingHandler.processResults(
          audioPath: audioPath,
          duration: duration,
          currentTranscript: _currentTranscript,
          onResult: _onResult,
          onError: _setError,
          onAudioUrlUploaded: _onAudioUrlUploaded,
          onAudioUploadSkipped: _onAudioUploadSkipped,
        );
      }

      _state = AudioInputState.idle;
      notifyListeners();
    } catch (e) {
      AppLogger.e('❌ Failed to stop recording',
          category: LogCategory.voice, error: e);
      _setError('Failed to stop recording: $e');
    }
  }

  /// Callback for when audio URL is uploaded
  Function(String audioUrl)? _onAudioUrlUploaded;

  /// Callback for when audio upload is skipped (logged out user or failed)
  Function()? _onAudioUploadSkipped;

  /// Set callback to receive audio URL after background upload
  void setOnAudioUrlUploaded(Function(String audioUrl)? callback) {
    _onAudioUrlUploaded = callback;
  }

  /// Set callback for when upload is skipped/failed (to hide loading indicator)
  void setOnAudioUploadSkipped(Function()? callback) {
    _onAudioUploadSkipped = callback;
  }

  /// Cancel current recording
  Future<void> cancelRecording() async {
    try {
      if (!kIsWeb && _speechToText.isListening) {
        await _speechToText.cancel();
      }

      await _recordingHandler.cancelRecording(_currentAudioPath);

      // Clear web audio bytes
      _webAudioBytes = null;

      _state = AudioInputState.idle;
      _currentTranscript = '';
      _currentAudioPath = null;
      notifyListeners();

      AppLogger.i('Recording cancelled', category: LogCategory.voice);
    } catch (e) {
      AppLogger.e('Error cancelling recording',
          category: LogCategory.voice, error: e);
    }
  }

  /// Handle speech recognition errors with better diagnostics
  void _handleSpeechError(dynamic error) {
    final errorString = error.toString();
    final isNoMatchError = errorString.contains('error_no_match');
    final isTimeoutError = errorString.contains('timeout') ||
        errorString.contains('error_speech_timeout');
    final isListenFailedError = errorString.contains('error_listen_failed');
    final isPermissionError = errorString.contains('error_permission_denied');

    _hasSpeechRecognitionError = true;
    if (isNoMatchError) {
      _speechErrorType = 'no_match';
    } else if (isTimeoutError) {
      _speechErrorType = 'timeout';
    } else if (isListenFailedError) {
      _speechErrorType = 'listen_failed';
    } else if (isPermissionError) {
      _speechErrorType = 'permission_denied';
    } else {
      _speechErrorType = 'other';
    }

    AppLogger.e('🎤 Speech recognition error: $error',
        category: LogCategory.voice,
        data: {
          'errorType': error.runtimeType.toString(),
          'errorMessage': errorString,
          'isRecording': _state == AudioInputState.recording,
          'isNoMatchError': isNoMatchError,
          'isTimeoutError': isTimeoutError,
          'isListenFailedError': isListenFailedError,
          'isPermissionError': isPermissionError,
          'hasCurrentTranscript': _currentTranscript.isNotEmpty,
          'speechErrorType': _speechErrorType,
        });

    if (isListenFailedError) {
      AppLogger.w('🎤 Speech listening failed - possible microphone conflict',
          category: LogCategory.voice,
          data: {
            'cause': 'Another app may be using the microphone',
            'suggestion':
                'Audio recording will continue, speech recognition disabled',
            'recovery': 'Try restarting the app or closing other audio apps'
          });
    } else if (isPermissionError) {
      AppLogger.w('🎤 Speech recognition permission denied',
          category: LogCategory.voice,
          data: {
            'cause': 'User denied speech recognition permission',
            'suggestion': 'Enable speech recognition in Settings > Privacy',
            'fallback': 'Audio recording will continue without transcription'
          });
    } else if (isNoMatchError) {
      AppLogger.d('🎤 No speech detected - continuing recording',
          category: LogCategory.voice,
          data: {
            'suggestion': 'Speak closer to the microphone',
            'status': 'Audio recording continues normally'
          });
    }

    notifyListeners();
  }

  /// Handle speech recognition status changes
  void _handleSpeechStatus(String status) {
    AppLogger.d('Speech status: $status', category: LogCategory.voice);
  }

  /// Set error state
  void _setError(String message) {
    _state = AudioInputState.error;
    _errorMessage = message;
    notifyListeners();

    AppLogger.e('Audio input error: $message', category: LogCategory.voice);
  }

  /// Clear current state
  void clearState() {
    _currentTranscript = '';
    _currentAudioPath = null;
    _errorMessage = '';
    _state = AudioInputState.idle;
    _hasSpeechRecognitionError = false;
    _speechErrorType = '';
    _recordingStartTime = null;
    notifyListeners();
  }

  /// Reset and reinitialize the service (for critical error recovery)
  Future<void> resetService() async {
    AppLogger.i('🔄 Resetting audio service for error recovery',
        category: LogCategory.voice);

    try {
      if (_state == AudioInputState.recording) {
        await cancelRecording();
      }

      if (!kIsWeb) {
        await _recordingHandler.cleanupTempFiles();
      }

      try {
        if (_recordingHandler.recorder.isRecording) {
          await _recordingHandler.recorder.cancelRecording();
        }
      } catch (e) {
        AppLogger.w('Error stopping recorder during reset: $e',
            category: LogCategory.voice);
      }

      await Future.delayed(const Duration(milliseconds: 100));

      _isInitialized = false;

      clearState();
      _webAudioBytes = null;

      AppLogger.i('🔄 Audio service reset completed',
          category: LogCategory.voice);
    } catch (e) {
      AppLogger.e('Failed to reset audio service',
          category: LogCategory.voice, error: e);
      _setError('Failed to reset audio service: $e');
    }
  }

  /// Check if the service is in a good state for recording
  bool get canStartRecording {
    return _state == AudioInputState.idle && !hasError && _isInitialized;
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      _recordingHandler.cleanupTempFiles().catchError((e) {
        AppLogger.w('Error during dispose cleanup: $e',
            category: LogCategory.voice);
      });
    }

    _recordingHandler.dispose();
    _webAudioBytes = null;

    super.dispose();
  }
}
