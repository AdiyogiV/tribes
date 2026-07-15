import 'package:flutter/foundation.dart';

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
    AppLogger.d('BabaContext: location -> $uri',
        category: LogCategory.voice);
    notifyListeners();
  }

  /// A screen announces salient visible content. [speak] true asks Baba to
  /// narrate it now (proactive); false just makes it available to `whereAmI`
  /// (silent awareness). No-op narration unless a call is live.
  void publish(String detail, {bool speak = false}) {
    _detail = detail.trim();
    notifyListeners();
    // Feed the live session: the controller stores it and (if connected) sends
    // it. speak=false => ambient; speak=true => Baba reacts now.
    _voice.updateScreenContext(describeForVoice(), speak: speak);
  }

  /// Drop any screen-published detail (call on screen dispose if it set one).
  void clearDetail() {
    if (_detail == null) return;
    _detail = null;
    notifyListeners();
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
  Map<String, dynamic>? _currentSnapshot() {
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

  /// Structured snapshot for the `whereAmI` tool.
  Map<String, dynamic> snapshot() {
    final s = screen;
    final live = _currentSnapshot();
    return {
      'route': _location,
      'screen': s?.key ?? 'unknown',
      'label': s?.label ?? 'Unknown',
      'description': s?.description ?? '',
      if (_detail != null && _detail!.isNotEmpty) 'visible': _detail,
      // The real, live rendered data for this screen — the heart of Baba's
      // page awareness. Absent when the screen hasn't registered a provider.
      if (live != null) 'onScreen': live,
    };
  }

  /// One-line context string suitable for injecting into the voice session.
  String describeForVoice() {
    final base = BabaAppMap.describe(_location);
    final parts = <String>[base];
    if (_detail != null && _detail!.isNotEmpty) {
      parts.add('On screen now: $_detail');
    }
    // Fold in the live snapshot as a compact key=value line so proactive
    // narration (publish) carries the real data, matching what whereAmI pulls.
    final live = _currentSnapshot();
    if (live != null) {
      final flat = live.entries
          .map((e) => '${e.key}=${_compact(e.value)}')
          .join(', ');
      if (flat.isNotEmpty) parts.add('Showing: $flat');
    }
    return parts.join(' ');
  }

  /// Stringify a snapshot value compactly for the one-line voice context.
  static String _compact(dynamic v) {
    if (v is Map) return '{${v.length} fields}';
    if (v is List) return '[${v.length}]';
    final s = v.toString();
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }
}
