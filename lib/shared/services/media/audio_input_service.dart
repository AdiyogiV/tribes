import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/services/media/media_storage_service.dart';
import 'package:aurogram/shared/services/media/audio/audio_recorder.dart';

// Conditional imports for mobile-only features
import 'dart:io' if (dart.library.html) 'package:aurogram/platform/io_stub.dart';
import 'package:path_provider/path_provider.dart'
    if (dart.library.html) 'package:aurogram/platform/path_provider_stub.dart';
import 'package:permission_handler/permission_handler.dart'
    if (dart.library.html) 'package:aurogram/platform/permission_handler_stub.dart';
import 'package:geolocator/geolocator.dart'
    if (dart.library.html) 'package:aurogram/platform/geolocator_stub.dart';
import 'package:path/path.dart' as path
    if (dart.library.html) 'package:aurogram/platform/path_stub.dart';

enum AudioInputState {
  idle,
  recording, // Both recording audio and transcribing
  processing, // Processing the recording
  error,
}

class AudioInputResult {
  final String transcript;
  final String? audioUrl; // Firebase Storage URL
  final int durationInSeconds;
  final String? localAudioPath; // Temp local path before upload

  const AudioInputResult({
    required this.transcript,
    this.audioUrl,
    required this.durationInSeconds,
    this.localAudioPath,
  });
}

/// Enhanced service that simultaneously records audio and transcribes speech
/// Uses en_IN locale for optimal English/Hindi/Hinglish code-switching support
class AudioInputService extends ChangeNotifier {
  static final AudioInputService _instance = AudioInputService._internal();
  factory AudioInputService() => _instance;
  AudioInputService._internal();

  // Speech-to-text service
  final SpeechToText _speechToText = SpeechToText();

  // Audio recording service - cross-platform (web uses MediaRecorder API)
  final AppAudioRecorder _recorder = AppAudioRecorder();
  
  // Web-specific: store audio bytes from recording
  Uint8List? _webAudioBytes;

  // Media storage service for uploading
  final MediaStorageService _storageService = MediaStorageService();

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
      // Web uses different initialization flow
      if (kIsWeb) {
        return await _initializeForWeb();
      }
      
      // Clean up any orphaned temp files from previous sessions
      await _cleanupTempFiles();

      // Request all necessary permissions first
      final micPermission = await Permission.microphone.request();
      if (micPermission != PermissionStatus.granted) {
        _setError('Microphone permission denied');
        return false;
      }

      // Request speech recognition permission explicitly on iOS
      if (Platform.isIOS) {
        final speechPermission = await Permission.speech.request();
        if (speechPermission != PermissionStatus.granted) {
          _setError('Speech recognition permission denied');
          return false;
        }
      }

      // Request location permission upfront (non-blocking)
      // This prevents location permission dialog from interrupting audio processing later
      await _requestLocationPermission();

      AppLogger.d('Audio permissions granted, initializing components',
          category: LogCategory.voice);

      // Initialize the cross-platform recorder
      final recorderInitialized = await _recorder.initialize();
      if (!recorderInitialized) {
        _setError('Audio recording permission denied');
        return false;
      }

      // Initialize speech-to-text
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
  
  /// Web-specific initialization
  Future<bool> _initializeForWeb() async {
    try {
      // Initialize the cross-platform recorder (handles browser permission)
      final recorderInitialized = await _recorder.initialize();
      if (!recorderInitialized) {
        _setError('Microphone permission denied');
        return false;
      }

      // Speech-to-text may not be available on all browsers
      // We'll skip it on web and rely on Gemini for audio understanding
      AppLogger.d('Web audio service initialized (speech-to-text disabled)',
          category: LogCategory.voice);

      _isInitialized = true;
      return true;
    } catch (e) {
      AppLogger.e('Failed to initialize web audio service',
          category: LogCategory.voice, error: e);
      _setError('Failed to initialize: $e');
      return false;
    }
  }

  /// Request location permission upfront (non-blocking)
  /// This is requested alongside audio permissions to prevent
  /// location permission dialog from interrupting audio processing later
  Future<void> _requestLocationPermission() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.d('Location services disabled, skipping permission request',
            category: LogCategory.voice);
        return;
      }

      // Check current permission status
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Request permission - this shows the dialog now instead of during audio processing
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

      AppLogger.d('Location permission granted',
          category: LogCategory.voice);
    } catch (e) {
      // Location is optional - don't fail audio init if this errors
      AppLogger.d('Location permission check failed (optional): $e',
          category: LogCategory.voice);
    }
  }

  /// Start recording audio and optionally speech recognition
  /// Set [skipSpeechRecognition] to true when using Gemini for audio understanding
  /// (On Android, STT and audio recorder conflict for microphone access)
  Future<void> startRecording({
    Function(AudioInputResult)? onResult,
    Function(String)? onTranscriptUpdate,
    bool skipSpeechRecognition = true, // Default true for Gemini audio
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
        final started = await _recorder.startRecording();
        if (!started) {
          _setError('Failed to start audio recording');
          return;
        }
        AppLogger.i('🎙️ Web audio recording started',
            category: LogCategory.voice);
      } else {
        // Mobile: Get temporary directory for audio recording
        final Directory tempDir = await getTemporaryDirectory();
        // Use .m4a extension to match what AppAudioRecorder produces
        final String fileName =
            'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _currentAudioPath = path.join(tempDir.path, fileName);

        // Start audio recording first
        final recordingStarted = await _startAudioRecording();
        if (!recordingStarted) {
          _setError('Failed to start audio recording');
          return;
        }

        // Only start speech recognition if NOT skipped (mobile only)
        // (On Android, STT and audio recorder both need microphone - causes conflict)
        if (!skipSpeechRecognition) {
          await _startSpeechRecognition(onTranscriptUpdate);
        } else {
          AppLogger.i('🎙️ Audio-only recording mode (Gemini will understand speech)',
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

  /// Start audio recording with better error handling (mobile only)
  Future<bool> _startAudioRecording() async {
    try {
      AppLogger.i('🎙️ Starting audio recording...',
          category: LogCategory.voice, data: {'path': _currentAudioPath});
      
      // Use cross-platform recorder
      final started = await _recorder.startRecording();
      if (!started) {
        AppLogger.e('❌ Audio recorder failed to start',
            category: LogCategory.voice);
        return false;
      }

      // Give the recorder time to initialize
      await Future.delayed(const Duration(milliseconds: 150));

      if (!_recorder.isRecording) {
        AppLogger.e('❌ Audio recorder failed to start - isRecording=false',
            category: LogCategory.voice);
        return false;
      }
      
      AppLogger.i('✅ Audio recording STARTED successfully',
          category: LogCategory.voice, data: {
            'path': _currentAudioPath,
          });
      return true;
    } catch (e) {
      AppLogger.e('❌ Error starting audio recording',
          category: LogCategory.voice, error: e);
      return false;
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
        localeId: 'en_IN', // English (India) - supports Hinglish code-switching
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
      // Don't fail the entire operation - audio recording can continue
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

    AppLogger.i('🛑 Stopping audio recording...',
        category: LogCategory.voice);

    try {
      _state = AudioInputState.processing;
      notifyListeners();

      // Calculate duration
      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero;

      if (kIsWeb) {
        // Web: get audio bytes from cross-platform recorder
        _webAudioBytes = await _recorder.stopRecording();
        
        AppLogger.i('✅ Web audio recording STOPPED',
            category: LogCategory.voice, data: {
              'bytesLength': _webAudioBytes?.length ?? 0,
              'duration': duration.inSeconds,
            });

        // Process web results
        await _processWebResults(_webAudioBytes, duration);
      } else {
        // Mobile: Stop speech-to-text
        if (_speechToText.isListening) {
          await _speechToText.stop();
        }

        // Stop audio recording (returns bytes)
        final audioBytes = await _recorder.stopRecording();
        final audioPath = _currentAudioPath;

        // Save bytes to the expected file path
        if (audioBytes != null && audioBytes.isNotEmpty && audioPath != null) {
          try {
            final file = File(audioPath);
            // Ensure parent directory exists (use path package for cross-platform compatibility)
            if (!kIsWeb) {
              final dirPath = path.dirname(audioPath);
              if (dirPath.isNotEmpty && dirPath != audioPath) {
                try {
                  await Directory(dirPath).create(recursive: true);
                } catch (_) {
                  // Directory might already exist, ignore
                }
              }
            }
            await file.writeAsBytes(audioBytes);
            AppLogger.i('💾 Saved audio bytes to file',
                category: LogCategory.voice, data: {
                  'path': audioPath,
                  'bytesLength': audioBytes.length,
                });
          } catch (e) {
            AppLogger.e('❌ Failed to save audio bytes to file',
                category: LogCategory.voice, error: e);
            // Continue processing even if file save fails
          }
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

        // Process the results
        await _processResults(audioPath, duration);
      }
    } catch (e) {
      AppLogger.e('❌ Failed to stop recording',
          category: LogCategory.voice, error: e);
      _setError('Failed to stop recording: $e');
    }
  }
  
  /// Process web audio results
  Future<void> _processWebResults(Uint8List? audioBytes, Duration duration) async {
    try {
      if (audioBytes == null || audioBytes.isEmpty) {
        AppLogger.w('⚠️ No web audio data',
            category: LogCategory.voice);
        
        final result = AudioInputResult(
          transcript: '',
          audioUrl: null,
          durationInSeconds: duration.inSeconds,
          localAudioPath: null,
        );
        
        if (_onResult != null) _onResult!(result);
        _state = AudioInputState.idle;
        notifyListeners();
        return;
      }

      AppLogger.i('🎯 Web voice recording ready', category: LogCategory.voice, data: {
        'duration': duration.inSeconds,
        'bytesLength': audioBytes.length,
      });

      // For web, we don't have a local file path
      // The audio bytes can be uploaded directly
      final result = AudioInputResult(
        transcript: '', // No speech-to-text on web
        audioUrl: null, // Will be set after upload
        durationInSeconds: duration.inSeconds,
        localAudioPath: null, // No local path on web
      );

      // Call completion callback
      if (_onResult != null) {
        _onResult!(result);
      }

      // Upload audio bytes to Firebase Storage in background
      _uploadWebAudioInBackground(audioBytes);

      _state = AudioInputState.idle;
      notifyListeners();
    } catch (e) {
      AppLogger.e('❌ Failed to process web voice results',
          category: LogCategory.voice, error: e);
      _setError('Failed to process results: $e');
    }
  }
  
  /// Upload web audio bytes to Firebase Storage
  Future<void> _uploadWebAudioInBackground(Uint8List audioBytes) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.d('⏭️ Skipping web audio upload - user not authenticated',
            category: LogCategory.voice);
        _onAudioUploadSkipped?.call();
        return;
      }

      final fileName = 'voice_chat_${DateTime.now().millisecondsSinceEpoch}.webm';
      final storagePath = 'chat_audio/$fileName';

      final audioUrl = await _storageService.uploadFromBytes(
        audioBytes, 
        storagePath,
        contentType: 'audio/webm',
      );

      if (audioUrl != null) {
        AppLogger.i('☁️ Web audio uploaded to Storage',
            category: LogCategory.voice, data: {'audioUrl': audioUrl});
        _onAudioUrlUploaded?.call(audioUrl);
      } else {
        _onAudioUploadSkipped?.call();
      }
    } catch (e) {
      AppLogger.w('⚠️ Web audio upload failed: $e', category: LogCategory.voice);
      _onAudioUploadSkipped?.call();
    }
  }

  /// Process and upload the recording results
  /// Changed: Pass localAudioPath FIRST for Gemini processing, then upload in background
  Future<void> _processResults(String? audioPath, Duration duration) async {
    try {
      // Validate audio file
      if (audioPath == null || !File(audioPath).existsSync()) {
        AppLogger.w('⚠️ No valid audio file',
            category: LogCategory.voice,
            data: {
              'audioPath': audioPath,
              'pathExists': audioPath != null,
              'fileExists': audioPath != null ? File(audioPath).existsSync() : false,
            });
        
        // Still call callback with transcript only
        final result = AudioInputResult(
          transcript: _currentTranscript.trim(),
          audioUrl: null,
          durationInSeconds: duration.inSeconds,
          localAudioPath: null,
        );
        
        if (_onResult != null) _onResult!(result);
        _state = AudioInputState.idle;
        notifyListeners();
        return;
      }

      final file = File(audioPath);
      final fileSize = await file.length();

      AppLogger.i('📁 Audio file info',
          category: LogCategory.voice, data: {
            'path': audioPath,
            'fileSize': fileSize,
            'fileSizeKB': (fileSize / 1024).toStringAsFixed(1),
            'exists': await file.exists(),
          });

      if (fileSize == 0 || fileSize < 100) {
        AppLogger.e('❌ Audio file is empty or too small ($fileSize bytes)',
            category: LogCategory.voice);
        try { await file.delete(); } catch (_) {
          AppLogger.w('AudioInputService: failed to delete empty audio file', category: LogCategory.general);
        }
        
        final result = AudioInputResult(
          transcript: _currentTranscript.trim(),
          audioUrl: null,
          durationInSeconds: duration.inSeconds,
          localAudioPath: null,
        );
        
        if (_onResult != null) _onResult!(result);
        _state = AudioInputState.idle;
        notifyListeners();
        return;
      }

      AppLogger.i('🎯 Voice recording ready', category: LogCategory.voice, data: {
        'hasTranscript': _currentTranscript.isNotEmpty,
        'transcript': _currentTranscript,
        'localPath': audioPath,
        'duration': duration.inSeconds,
        'fileSize': fileSize,
      });

      // Create result with LOCAL path - Gemini can process directly!
      // Upload happens in background, audioUrl will be updated later if needed
      final result = AudioInputResult(
        transcript: _currentTranscript.trim(),
        audioUrl: null, // Will be set after background upload
        durationInSeconds: duration.inSeconds,
        localAudioPath: audioPath, // Pass local path for immediate Gemini processing
      );

      // Call completion callback IMMEDIATELY with local path
      // This allows Gemini to process while upload happens in background
      if (_onResult != null) {
        _onResult!(result);
      } else {
        AppLogger.w('⚠️ No result callback set', category: LogCategory.voice);
      }

      // Upload to Firebase Storage in background (for playback later)
      _uploadAudioInBackground(audioPath);

      _state = AudioInputState.idle;
      notifyListeners();
    } catch (e) {
      AppLogger.e('❌ Failed to process voice results',
          category: LogCategory.voice, error: e);
      _setError('Failed to process results: $e');
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

  /// Upload audio to Firebase Storage in background
  /// This runs after callback is called so Gemini processing isn't blocked
  /// Skips upload for logged out users to avoid permission errors
  Future<void> _uploadAudioInBackground(String audioPath) async {
    try {
      // Skip upload for logged out users - they can still use Gemini locally
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.d('⏭️ Skipping audio upload - user not authenticated',
            category: LogCategory.voice);
        // Notify with special marker so UI knows not to show upload indicator
        _onAudioUploadSkipped?.call();
        // DO NOT delete temp file immediately - Gemini is still processing it asynchronously!
        // The file will be cleaned up on next session initialization via _cleanupTempFiles()
        // or after a delay to allow Gemini to finish reading it
        Future.delayed(const Duration(seconds: 30), () {
          _deleteTempFile(audioPath);
        });
        return;
      }

      final file = File(audioPath);
      if (!await file.exists()) return;

      final fileName = 'voice_chat_${DateTime.now().millisecondsSinceEpoch}.wav';
      final storagePath = 'chat_audio/$fileName';

      final audioUrl = await _storageService.uploadToStorage(audioPath, storagePath);

      if (audioUrl != null) {
        AppLogger.i('☁️ Audio uploaded to Storage in background',
            category: LogCategory.voice, data: {'audioUrl': audioUrl});
        
        // Notify callback so provider can update message with audioUrl
        _onAudioUrlUploaded?.call(audioUrl);
      } else {
        // Upload returned null (failed) - notify UI to stop showing loading
        _onAudioUploadSkipped?.call();
      }

      // Delete temp file after upload
      _deleteTempFile(audioPath);
    } catch (e) {
      AppLogger.w('⚠️ Background audio upload failed: $e', category: LogCategory.voice);
      // Notify UI to stop showing loading indicator on failure
      _onAudioUploadSkipped?.call();
      // Don't throw - this is background work, Gemini already has the audio
    }
  }

  /// Helper to delete temp audio file
  void _deleteTempFile(String audioPath) {
    try {
      final file = File(audioPath);
      file.exists().then((exists) {
        if (exists) {
          file.delete().then((_) {
            AppLogger.d('🗑️ Deleted temp audio file', category: LogCategory.voice);
          });
        }
      });
    } catch (e) {
      AppLogger.w('⚠️ Failed to delete temp file: $e', category: LogCategory.voice);
    }
  }

  /// Cancel current recording
  Future<void> cancelRecording() async {
    try {
      if (!kIsWeb && _speechToText.isListening) {
        await _speechToText.cancel();
      }

      await _recorder.cancelRecording();

      // Clean up temp file on mobile - CRITICAL for memory management
      if (!kIsWeb && _currentAudioPath != null) {
        final file = File(_currentAudioPath!);
        if (await file.exists()) {
          await file.delete();
          AppLogger.i('🗑️ Deleted temp audio file on cancel',
              category: LogCategory.voice);
        }
      }
      
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

    // Track speech recognition error state
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

    // Provide specific guidance based on error type
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

    // Notify listeners so UI can update with error indicator
    notifyListeners();

    // Don't fail the entire operation for speech errors
    // Audio recording can continue and provide playback option
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
      // Stop any ongoing operations
      if (_state == AudioInputState.recording) {
        await cancelRecording();
      }

      // Clean up any leftover temp files (mobile only)
      if (!kIsWeb) {
        await _cleanupTempFiles();
      }

      // Stop recorder if running
      try {
        if (_recorder.isRecording) {
          await _recorder.cancelRecording();
        }
      } catch (e) {
        AppLogger.w('Error stopping recorder during reset: $e',
            category: LogCategory.voice);
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Reset initialization flag to force reinit
      _isInitialized = false;

      // Clear all state
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

  /// Clean up any leftover temporary audio files
  Future<void> _cleanupTempFiles() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      int deletedCount = 0;
      for (var file in files) {
        if (file is File &&
            file.path.contains('voice_') &&
            (file.path.endsWith('.wav') || file.path.endsWith('.m4a'))) {
          try {
            await file.delete();
            deletedCount++;
          } catch (e) {
            AppLogger.w('Failed to delete temp file ${file.path}: $e',
                category: LogCategory.voice);
          }
        }
      }

      if (deletedCount > 0) {
        AppLogger.i('🗑️ Cleaned up $deletedCount temp audio files',
            category: LogCategory.voice);
      }
    } catch (e) {
      AppLogger.w('Error cleaning up temp files: $e',
          category: LogCategory.voice);
    }
  }

  /// Check if the service is in a good state for recording
  bool get canStartRecording {
    return _state == AudioInputState.idle && !hasError && _isInitialized;
  }

  @override
  void dispose() {
    // Clean up resources to prevent memory leaks
    if (!kIsWeb) {
      _cleanupTempFiles().catchError((e) {
        AppLogger.w('Error during dispose cleanup: $e',
            category: LogCategory.voice);
      });
    }

    _recorder.dispose();
    _webAudioBytes = null;

    super.dispose();
  }
}
