// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:aurogram/shared/services/media/audio/audio_recorder_interface.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:web/web.dart' as web;

/// Web implementation of AudioRecorderInterface using MediaRecorder API
class AppAudioRecorder implements AudioRecorderInterface {
  web.MediaRecorder? _recorder;
  web.MediaStream? _stream;
  final List<web.Blob> _chunks = [];
  bool _isRecording = false;
  bool _isInitialized = false;
  Completer<Uint8List?>? _stopCompleter;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check if MediaRecorder is supported
      final navigator = web.window.navigator;

      // Request microphone permission (but don't keep stream open)
      // We only need to verify permission is available, not keep mic active
      final mediaDevices = navigator.mediaDevices;
      final constraints = web.MediaStreamConstraints(audio: true.toJS);

      final testStream = await mediaDevices.getUserMedia(constraints).toDart;

      // Immediately stop the stream - we only needed permission, not an active mic
      testStream.getTracks().toDart.forEach((track) => track.stop());

      _isInitialized = true;
      AppLogger.d(
          'Web audio recorder initialized (permission granted, stream closed)',
          category: LogCategory.media);
      return true;
    } catch (e) {
      AppLogger.e('Failed to initialize web audio recorder',
          category: LogCategory.media, error: e);
      return false;
    }
  }

  @override
  Future<bool> startRecording() async {
    if (_isRecording) return false;
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      _chunks.clear();

      // Get fresh stream
      final mediaDevices = web.window.navigator.mediaDevices;
      final constraints = web.MediaStreamConstraints(audio: true.toJS);
      _stream = await mediaDevices.getUserMedia(constraints).toDart;

      // Create MediaRecorder with webm format
      final options =
          web.MediaRecorderOptions(mimeType: 'audio/webm;codecs=opus');
      _recorder = web.MediaRecorder(_stream!, options);

      // Listen for data available events
      _recorder!.ondataavailable = (web.BlobEvent event) {
        if (event.data.size > 0) {
          _chunks.add(event.data);
        }
      }.toJS;

      // Set up stop handler - must be sync, so we use a completer
      _recorder!.onstop = (web.Event event) {
        _processStopEvent();
      }.toJS;

      _recorder!.start(100); // Request data every 100ms
      _isRecording = true;

      AppLogger.d('Web audio recording started', category: LogCategory.media);
      return true;
    } catch (e) {
      AppLogger.e('Failed to start web audio recording',
          category: LogCategory.media, error: e);
      return false;
    }
  }

  /// Process the stop event - called from sync callback
  void _processStopEvent() {
    if (_stopCompleter == null || _stopCompleter!.isCompleted) return;

    try {
      if (_chunks.isEmpty) {
        _stopCompleter!.complete(null);
        return;
      }

      // Combine all chunks into a single blob
      final blob = web.Blob(
        _chunks.map((c) => c as JSAny).toList().toJS,
        web.BlobPropertyBag(type: 'audio/webm'),
      );

      // Read blob as ArrayBuffer
      final reader = web.FileReader();

      reader.onload = (web.Event e) {
        final result = reader.result;
        if (result != null && !_stopCompleter!.isCompleted) {
          final arrayBuffer = result as JSArrayBuffer;
          final bytes = arrayBuffer.toDart.asUint8List();
          _stopCompleter!.complete(bytes);
        } else if (!_stopCompleter!.isCompleted) {
          _stopCompleter!.complete(null);
        }
      }.toJS;

      reader.onerror = (web.Event e) {
        AppLogger.e('Error reading audio blob', category: LogCategory.media);
        if (!_stopCompleter!.isCompleted) {
          _stopCompleter!.complete(null);
        }
      }.toJS;

      reader.readAsArrayBuffer(blob);
    } catch (e) {
      AppLogger.e('Error processing audio chunks',
          category: LogCategory.media, error: e);
      if (!_stopCompleter!.isCompleted) {
        _stopCompleter!.complete(null);
      }
    }
  }

  @override
  Future<Uint8List?> stopRecording() async {
    if (!_isRecording || _recorder == null) return null;

    try {
      _stopCompleter = Completer<Uint8List?>();

      _recorder!.stop();
      _isRecording = false;

      // Stop all tracks on the stream
      _stream?.getTracks().toDart.forEach((track) => track.stop());

      return _stopCompleter!.future;
    } catch (e) {
      AppLogger.e('Failed to stop web audio recording',
          category: LogCategory.media, error: e);
      _isRecording = false;
      return null;
    }
  }

  @override
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      _stopCompleter = null; // Discard any pending completion
      _recorder?.stop();
      _stream?.getTracks().toDart.forEach((track) => track.stop());
      _chunks.clear();
      _isRecording = false;
      AppLogger.d('Web audio recording cancelled', category: LogCategory.media);
    } catch (e) {
      AppLogger.e('Failed to cancel web audio recording',
          category: LogCategory.media, error: e);
    }
  }

  @override
  bool get isRecording => _isRecording;

  @override
  bool get isInitialized => _isInitialized;

  @override
  String get mimeType => 'audio/webm';

  @override
  String get fileExtension => '.webm';

  @override
  void dispose() {
    cancelRecording();
    _stream?.getTracks().toDart.forEach((track) => track.stop());
    _recorder = null;
    _stream = null;
    _isInitialized = false;
    AppLogger.d('Web audio recorder disposed', category: LogCategory.media);
  }
}
