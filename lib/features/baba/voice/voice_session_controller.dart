import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/baba/voice/voice_relay_config.dart';
import 'package:aurogram/features/baba/voice/voice_engine_pref.dart';
import 'package:aurogram/features/baba/voice/voice_mic_mode_pref.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';

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
  // App-scoped singleton. Baba's voice session must OUTLIVE any single widget
  // (the dashboard cow, the shell orb, a chat page) so a live call survives
  // navigation and hands off between presences. Every `VoiceSessionController()`
  // returns this one instance; it is never disposed for the app's lifetime.
  VoiceSessionController._();
  static final VoiceSessionController _instance = VoiceSessionController._();
  factory VoiceSessionController() => _instance;

  final AudioRecorder _recorder = AudioRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer(logLevel: Level.off);

  WebSocketChannel? _channel;
  StreamSubscription? _socketSub;
  StreamSubscription<Uint8List>? _micSub;
  Future<void>? _cleanupFuture;

  bool _playerOpen = false;
  bool _disposed = false;

  // The mic opens once, as soon as the relay is ready. No greeting any more:
  // the user simply starts talking and Aryabhatt (Gemini Live API) replies.
  bool _micStarted = false;
  bool _relayReady = false;

  // How the mic behaves this call (read once at start, see [VoiceMicModePref]).
  // waitTurn (default): only forward mic audio while it's the user's turn
  // (listening) so Aryabhatt's voice / room noise can't leak in. openMic:
  // stream the whole call so the user can talk over him (barge-in, Live only).
  VoiceMicMode _micMode = VoiceMicMode.waitTurn;

  // Which engine this call uses (read once at start). The relay routes on it,
  // and it also drives the smart mic-mode default (Live→openMic, CX→waitTurn).
  VoiceEngine _engine = VoiceEngine.live;

  // Native player ring-buffer size = ~1s of 24kHz PCM16 (48000 B/s). The Live
  // API streams Aryabhatt's voice in fast BURSTS (often a whole sentence at
  // once), so a small buffer underruns the moment the event loop is busy with
  // the mic stream / websocket / logging => audible stutter. ~1s of headroom
  // rides those bursts smoothly. It's also the per-feed coalesce cap: barge-in
  // is now server-side (the relay emits an explicit `interrupt`), so we no
  // longer need a tiny cap to stay interruptible — on interrupt we clear the
  // queue and only this ~1s already in the native buffer fades out.
  static const int _playerBufferBytes = 49152;

  // PCM16 mono bytes the player consumes per second at the (sped-up) playback
  // rate — used to estimate when fed audio has finished playing out. Must use
  // the PLAYBACK rate (ttsSampleRate x playbackSpeed), not the source rate.
  static int get _playbackBytesPerSec =>
      VoiceRelayConfig.ttsPlaybackSampleRate * 2;

  // Acoustic tail added after the computed playout end before re-arming the
  // mic: covers speaker decay + AEC settle so the last syllable can't leak in.
  static const Duration _micReopenGuard = Duration(milliseconds: 250);

  // TTS playback is fed to flutter_sound ONE buffer at a time, awaited, so the
  // native player can apply backpressure. The relay bursts a whole reply at
  // once; without this queue the overlapping un-awaited feeds overflow the
  // player buffer and most of Aryabhatt's audio is silently dropped (he'd
  // "speak only a few words"). flutter_sound forbids two simultaneous feeds.
  final Queue<Uint8List> _ttsQueue = Queue<Uint8List>();
  bool _draining = false;
  bool _turnEndPending = false;

  // Wall-clock playback tracking. The native player buffers up to ~1s of audio
  // (_playerBufferBytes), so "the TTS queue is empty" does NOT mean Aryabhatt
  // has stopped coming out of the speaker — up to a second of his voice is
  // still playing out. We record when playback began and how many bytes we've
  // fed this turn, then re-arm the mic only once that audio has actually played
  // out (+ a short acoustic tail). Otherwise the mic reopens over his own voice
  // and the relay transcribes his echo => he talks to himself. This is the ONLY
  // echo guard for Standard/CX, whose relay has none of its own.
  DateTime? _playbackStartedAt;
  int _playbackBytesFed = 0;
  Timer? _finishTurnTimer;
  // Set the instant a barge-in (interrupt) arrives. While true, any TTS audio
  // still in flight from the cut-off turn is dropped so it can't sneak into the
  // player after we've flushed it. Cleared when the next reply begins.
  bool _suppressAudio = false;

  // Flow counters so the logs tell the whole story of a call.
  int _ttsChunks = 0; // TTS audio frames received from the relay
  int _ttsBytes = 0;
  int _micChunks = 0; // mic frames sent to the relay
  int _micBytes = 0;

  VoiceCallState _state = VoiceCallState.idle;
  String _userTranscript = '';
  String _aryabhattReply = '';
  String? _errorMessage;

  /// When set, forces the voice engine for the NEXT call regardless of the
  /// user's saved preference. Onboarding sets this to [VoiceEngine.live] because
  /// tool-calling only flows over the Live engine (CX can't). Cleared by the
  /// screen on exit.
  VoiceEngine? engineOverride;

  /// When set, appended to Baba's system prompt for the NEXT call to give him a
  /// task for the current screen (e.g. "guide onboarding"). Keeps ONE persona;
  /// this is just his job right now. Cleared by the screen on exit.
  String? directiveOverride;

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

  /// Open audio devices, hook up the relay, then open the mic the moment the
  /// relay is ready.
  Future<void> start() async {
    if (_state != VoiceCallState.idle && _state != VoiceCallState.ended) return;
    _micStarted = _relayReady = false;
    // Engine: an explicit override wins (onboarding forces Live for its
    // latency-sensitive co-authoring), otherwise honour the user's saved pref.
    // BOTH engines now support tool-calling — Live via streamed declarations,
    // CX via Function tools provisioned on the agent — so tools no longer force
    // an engine. CX is the credit-funded default; Live is premium.
    _engine = engineOverride ?? await VoiceEnginePref.read();
    _micMode = await VoiceMicModePref.effectiveFor(_engine);
    // Clear last call's transcript + reply so a fresh tap never flashes stale
    // text in the caption before the first reply.
    _userTranscript = '';
    _aryabhattReply = '';
    _suppressAudio = false;
    _finishTurnTimer?.cancel();
    _playbackStartedAt = null;
    _playbackBytesFed = 0;
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
      // If we were torn down during the permission prompt / audio setup (e.g.
      // the app was backgrounded), abort instead of connecting a zombie socket
      // that would fire its own kickoff turn.
      if (_state != VoiceCallState.connecting) return;
      // Connect to the relay; the mic opens the moment it's ready (see
      // [_maybeStartMic]). No greeting — the user speaks first.
      await _connect();
    } catch (e, st) {
      AppLogger.e('Voice session start failed',
          category: LogCategory.voice, error: e, stackTrace: st);
      // Surface the real reason (audio session / player / relay) instead of a
      // generic message — a swallowed exception makes web failures impossible
      // to diagnose from the field.
      _fail('Could not start the call: $e');
    }
  }

  /// Open the mic exactly once, as soon as the relay is ready.
  void _maybeStartMic() {
    if (_disposed || _micStarted) return;
    if (!_relayReady) return;
    if (_state == VoiceCallState.error || _state == VoiceCallState.ended) return;
    _micStarted = true;
    unawaited(_startMic());
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    // Speakerphone + echo cancellation. category playAndRecord (we record the
    // mic while playing replies) with defaultToSpeaker (loud bottom speaker,
    // not the earpiece) and allowBluetooth so headphones/AirPods just work.
    //
    // mode = videoChat: this engages iOS hardware echo cancellation, which
    // ERASES Aryabhatt's own voice from the mic. That's what lets talk-to-
    // interrupt (barge-in) work WITHOUT the speaker echo false-triggering it.
    // videoChat (not voiceChat) keeps the loud speakerphone route. There's a
    // mild volume dip vs defaultMode — the trade for echo-free full-duplex.
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.allowBluetoothA2dp,
      avAudioSessionMode: AVAudioSessionMode.videoChat,
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
    await _startPlayerStream();
    _playerOpen = true;
  }

  /// Start the PCM16 streaming player. The stream stays up for the whole call
  /// — even barge-in no longer restarts it (see [_flushPlayback]).
  Future<void> _startPlayerStream() async {
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
sampleRate: VoiceRelayConfig.ttsPlaybackSampleRate,
      interleaved: true,
      // ~340ms of 24kHz PCM16 audio. Generous enough to ride bursts (and the
      // event-loop jank from the parallel connect) without underrunning.
      bufferSize: _playerBufferBytes,
    );
    await _player.setVolume(1.0); // play replies at full volume
  }

  /// Barge-in: the user cut in while Aryabhatt was speaking. We DON'T stop the
  /// native player (stopPlayer() tears down the iOS audio unit and drops the
  /// route, which spawned a whole chain of bugs). Instead we just drop
  /// everything not yet played — clear the queue, and [_suppressAudio] (set by
  /// the caller) discards any chunks still in flight from the cut-off turn.
  /// The ~340ms already in the native buffer drains on its own = a quick, clean
  /// fade instead of a hard cut with a click. The stream keeps running, so the
  /// next reply just feeds straight into it.
  void _flushPlayback() {
    _ttsQueue.clear();
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
    // `engine` lets the user pick Live (premium) vs CX (credit-funded) — the
    // relay falls back to its own default if we send nothing.
    final sessionId = const Uuid().v4();
    final engine = _engine;
    // Hand Baba the WHITELISTED tools registered for the current surface, so he
    // can act (not just talk). Empty list => a plain conversational session.
    final tools = BabaToolRegistry.instance.declarations;
    _channel!.sink.add(jsonEncode({
      'type': 'start',
      'token': token,
      'sessionId': sessionId,
      'engine': VoiceEnginePref.wireValue(engine),
      if (tools.isNotEmpty) 'tools': tools,
      if (directiveOverride != null && directiveOverride!.isNotEmpty)
        'directive': directiveOverride,
    }));
    AppLogger.i('Voice start frame sent',
        category: LogCategory.voice,
        data: {
          'sessionId': sessionId,
          'engine': engine.name,
          'micMode': _micMode.name,
          'tools': tools.length,
        });
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
      // Half-duplex (waitTurn): hold the mic shut unless it's the user's turn,
      // so Aryabhatt's own voice / room noise never reaches the relay. The mic
      // stream itself stays open (no start/stop churn) — we just don't forward.
      if (_micMode == VoiceMicMode.waitTurn &&
          _state != VoiceCallState.listening) {
        return;
      }
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
        // Relay is live — open the mic right away so the user can talk.
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
        // A fresh turn's audio is about to arrive — cancel any pending mic
        // re-arm and reset the playback clock so this turn is measured on its
        // own (the CX flow emits one 'reply' per turn before its audio).
        _finishTurnTimer?.cancel();
        _playbackStartedAt = null;
        _playbackBytesFed = 0;
        // A fresh reply is starting — stop dropping audio (any barge-in flush
        // is done; from here the incoming chunks belong to THIS turn).
        _suppressAudio = false;
        _setState(VoiceCallState.speaking);
        break;
      case 'interrupt':
        // Barge-in: user started talking over Aryabhatt. Kill playback now and
        // give them the floor. STT keeps running on the relay, so their actual
        // utterance will come back as the next transcript/reply.
        AppLogger.i('Barge-in: user interrupted',
            category: LogCategory.voice,
            data: {'queued': _ttsQueue.length, 'draining': _draining});
        _suppressAudio = true;
        _turnEndPending = false;
        _finishTurnTimer?.cancel();
        _flushPlayback();
        if (_state == VoiceCallState.speaking) {
          _setState(VoiceCallState.listening);
        }
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
          _scheduleFinishTurn();
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
      case 'tool_call':
        // Baba wants to DO something (navigate, set a field, etc). Dispatch to
        // the whitelisted registry and send the result back so he can react.
        unawaited(_handleToolCall(msg));
        break;
    }
  }

  /// Execute a tool Baba requested and return the result to the relay.
  Future<void> _handleToolCall(Map<String, dynamic> msg) async {
    final id = msg['id'] as String?;
    final name = (msg['name'] as String?) ?? '';
    final args = (msg['args'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    AppLogger.i('Baba tool_call',
        category: LogCategory.voice,
        data: {'id': id, 'name': name, 'args': args});
    final result = await BabaToolRegistry.instance.dispatch(name, args);
    _channel?.sink.add(jsonEncode({
      'type': 'tool_response',
      'id': id,
      'name': name,
      'response': result,
    }));
    AppLogger.i('Baba tool_response',
        category: LogCategory.voice,
        data: {'id': id, 'name': name, 'result': result});
  }

  void _playAudio(Uint8List bytes) {
    if (!_playerOpen || bytes.isEmpty) {
      AppLogger.w('Voice: dropped TTS chunk',
          category: LogCategory.voice,
          data: {'playerOpen': _playerOpen, 'bytes': bytes.length});
      return;
    }
    // Barge-in in progress: discard audio left over from the cut-off turn so it
    // can't slip into the player after the flush.
    if (_suppressAudio) return;
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

  /// Feed queued TTS buffers to the player, awaiting each so the native side
  /// applies backpressure. We coalesce queued chunks into one buffer per feed
  /// (flutter_sound stutters when fed many tiny chunks back-to-back) capped at
  /// [_playerBufferBytes] (~1s). The cap keeps each feed bounded so the loop
  /// can re-check [_suppressAudio] between feeds and bail promptly on a
  /// server-driven barge-in. Never run two feeds concurrently.
  Future<void> _drainTts() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_ttsQueue.isNotEmpty && _playerOpen && !_disposed) {
        // Barge-in landed: drop the rest of the cut-off turn. Only what's
        // already in the native buffer plays out (a short, clean fade).
        if (_suppressAudio) {
          _ttsQueue.clear();
          break;
        }
        // Coalesce up to one buffer's worth, no more (see cap rationale above).
        var total = 0;
        final parts = <Uint8List>[];
        while (_ttsQueue.isNotEmpty && total < _playerBufferBytes) {
          final c = _ttsQueue.removeFirst();
          parts.add(c);
          total += c.length;
        }
        final merged = Uint8List(total);
        var offset = 0;
        for (final p in parts) {
          merged.setAll(offset, p);
          offset += p.length;
        }
        try {
          // Mark the start of playout BEFORE the feed, not after. The player
          // buffers only ~1s, so feedUint8FromStream applies backpressure and
          // BLOCKS for most of a long buffer's duration while it drains. If we
          // stamped the clock after the await, that blocked time (seconds, for
          // a full reply) wouldn't count toward playout — so _scheduleFinishTurn
          // would then wait the entire duration AGAIN, re-arming the mic seconds
          // late (long, awkward dead air after he stops). Stamping before the
          // feed anchors the clock at the moment audio actually starts playing.
          _playbackStartedAt ??= DateTime.now();
          await _player.feedUint8FromStream(merged);
          _playbackBytesFed += merged.length;
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
      _scheduleFinishTurn();
    }
  }

  /// Re-arm the mic only AFTER Aryabhatt's audio has actually played out of the
  /// speaker. The relay's `speaking_done` (and an emptied queue) only mean we've
  /// FED every byte to the native player — up to ~1s is still buffered and
  /// audibly playing. Re-arming the mic then makes it capture his own tail,
  /// which the (guard-less) CX relay transcribes => he replies to himself.
  ///
  /// So we compute when the fed audio finishes from a playback clock
  /// (bytes ÷ playback byte-rate, anchored at first feed) and delay the mic
  /// re-arm until then + a short acoustic tail. Deterministic, no polling.
  void _scheduleFinishTurn() {
    _finishTurnTimer?.cancel();
    final started = _playbackStartedAt;
    Duration delay = _micReopenGuard;
    if (started != null && _playbackBytesFed > 0) {
      final playoutMs =
          (_playbackBytesFed * 1000 / _playbackBytesPerSec).ceil();
      final elapsedMs = DateTime.now().difference(started).inMilliseconds;
      final remainingMs = (playoutMs - elapsedMs).clamp(0, playoutMs);
      delay = Duration(milliseconds: remainingMs) + _micReopenGuard;
    }
    if (delay <= Duration.zero) {
      _finishTurn();
      return;
    }
    _finishTurnTimer = Timer(delay, _finishTurn);
  }

  /// Reopen the floor to the user after Aryabhatt finishes speaking.
  void _finishTurn() {
    _finishTurnTimer?.cancel();
    _turnEndPending = false;
    _userTranscript = '';
    _playbackStartedAt = null;
    _playbackBytesFed = 0;
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

  /// User tapped "my turn": cut Aryabhatt off mid-sentence and hand the floor
  /// back to the mic. This is the CLIENT-initiated twin of the server-driven
  /// `interrupt` control frame — needed because in waitTurn (half-duplex) mode
  /// the mic is muted while he speaks, so the user has no voice-only way to
  /// barge in. We locally drop everything not yet played (the ~340ms already in
  /// the native buffer fades out cleanly), tell the relay to stop generating
  /// too, and flip to [VoiceCallState.listening] which unmutes the mic.
  ///
  /// Safe if the relay ignores the frame: [_suppressAudio] keeps discarding the
  /// cut-off turn's audio until the next `reply` arrives, so he can't sneak back
  /// in. Only meaningful while actually speaking; a no-op otherwise.
  void interruptAndListen() {
    if (_state != VoiceCallState.speaking &&
        _state != VoiceCallState.thinking) {
      return;
    }
    AppLogger.i('User interrupt: taking the floor',
        category: LogCategory.voice,
        data: {'queued': _ttsQueue.length, 'draining': _draining});
    _suppressAudio = true;
    _turnEndPending = false;
    _finishTurnTimer?.cancel();
    _flushPlayback();
    try {
      _channel?.sink.add(jsonEncode({'type': 'interrupt'}));
    } catch (_) {
      // socket already closing — local suppression still handles it
    }
    _setState(VoiceCallState.listening);
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
    _finishTurnTimer?.cancel();
    _playbackStartedAt = null;
    _playbackBytesFed = 0;
    _micStarted = _relayReady = false;
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

    // Close the player between calls on native platforms only. On WEB we must
    // NOT close it: flutter_sound's web plugin re-injects its <script> tags on
    // every openPlayer(), and the second injection throws
    // "Identifier FLUTTER_SOUND_VERSION has already been declared" (likewise
    // PLAYER_VERSION / RECORDER_VERSION). That permanently breaks the player
    // module (initializeMediaPlayer becomes undefined) and kills every
    // subsequent call. Keeping the one player instance open across calls means
    // openPlayer() runs exactly once per page load, so nothing is re-injected.
    // The PCM stream is designed to stay up for the whole session anyway.
    if (_playerOpen && !kIsWeb) {
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
