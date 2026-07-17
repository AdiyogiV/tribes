import 'package:flutter/widgets.dart';

import 'package:aurogram/features/baba/domain/baba_context.dart';

/// Readiness of what a screen is showing, so Baba never guesses "loaded" vs
/// "still loading" vs "nothing here."
enum BabaScreenStatus { loading, ready, empty, error }

/// A screen's live, structured view of what it is showing RIGHT NOW.
///
/// This is the ONE shape every screen speaks, so Baba's page awareness is
/// uniform and scalable (no more each-screen-invents-its-own-keys). Keep it
/// small and factual — it's injected into Baba's context, not rendered, and the
/// voice prompt has a hard token budget.
///
///   * [status]   — loading / ready / empty / error.
///   * [headline] — ONE human line summarising what's on screen (Baba can read
///                  this almost verbatim).
///   * [facts]    — a few citable key -> value pairs (e.g. sunSign: Leo).
///   * [items]    — visible item labels, e.g. the section titles on screen.
///
/// Baba reads this via `whereAmI`, pulled ON DEMAND, so it is always current.
@immutable
class BabaSnapshot {
  const BabaSnapshot({
    this.status = BabaScreenStatus.ready,
    this.headline,
    this.facts = const {},
    this.items = const [],
  });

  /// Convenience: the screen's content is ready.
  const BabaSnapshot.ready({String? headline, Map<String, Object?> facts = const {}, List<String> items = const []})
      : this(status: BabaScreenStatus.ready, headline: headline, facts: facts, items: items);

  /// Convenience: the screen is still loading its content.
  const BabaSnapshot.loading({String? headline})
      : this(status: BabaScreenStatus.loading, headline: headline);

  /// Convenience: the screen has nothing to show.
  const BabaSnapshot.empty({String? headline})
      : this(status: BabaScreenStatus.empty, headline: headline);

  /// Convenience: the screen failed to load its content.
  const BabaSnapshot.error({String? headline})
      : this(status: BabaScreenStatus.error, headline: headline);

  final BabaScreenStatus status;
  final String? headline;
  final Map<String, Object?> facts;
  final List<String> items;

  bool get isEmpty =>
      headline == null && facts.isEmpty && items.isEmpty;

  /// Structured form for the `whereAmI` tool result (`onScreen`).
  Map<String, dynamic> toJson() => {
        'status': status.name,
        if (headline != null && headline!.isNotEmpty) 'headline': headline,
        if (facts.isNotEmpty) 'facts': facts,
        if (items.isNotEmpty) 'items': items,
      };

  /// Compact one-line form for the spoken voice context (proactive narration).
  String toContextLine() {
    final parts = <String>[];
    if (status != BabaScreenStatus.ready) parts.add('(${status.name})');
    if (headline != null && headline!.isNotEmpty) parts.add(headline!);
    if (facts.isNotEmpty) {
      parts.add(facts.entries.map((e) => '${e.key}=${e.value}').join(', '));
    }
    if (items.isNotEmpty) parts.add('items: ${items.join(', ')}');
    return parts.join(' | ');
  }
}

/// Returns the CURRENT [BabaSnapshot] for a screen, pulled on demand.
typedef BabaSnapshotProvider = BabaSnapshot Function();

/// Drop-in awareness for a screen: mix this into a [State], say which screen it
/// is, and return its live [BabaSnapshot]. Registration/cleanup are automatic.
///
/// ```dart
/// class _FooPageState extends State<FooPage> with BabaScreenAware<FooPage> {
///   @override
///   String get babaScreenKey => 'dailyInsight';
///   @override
///   BabaSnapshot babaSnapshot() => BabaSnapshot.ready(
///         headline: "Today's insight: $_theme",
///         facts: {'theme': _theme},
///         items: _sectionTitles,
///       );
/// }
/// ```
///
/// This is the whole "wrap the app" contract from the screen's side — one key,
/// one snapshot method. The registry lives in [BabaContext] so both the voice
/// and text brains read from a single spine.
mixin BabaScreenAware<T extends StatefulWidget> on State<T> {
  /// The [BabaScreen.key] this screen corresponds to (matches BabaAppMap).
  String get babaScreenKey;

  /// The live, structured snapshot of what's on screen right now.
  BabaSnapshot babaSnapshot();

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
