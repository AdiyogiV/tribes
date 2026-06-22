import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/ai_chat/voice/voice_relay_config.dart';

/// High-level state of a live voice conversation with Aryabhatt.
enum VoiceCallState {
  idle,
  connecting,
  listening, // mic open, waiting for / hearing the user
  thinking, // user finished, awaiting Aryabhatt
  speaking, // playing Aryabhatt's TTS audio
  error,
  ended,
}

/// Drives one live voice session end-to-end:
///   mic (PCM16 16k) -> WebSocket relay -> Dialogflow CX -> TTS (PCM16 24k) -> speaker.
///
/// Transport-thin and UI-agnostic: the page just listens and renders. Mic stays
/// open during playback so the user can barge in (CX handles interruption).
class VoiceSessionController extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer(logLevel: Level.off);

  WebSocketChannel? _channel;
  StreamSubscription? _socketSub;
  StreamSubscription<Uint8List>? _micSub;
  Future<void>? _cleanupFuture;

  bool _playerOpen = false;
  bool _disposed = false;

  // Flow counters so the logs tell the whole story of a call.
  int _ttsChunks = 0; // TTS audio frames received from the relay
  int _ttsBytes = 0;
  int _micChunks = 0; // mic frames sent to the relay
  int _micBytes = 0;

  VoiceCallState _state = VoiceCallState.idle;
  String _userTranscript = '';
  String _aryabhattReply = '';
  String? _errorMessage;

  VoiceCallState get state => _state;
  String get userTranscript => _userTranscript;
  String get aryabhattReply => _aryabhattReply;
  String? get errorMessage => _errorMessage;

  void _setState(VoiceCallState s) {
    if (_disposed || _state == s) return;
    final from = _state;
    _state = s;
    AppLogger.i('Voice state',
        category: LogCategory.voice,
        data: {'from': from.name, 'to': s.name});
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────
  // Lifecycle
  // ───────────────────────────────────────────────────────────────

  /// Open audio devices, connect to the relay, and start streaming the mic.
  Future<void> start() async {
    if (_state != VoiceCallState.idle && _state != VoiceCallState.ended) return;
    _setState(VoiceCallState.connecting);
    _ttsChunks = _ttsBytes = _micChunks = _micBytes = 0;
    AppLogger.i('Voice call starting',
        category: LogCategory.voice,
        data: {'relay': VoiceRelayConfig.relayUrl});

    try {
      if (!await _recorder.hasPermission()) {
        _fail('Microphone permission denied');
        return;
      }

      if (FirebaseAuth.instance.currentUser == null) {
        _fail('Please sign in to talk to Aryabhatt');
        return;
      }

      await _configureAudioSession();
      await _openPlayer();
      await _connect();
      await _startMic();
    } catch (e) {
      AppLogger.e('Voice session start failed',
          category: LogCategory.voice, error: e);
      _fail('Could not start the call');
    }
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    await session.setActive(true);
  }

  Future<void> _openPlayer() async {
    if (_playerOpen) return;
    await _player.openPlayer();
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: VoiceRelayConfig.ttsSampleRate,
      interleaved: true,
      bufferSize: 1024,
    );
    _playerOpen = true;
  }

  Future<void> _connect() async {
    // Authenticate the caller: the relay rejects sessions without a valid
    // Firebase ID token so randoms can't burn our Gen AI credits.
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (user == null || token == null) {
      throw StateError('not-signed-in');
    }

    _channel = WebSocketChannel.connect(Uri.parse(VoiceRelayConfig.relayUrl));
    await _channel!.ready;
    AppLogger.i('Voice socket connected',
        category: LogCategory.voice,
        data: {'uid': user.uid});

    _socketSub = _channel!.stream.listen(
      _onSocketMessage,
      onError: (e) {
        AppLogger.e('Voice socket error',
            category: LogCategory.voice, error: e);
        _fail('Connection lost');
      },
      onDone: () => _setState(VoiceCallState.ended),
    );

    // Open the CX session on the relay (uid => stable per-user context).
    _channel!.sink.add(jsonEncode({
      'type': 'start',
      'token': token,
      'sessionId': user.uid,
    }));
    AppLogger.i('Voice start frame sent', category: LogCategory.voice);
  }

  Future<void> _startMic() async {
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: VoiceRelayConfig.micSampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );
    _micSub = stream.listen((chunk) {
      // Forward raw PCM straight to the relay as a binary frame.
      _micChunks++;
      _micBytes += chunk.length;
      if (_micChunks == 1 || _micChunks % 50 == 0) {
        AppLogger.i('Mic -> relay',
            category: LogCategory.voice,
            data: {'chunks': _micChunks, 'bytes': _micBytes});
      }
      _channel?.sink.add(chunk);
    });
    _setState(VoiceCallState.listening);
  }

  // ───────────────────────────────────────────────────────────────
  // Relay messages
  // ───────────────────────────────────────────────────────────────

  void _onSocketMessage(dynamic message) {
    if (message is String) {
      _onControl(message);
    } else {
      // Binary = a TTS audio chunk to play.
      final bytes = message is Uint8List
          ? message
          : Uint8List.fromList(List<int>.from(message as List));
      _ttsChunks++;
      _ttsBytes += bytes.length;
      if (_ttsChunks == 1 || _ttsChunks % 25 == 0) {
        AppLogger.i('Relay -> TTS audio',
            category: LogCategory.voice,
            data: {'chunks': _ttsChunks, 'bytes': _ttsBytes});
      }
      _playAudio(bytes);
    }
  }

  void _onControl(String raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      AppLogger.w('Voice: unparseable control frame',
          category: LogCategory.voice, data: {'raw': raw});
      return;
    }
    final type = msg['type'];
    AppLogger.i('Relay control',
        category: LogCategory.voice,
        data: {
          'type': type,
          if (msg['final'] != null) 'final': msg['final'],
          if (msg['text'] != null)
            'text': (msg['text'] as String?)?.substring(
                0,
                ((msg['text'] as String).length).clamp(0, 60)),
        });
    switch (type) {
      case 'ready':
        _setState(VoiceCallState.listening);
        break;
      case 'transcript':
        _userTranscript = (msg['text'] as String?) ?? '';
        if ((msg['final'] as bool?) ?? false) {
          _setState(VoiceCallState.thinking);
        }
        notifyListeners();
        break;
      case 'reply':
        _aryabhattReply = (msg['text'] as String?) ?? '';
        _setState(VoiceCallState.speaking);
        break;
      case 'speaking_done':
        // Turn complete — reopen the floor to the user.
        AppLogger.i('Turn done',
            category: LogCategory.voice,
            data: {'ttsChunks': _ttsChunks, 'ttsBytes': _ttsBytes});
        _userTranscript = '';
        _setState(VoiceCallState.listening);
        break;
      case 'error':
        final m = (msg['message'] as String?) ?? 'Something went wrong';
        _fail(m == 'unauthorized'
            ? 'Session expired — please sign in again'
            : m);
        break;
      case 'session_closed':
        _setState(VoiceCallState.ended);
        break;
    }
  }

  void _playAudio(Uint8List bytes) {
    if (!_playerOpen || bytes.isEmpty) {
      AppLogger.w('Voice: dropped TTS chunk',
          category: LogCategory.voice,
          data: {'playerOpen': _playerOpen, 'bytes': bytes.length});
      return;
    }
    // PCM16 mono => each sample is 2 bytes; feed only whole samples so the
    // interleaved feeder never rejects a misaligned buffer.
    final aligned =
        bytes.length.isEven ? bytes : bytes.sublist(0, bytes.length - 1);
    _setState(VoiceCallState.speaking);
    // flutter_sound 9.x interleaved feed (replaces the old foodSink/FoodData).
    _player.feedUint8FromStream(aligned);
  }

  // ───────────────────────────────────────────────────────────────
  // Teardown
  // ───────────────────────────────────────────────────────────────

  void _fail(String message) {
    _errorMessage = message;
    _setState(VoiceCallState.error);
    unawaited(_cleanup());
  }

  /// User tapped hang up.
  Future<void> hangUp() async {
    try {
      _channel?.sink.add(jsonEncode({'type': 'stop'}));
    } catch (_) {
      // socket already closing
    }
    await _cleanup();
    _setState(VoiceCallState.ended);
  }

  Future<void> _cleanup() {
    final existing = _cleanupFuture;
    if (existing != null) return existing;

    final future = _cleanupOnce();
    _cleanupFuture = future.whenComplete(() {
      _cleanupFuture = null;
    });
    return _cleanupFuture!;
  }

  Future<void> _cleanupOnce() async {
    await _micSub?.cancel();
    _micSub = null;
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {/* ignore */}

    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {/* ignore */}
    _channel = null;

    if (_playerOpen) {
      _playerOpen = false;
      try {
        await _player.closePlayer();
      } catch (_) {/* ignore */}
    }

    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {
      /* ignore */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_cleanup().whenComplete(_recorder.dispose));
    super.dispose();
  }
}
