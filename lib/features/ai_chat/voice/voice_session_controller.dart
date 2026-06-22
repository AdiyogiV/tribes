import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:audio_session/audio_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
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
///   mic (PCM16 16k) -> WebSocket relay -> Gemini brain -> TTS (PCM16 24k) -> speaker.
///
/// Transport-thin and UI-agnostic: the page just listens and renders. A short
/// filler clip plays on tap to cover the ~1-2s connect; the mic opens the
/// instant the relay is ready.
class VoiceSessionController extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer(logLevel: Level.off);

  WebSocketChannel? _channel;
  StreamSubscription? _socketSub;
  StreamSubscription<Uint8List>? _micSub;
  Future<void>? _cleanupFuture;

  bool _playerOpen = false;
  bool _disposed = false;

  // The mic opens once, after the greeting finishes AND the relay is ready, so
  // the greeting's question is never cut off and the user never talks into a
  // void. The greeting is a local PCM clip played instantly on tap (to mask
  // the connect latency), through the SAME flutter_sound player as replies so
  // it's loud and smooth — not a second audio engine.
  bool _micStarted = false;
  bool _greetingDone = false;
  bool _relayReady = false;
  final Random _random = Random();
  static const int _greetingCount = 10;

  // TTS playback is fed to flutter_sound ONE buffer at a time, awaited, so the
  // native player can apply backpressure. The relay bursts a whole reply at
  // once; without this queue the overlapping un-awaited feeds overflow the
  // player buffer and most of Aryabhatt's audio is silently dropped (he'd
  // "speak only a few words"). flutter_sound forbids two simultaneous feeds.
  final Queue<Uint8List> _ttsQueue = Queue<Uint8List>();
  bool _draining = false;
  bool _turnEndPending = false;

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

  /// Open audio devices, play a short filler clip to cover the connect, hook up
  /// the relay, then open the mic the moment the relay is ready.
  Future<void> start() async {
    if (_state != VoiceCallState.idle && _state != VoiceCallState.ended) return;
    _micStarted = _greetingDone = _relayReady = false;
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
      // Play the greeting INSTANTLY to mask the connect latency, AND connect in
      // parallel. Each flips its own flag; the mic opens once both are ready
      // (greeting finished AND relay ready) — see [_maybeStartMic].
      unawaited(_playGreeting());
      await _connect();
    } catch (e) {
      AppLogger.e('Voice session start failed',
          category: LogCategory.voice, error: e);
      _fail('Could not start the call');
    }
  }

  /// Play a random local greeting clip INSTANTLY on tap, through the same
  /// flutter_sound player as replies (so it's loud + smooth, no second engine).
  /// The clips are raw PCM16 @ 24kHz mono — the exact format the TTS stream
  /// uses — so we just feed the bytes through the normal playback queue. It
  /// asks a question, so we open the mic only after it finishes playing.
  Future<void> _playGreeting() async {
    try {
      final idx = _random.nextInt(_greetingCount);
      final data = await rootBundle.load('assets/audio/greeting_$idx.pcm');
      final bytes = data.buffer.asUint8List();
      const chunk = 8192;
      for (var i = 0; i < bytes.length; i += chunk) {
        final end = (i + chunk < bytes.length) ? i + chunk : bytes.length;
        _playAudio(Uint8List.sublistView(bytes, i, end));
      }
      // Mark done after the clip's real playback duration (2 bytes/sample).
      final seconds = bytes.length / (2 * VoiceRelayConfig.ttsSampleRate);
      await Future<void>.delayed(
          Duration(milliseconds: (seconds * 1000).ceil() + 200));
    } catch (e) {
      AppLogger.w('Voice greeting failed',
          category: LogCategory.voice, data: {'error': e.toString()});
    } finally {
      _greetingDone = true;
      _maybeStartMic();
    }
  }

  /// Open the mic exactly once, after the greeting has finished AND the relay
  /// is ready — so we never cut the greeting off or talk into a void.
  void _maybeStartMic() {
    if (_disposed || _micStarted) return;
    if (!_greetingDone || !_relayReady) return;
    if (_state == VoiceCallState.error || _state == VoiceCallState.ended) return;
    _micStarted = true;
    unawaited(_startMic());
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    // Speakerphone + LOUD. We must record the mic while playing replies, so
    // category is playAndRecord with defaultToSpeaker (routes to the loud
    // bottom speaker, not the earpiece). Crucially we use defaultMode, NOT
    // voiceChat/videoChat: those engage iOS voice-processing AGC which ducks
    // the output volume. Echo isn't an issue — the relay mutes the mic while
    // Aryabhatt is speaking.
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.allowBluetoothA2dp,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    ));
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
    await _player.setVolume(1.0); // play replies at full volume
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

    // Open the CX session on the relay. Fresh session id per call => each tap
    // starts a brand-new conversation (no carryover). Auth is the token.
    final sessionId = const Uuid().v4();
    _channel!.sink.add(jsonEncode({
      'type': 'start',
      'token': token,
      'sessionId': sessionId,
    }));
    AppLogger.i('Voice start frame sent',
        category: LogCategory.voice, data: {'sessionId': sessionId});
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
        // Relay is live. Don't grab the mic yet — wait for the greeting to
        // finish too (see _maybeStartMic).
        _relayReady = true;
        _maybeStartMic();
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
        _turnEndPending = false;
        _setState(VoiceCallState.speaking);
        break;
      case 'speaking_done':
        // Turn complete on the relay — but locally we may still be draining the
        // TTS queue. Only reopen the mic once the audio has actually finished
        // playing, otherwise we'd cut Aryabhatt off mid-sentence.
        AppLogger.i('Turn done',
            category: LogCategory.voice,
            data: {
              'ttsChunks': _ttsChunks,
              'ttsBytes': _ttsBytes,
              'queued': _ttsQueue.length,
              'draining': _draining,
            });
        if (_ttsQueue.isEmpty && !_draining) {
          _finishTurn();
        } else {
          _turnEndPending = true;
        }
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
    if (aligned.isEmpty) return;
    _setState(VoiceCallState.speaking);
    // Enqueue and drain sequentially with backpressure (see _ttsQueue docs).
    _ttsQueue.add(aligned);
    unawaited(_drainTts());
  }

  /// Feed queued TTS buffers to the player one at a time, awaiting each so the
  /// native side applies backpressure. Never run two feeds concurrently.
  Future<void> _drainTts() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_ttsQueue.isNotEmpty && _playerOpen && !_disposed) {
        final chunk = _ttsQueue.removeFirst();
        try {
          await _player.feedUint8FromStream(chunk);
        } catch (e) {
          AppLogger.w('Voice: TTS feed failed',
              category: LogCategory.voice, data: {'error': e.toString()});
          break;
        }
      }
    } finally {
      _draining = false;
    }
    // If the server already signalled end-of-turn while we were still playing,
    // reopen the mic now that the queue is empty.
    if (_turnEndPending && _ttsQueue.isEmpty) {
      _finishTurn();
    }
  }

  /// Reopen the floor to the user after Aryabhatt finishes speaking.
  void _finishTurn() {
    _turnEndPending = false;
    _userTranscript = '';
    if (_state == VoiceCallState.speaking ||
        _state == VoiceCallState.thinking) {
      _setState(VoiceCallState.listening);
    }
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
    _ttsQueue.clear();
    _turnEndPending = false;
    _micStarted = _greetingDone = _relayReady = false;
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
