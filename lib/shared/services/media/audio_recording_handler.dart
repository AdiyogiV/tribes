import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/services/media/media_storage_service.dart';
import 'package:aurogram/shared/services/media/audio_input_models.dart';
import 'package:aurogram/shared/services/media/audio/audio_recorder.dart';

// Conditional imports for mobile-only features
import 'dart:io' if (dart.library.html) 'package:aurogram/platform/io_stub.dart';
import 'package:path_provider/path_provider.dart'
    if (dart.library.html) 'package:aurogram/platform/path_provider_stub.dart';
import 'package:path/path.dart' as path
    if (dart.library.html) 'package:aurogram/platform/path_stub.dart';

/// Handles the low-level recording mechanics: starting/stopping the recorder,
/// saving audio bytes to files, processing results, uploading to Firebase
/// Storage, and cleaning up temporary files.
class AudioRecordingHandler {
  final AppAudioRecorder recorder;
  final MediaStorageService storageService;

  AudioRecordingHandler({
    required this.recorder,
    required this.storageService,
  });

  /// Generate a temporary file path for a new recording (mobile only).
  Future<String> generateRecordingPath() async {
    final Directory tempDir = await getTemporaryDirectory();
    final String fileName =
        'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return path.join(tempDir.path, fileName);
  }

  /// Start the audio recorder (mobile path, with file-based output).
  Future<bool> startAudioRecording(String? audioPath) async {
    try {
      AppLogger.i('🎙️ Starting audio recording...',
          category: LogCategory.voice, data: {'path': audioPath});

      final started = await recorder.startRecording();
      if (!started) {
        AppLogger.e('❌ Audio recorder failed to start',
            category: LogCategory.voice);
        return false;
      }

      // Give the recorder time to initialize
      await Future.delayed(const Duration(milliseconds: 150));

      if (!recorder.isRecording) {
        AppLogger.e('❌ Audio recorder failed to start - isRecording=false',
            category: LogCategory.voice);
        return false;
      }

      AppLogger.i('✅ Audio recording STARTED successfully',
          category: LogCategory.voice, data: {
            'path': audioPath,
          });
      return true;
    } catch (e) {
      AppLogger.e('❌ Error starting audio recording',
          category: LogCategory.voice, error: e);
      return false;
    }
  }

  /// Stop recording and return audio bytes from the recorder.
  Future<Uint8List?> stopRecording() async {
    return recorder.stopRecording();
  }

  /// Save audio bytes to a local file path (mobile only).
  Future<void> saveAudioToFile(Uint8List audioBytes, String audioPath) async {
    try {
      final file = File(audioPath);
      // Ensure parent directory exists
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
  }

  /// Process mobile recording results: validate the audio file,
  /// create an [AudioInputResult], and trigger background upload.
  ///
  /// Calls [onResult] with the result and [onError] if processing fails.
  Future<void> processResults({
    required String? audioPath,
    required Duration duration,
    required String currentTranscript,
    required Function(AudioInputResult)? onResult,
    required Function(String) onError,
    Function(String audioUrl)? onAudioUrlUploaded,
    Function()? onAudioUploadSkipped,
  }) async {
    try {
      // Validate audio file
      if (audioPath == null || !File(audioPath).existsSync()) {
        AppLogger.w('⚠️ No valid audio file',
            category: LogCategory.voice,
            data: {
              'audioPath': audioPath,
              'pathExists': audioPath != null,
              'fileExists':
                  audioPath != null ? File(audioPath).existsSync() : false,
            });

        final result = AudioInputResult(
          transcript: currentTranscript.trim(),
          audioUrl: null,
          durationInSeconds: duration.inSeconds,
          localAudioPath: null,
        );

        onResult?.call(result);
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
        try {
          await file.delete();
        } catch (_) {
          AppLogger.w(
              'AudioInputService: failed to delete empty audio file',
              category: LogCategory.general);
        }

        final result = AudioInputResult(
          transcript: currentTranscript.trim(),
          audioUrl: null,
          durationInSeconds: duration.inSeconds,
          localAudioPath: null,
        );

        onResult?.call(result);
        return;
      }

      AppLogger.i('🎯 Voice recording ready',
          category: LogCategory.voice, data: {
            'hasTranscript': currentTranscript.isNotEmpty,
            'transcript': currentTranscript,
            'localPath': audioPath,
            'duration': duration.inSeconds,
            'fileSize': fileSize,
          });

      final result = AudioInputResult(
        transcript: currentTranscript.trim(),
        audioUrl: null,
        durationInSeconds: duration.inSeconds,
        localAudioPath: audioPath,
      );

      onResult?.call(result);

      // Upload to Firebase Storage in background
      uploadAudioInBackground(
        audioPath,
        onAudioUrlUploaded: onAudioUrlUploaded,
        onAudioUploadSkipped: onAudioUploadSkipped,
      );
    } catch (e) {
      AppLogger.e('❌ Failed to process voice results',
          category: LogCategory.voice, error: e);
      onError('Failed to process results: $e');
    }
  }

  /// Process web audio results (no local file path).
  Future<void> processWebResults({
    required Uint8List? audioBytes,
    required Duration duration,
    required Function(AudioInputResult)? onResult,
    required Function(String) onError,
    Function(String audioUrl)? onAudioUrlUploaded,
    Function()? onAudioUploadSkipped,
  }) async {
    try {
      if (audioBytes == null || audioBytes.isEmpty) {
        AppLogger.w('⚠️ No web audio data', category: LogCategory.voice);

        final result = AudioInputResult(
          transcript: '',
          audioUrl: null,
          durationInSeconds: duration.inSeconds,
          localAudioPath: null,
        );

        onResult?.call(result);
        return;
      }

      AppLogger.i('🎯 Web voice recording ready',
          category: LogCategory.voice, data: {
            'duration': duration.inSeconds,
            'bytesLength': audioBytes.length,
          });

      final result = AudioInputResult(
        transcript: '',
        audioUrl: null,
        durationInSeconds: duration.inSeconds,
        localAudioPath: null,
      );

      onResult?.call(result);

      // Upload audio bytes to Firebase Storage in background
      uploadWebAudioInBackground(
        audioBytes,
        onAudioUrlUploaded: onAudioUrlUploaded,
        onAudioUploadSkipped: onAudioUploadSkipped,
      );
    } catch (e) {
      AppLogger.e('❌ Failed to process web voice results',
          category: LogCategory.voice, error: e);
      onError('Failed to process results: $e');
    }
  }

  /// Upload audio file to Firebase Storage in background (mobile).
  Future<void> uploadAudioInBackground(
    String audioPath, {
    Function(String audioUrl)? onAudioUrlUploaded,
    Function()? onAudioUploadSkipped,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.d('⏭️ Skipping audio upload - user not authenticated',
            category: LogCategory.voice);
        onAudioUploadSkipped?.call();
        // Delay deletion to allow Gemini to finish reading the file
        Future.delayed(const Duration(seconds: 30), () {
          deleteTempFile(audioPath);
        });
        return;
      }

      final file = File(audioPath);
      if (!await file.exists()) return;

      final fileName =
          'voice_chat_${DateTime.now().millisecondsSinceEpoch}.wav';
      final storagePath = 'chat_audio/$fileName';

      final audioUrl =
          await storageService.uploadToStorage(audioPath, storagePath);

      if (audioUrl != null) {
        AppLogger.i('☁️ Audio uploaded to Storage in background',
            category: LogCategory.voice, data: {'audioUrl': audioUrl});
        onAudioUrlUploaded?.call(audioUrl);
      } else {
        onAudioUploadSkipped?.call();
      }

      deleteTempFile(audioPath);
    } catch (e) {
      AppLogger.w('⚠️ Background audio upload failed: $e',
          category: LogCategory.voice);
      onAudioUploadSkipped?.call();
    }
  }

  /// Upload web audio bytes to Firebase Storage.
  Future<void> uploadWebAudioInBackground(
    Uint8List audioBytes, {
    Function(String audioUrl)? onAudioUrlUploaded,
    Function()? onAudioUploadSkipped,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.d('⏭️ Skipping web audio upload - user not authenticated',
            category: LogCategory.voice);
        onAudioUploadSkipped?.call();
        return;
      }

      final fileName =
          'voice_chat_${DateTime.now().millisecondsSinceEpoch}.webm';
      final storagePath = 'chat_audio/$fileName';

      final audioUrl = await storageService.uploadFromBytes(
        audioBytes,
        storagePath,
        contentType: 'audio/webm',
      );

      if (audioUrl != null) {
        AppLogger.i('☁️ Web audio uploaded to Storage',
            category: LogCategory.voice, data: {'audioUrl': audioUrl});
        onAudioUrlUploaded?.call(audioUrl);
      } else {
        onAudioUploadSkipped?.call();
      }
    } catch (e) {
      AppLogger.w('⚠️ Web audio upload failed: $e',
          category: LogCategory.voice);
      onAudioUploadSkipped?.call();
    }
  }

  /// Delete a temporary audio file.
  void deleteTempFile(String audioPath) {
    try {
      final file = File(audioPath);
      file.exists().then((exists) {
        if (exists) {
          file.delete().then((_) {
            AppLogger.d('🗑️ Deleted temp audio file',
                category: LogCategory.voice);
          });
        }
      });
    } catch (e) {
      AppLogger.w('⚠️ Failed to delete temp file: $e',
          category: LogCategory.voice);
    }
  }

  /// Clean up leftover temporary audio files from previous sessions.
  Future<void> cleanupTempFiles() async {
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

  /// Cancel an in-progress recording and clean up temp files.
  Future<void> cancelRecording(String? currentAudioPath) async {
    await recorder.cancelRecording();

    if (!kIsWeb && currentAudioPath != null) {
      final file = File(currentAudioPath);
      if (await file.exists()) {
        await file.delete();
        AppLogger.i('🗑️ Deleted temp audio file on cancel',
            category: LogCategory.voice);
      }
    }
  }

  /// Dispose the underlying recorder.
  void dispose() {
    recorder.dispose();
  }
}
