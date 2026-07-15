import 'package:flutter/widgets.dart';

import 'package:aurogram/features/baba/domain/baba_context.dart';

/// A screen's live, structured view of what it is showing RIGHT NOW.
///
/// Returns the ACTUAL rendered data (not a static label) — e.g. the Daily
/// Insight screen returns today's theme + the sections currently on screen; the
/// Chart screen returns the placements being shown. Baba reads this via the
/// `whereAmI` tool, so it is pulled ON DEMAND and is therefore always current.
typedef BabaSnapshotProvider = Map<String, dynamic> Function();

/// Drop-in awareness for a screen: mix this into a [State], say which screen it
/// is, and return its live data. Registration/cleanup are handled for you.
///
/// ```dart
/// class _FooPageState extends State<FooPage> with BabaScreenAware<FooPage> {
///   @override
///   String get babaScreenKey => 'dailyInsight';
///   @override
///   Map<String, dynamic> babaSnapshot() => {'theme': _theme, 'sections': _n};
/// }
/// ```
///
/// This is the whole "wrap the app" contract from the screen's side — one key,
/// one snapshot method. The registry lives in [BabaContext] so both the voice
/// and text brains read from a single spine.
mixin BabaScreenAware<T extends StatefulWidget> on State<T> {
  /// The [BabaScreen.key] this screen corresponds to (matches BabaAppMap).
  String get babaScreenKey;

  /// The live, structured snapshot of what's on screen right now. Keep it small
  /// and factual — it's injected into Baba's context, not rendered.
  Map<String, dynamic> babaSnapshot();

  @override
  void initState() {
    super.initState();
    BabaContext.instance.registerSnapshot(babaScreenKey, babaSnapshot);
  }

  @override
  void dispose() {
    BabaContext.instance.unregisterSnapshot(babaScreenKey);
    super.dispose();
  }
}
