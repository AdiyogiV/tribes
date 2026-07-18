import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/routing/app_router.dart';
import 'package:aurogram/features/baba/domain/baba_app_map.dart';
import 'package:aurogram/features/baba/domain/baba_snapshot.dart';
import 'package:aurogram/features/baba/voice/voice_session_controller.dart';

/// Baba's situational awareness — the ONE source of truth for "where is the
/// user and what are they seeing."
///
/// ## Why this is the clean, scalable spine
/// The router already knows the current screen on EVERY navigation. So instead
/// of every screen spoon-feeding Baba ("I am the reveal screen…"), we listen to
/// the router once and derive location automatically via [BabaAppMap]. Zero
/// per-screen code for location awareness — add a route to the map and Baba
/// knows it.
///
/// Two channels:
///   * **Ambient (automatic):** location, updated by the router. Baba PULLS it
///     on demand via the `whereAmI` tool — nothing is spoken unless he chooses
///     to. This is what makes him always-aware without narrating every tap.
///   * **Proactive (opt-in):** a screen with rich, worth-announcing content
///     calls [publish] to add a detail line and (optionally) have Baba narrate
///     it now — e.g. the chart reveal. Cleared automatically on navigation.
class BabaContext extends ChangeNotifier {
  BabaContext._();
  static final BabaContext instance = BabaContext._();

  // Lazy so BabaContext's core role — location + the screen-snapshot spine —
  // never forces the voice singleton (and its AudioRecorder platform channel)
  // into existence. Only publish()/proactive narration touches voice.
  VoiceSessionController? _voiceRef;
  VoiceSessionController get _voice => _voiceRef ??= VoiceSessionController();

  String _location = '/';
  String? _detail; // optional visible-content line published by a screen
  bool _attached = false;

  // Monotonic version of the world model. Bumped on EVERY change Baba should
  // know about — route change, published detail, or a screen signalling its
  // own state moved (markStateChanged). It lets consumers (and the Live push
  // path) coalesce: "have I already reflected this state?" without diffing the
  // whole model. Never resets for the app's lifetime.
  int _stateVersion = 0;

  /// Monotonic version of the world model (see [worldState]).
  int get stateVersion => _stateVersion;

  // Live, structured snapshot providers keyed by BabaScreen.key. Pulled on
  // demand at snapshot() time, so what Baba reads is always current. This is
  // the "wrap the app" spine: screens register via [registerSnapshot] (usually
  // through the BabaScreenAware mixin).
  final Map<String, BabaSnapshotProvider> _snapshots = {};

  /// Current concrete route (URI path), e.g. `/astrology/insight`.
  String get location => _location;

  /// The known screen for the current location (null if unmapped).
  BabaScreen? get screen => BabaAppMap.match(_location);

  /// Screen-published visible content, if any.
  String? get detail => _detail;

  /// Begin observing the router. Call once, after [appRouter] is created.
  /// Idempotent.
  void attach() {
    if (_attached) return;
    _attached = true;
    appRouter.routerDelegate.addListener(_onRouteChanged);
    _onRouteChanged(); // seed with the initial location
  }

  void _onRouteChanged() {
    final uri = appRouter.routerDelegate.currentConfiguration.uri.toString();
    if (uri == _location) return;
    _location = uri;
    // A new screen invalidates the previous screen's published detail.
    _detail = null;
    _stateVersion++;
    AppLogger.d('BabaContext: location -> $uri (v$_stateVersion)',
        category: LogCategory.voice);
    notifyListeners();
    _maybePushSilentDelta();
  }

  /// A screen announces salient visible content. [speak] true asks Baba to
  /// narrate it now (proactive); false just makes it available to `whereAmI`
  /// (silent awareness). No-op narration unless a call is live.
  void publish(String detail, {bool speak = false}) {
    _detail = detail.trim();
    _stateVersion++;
    notifyListeners();
    // Feed the live session: the controller stores it and (if connected) sends
    // it. speak=false => ambient; speak=true => Baba reacts now.
    _voice.updateScreenContext(describeForVoice(), speak: speak);
  }

  /// Drop any screen-published detail (call on screen dispose if it set one).
  void clearDetail() {
    if (_detail == null) return;
    _detail = null;
    _stateVersion++;
    notifyListeners();
  }

  /// A screen signals that its OWN live state moved (a sub-step advanced, its
  /// content finished loading, a field was filled) — something Baba should be
  /// aware of even though the route did not change. Bumps the version and, on a
  /// silent-capable engine (Live), streams a silent delta. Engine-agnostic: on
  /// CX this is a no-op push (awareness rides tool results), so screens can call
  /// it freely without worrying about the transport.
  ///
  /// [screenKey] guards against a stale, backgrounded screen: the signal only
  /// counts when it is still the current screen.
  void markStateChanged([String? screenKey]) {
    if (screenKey != null && screen?.key != screenKey) return;
    _stateVersion++;
    notifyListeners();
    _maybePushSilentDelta();
  }

  /// Like [markStateChanged], but flags the delta as IMPORTANT: worth a turn on
  /// EVERY engine (including CX, where ambient deltas are otherwise a no-op),
  /// and SPOKEN so Baba audibly acknowledges it. Reserve for high-value
  /// transitions the user must feel Baba noticed — e.g. sign-in succeeded and we
  /// moved to the dashboard. Keep it rare (each one costs a CX turn).
  void announceStateChange([String? screenKey]) {
    if (screenKey != null && screen?.key != screenKey) return;
    _stateVersion++;
    notifyListeners();
    _maybePushSilentDelta(important: true);
  }

  /// Push the current world state to a LIVE call, without ever forcing the voice
  /// singleton into existence (only if it already exists AND a call is live).
  /// A normal (ambient) delta is a no-op on CX — awareness there rides tool
  /// results — but an [important] one goes through on every engine and is spoken.
  void _maybePushSilentDelta({bool important = false}) {
    final v = _voiceRef;
    if (v == null || !v.isCallLive) return;
    v.pushWorldState(worldState(), silent: !important, important: important);
  }

  /// Wait for the world model to SETTLE after an action, so it is safe to read
  /// [worldState]/[snapshot] and get the TRUE resulting state. "Settled" means
  /// [stateVersion] has stopped moving for a few consecutive frames — which
  /// uniformly covers a synchronous route swap, a DEFERRED (post-frame)
  /// navigation like sign-in success, and the destination screen's initState
  /// registering its snapshot provider.
  ///
  /// This is the ONE owner of "has the UI caught up?" — every tool result and
  /// navigation awaits it instead of guessing a fixed frame count (which lost
  /// the race against deferred navigation and read stale/blank state). Bounded
  /// by [timeout] so a transition that never quiesces can't hang a tool result;
  /// returns immediately when there's no binding (unit tests).
  Future<void> settle({
    Duration timeout = const Duration(milliseconds: 1500),
    int quietFrames = 3,
  }) async {
    final deadline = DateTime.now().add(timeout);
    var stable = 0;
    var last = _stateVersion;
    while (DateTime.now().isBefore(deadline)) {
      try {
        await WidgetsBinding.instance.endOfFrame;
      } catch (_) {
        return; // no binding (tests) — nothing to wait on
      }
      final v = _stateVersion;
      if (v == last) {
        if (++stable >= quietFrames) return;
      } else {
        stable = 0;
        last = v;
      }
    }
  }

  /// Register a live snapshot provider for a screen (keyed by [BabaScreen.key]).
  /// Called automatically by the [BabaScreenAware] mixin in initState.
  void registerSnapshot(String screenKey, BabaSnapshotProvider provider) {
    _snapshots[screenKey] = provider;
  }

  /// Remove a screen's snapshot provider (mixin calls this in dispose).
  void unregisterSnapshot(String screenKey) {
    _snapshots.remove(screenKey);
  }

  /// The live data for the CURRENT screen, if it registered a provider.
  /// Pulled fresh every call. Failures are swallowed — an aware screen must
  /// never break `whereAmI`.
  BabaSnapshot? _currentSnapshot() {
    final key = screen?.key;
    if (key == null) return null;
    final provider = _snapshots[key];
    if (provider == null) return null;
    try {
      final data = provider();
      return data.isEmpty ? null : data;
    } catch (e) {
      AppLogger.w('BabaContext: snapshot provider for "$key" threw: $e',
          category: LogCategory.voice);
      return null;
    }
  }

  /// The canonical, authoritative world state. This is what Baba perceives —
  /// via `whereAmI` (pull) and appended to EVERY tool result (observe-on-act),
  /// so he can never act on stale or blind assumptions. Carries the route, the
  /// screen, the live sub-`step`, the version, whether he can proceed, the
  /// actions available here, and the full structured `onScreen` content.
  Map<String, dynamic> worldState() {
    final s = screen;
    final live = _currentSnapshot();
    final map = <String, dynamic>{
      'route': _location,
      'screen': s?.key ?? 'unknown',
      'label': s?.label ?? 'Unknown',
      'description': s?.description ?? '',
      'stateVersion': _stateVersion,
    };
    if (_detail != null && _detail!.isNotEmpty) map['visible'] = _detail;
    if (live != null) {
      // The real, live rendered data for this screen — the heart of Baba's
      // page awareness. Absent when the screen hasn't registered a provider.
      map['onScreen'] = live.toJson();
      if (live.step != null) map['step'] = live.step;
      if (live.canProceed != null) map['canProceed'] = live.canProceed;
      if (live.blockedReason != null && live.blockedReason!.isNotEmpty) {
        map['blockedReason'] = live.blockedReason;
      }
      if (live.availableActions.isNotEmpty) {
        map['availableActions'] = live.availableActions;
      }
    }
    return map;
  }

  /// Structured snapshot for the `whereAmI` tool. Alias of [worldState] so the
  /// tool keeps working while `worldState` is the canonical name.
  Map<String, dynamic> snapshot() => worldState();

  /// One-line context string suitable for injecting into the voice session.
  String describeForVoice() {
    final base = BabaAppMap.describe(_location);
    final parts = <String>[base];
    if (_detail != null && _detail!.isNotEmpty) {
      parts.add('On screen now: $_detail');
    }
    // Fold in the typed live snapshot as a compact line so proactive narration
    // (publish) carries the real data, matching what whereAmI pulls.
    final live = _currentSnapshot();
    if (live != null) {
      final line = live.toContextLine();
      if (line.isNotEmpty) parts.add('Showing: $line');
    }
    return parts.join(' ');
  }
}
