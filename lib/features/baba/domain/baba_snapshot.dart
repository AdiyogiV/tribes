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
///   * [step]     — stable id of the sub-step WITHIN this screen (e.g.
///                  'birthReading', 'phoneEntry'), so Baba's awareness is finer
///                  than route-level. Null when the screen has no sub-steps.
///   * [canProceed] / [blockedReason] — whether Baba can move forward from here
///                  right now, and if not, the human reason (he can say it).
///                  This is what lets a guided step honestly report "not yet".
///   * [availableActions] — the tool names / verbs Baba can meaningfully use on
///                  this screen right now, so he knows his options, not guesses.
///
/// Baba reads this via `whereAmI` and on EVERY tool result, so it is always
/// current — the authoritative "what is true on screen right now."
@immutable
class BabaSnapshot {
  const BabaSnapshot({
    this.status = BabaScreenStatus.ready,
    this.headline,
    this.facts = const {},
    this.items = const [],
    this.step,
    this.canProceed,
    this.blockedReason,
    this.availableActions = const [],
  });

  /// Convenience: the screen's content is ready.
  const BabaSnapshot.ready({
    String? headline,
    Map<String, Object?> facts = const {},
    List<String> items = const [],
    String? step,
    bool? canProceed,
    String? blockedReason,
    List<String> availableActions = const [],
  }) : this(
          status: BabaScreenStatus.ready,
          headline: headline,
          facts: facts,
          items: items,
          step: step,
          canProceed: canProceed,
          blockedReason: blockedReason,
          availableActions: availableActions,
        );

  /// Convenience: the screen is still loading its content.
  const BabaSnapshot.loading({String? headline, String? step, String? blockedReason})
      : this(
          status: BabaScreenStatus.loading,
          headline: headline,
          step: step,
          canProceed: false,
          blockedReason: blockedReason,
        );

  /// Convenience: the screen has nothing to show.
  const BabaSnapshot.empty({String? headline, String? step})
      : this(status: BabaScreenStatus.empty, headline: headline, step: step);

  /// Convenience: the screen failed to load its content.
  const BabaSnapshot.error({String? headline, String? step, String? blockedReason})
      : this(
          status: BabaScreenStatus.error,
          headline: headline,
          step: step,
          canProceed: false,
          blockedReason: blockedReason,
        );

  final BabaScreenStatus status;
  final String? headline;
  final Map<String, Object?> facts;
  final List<String> items;
  final String? step;
  final bool? canProceed;
  final String? blockedReason;
  final List<String> availableActions;

  bool get isEmpty =>
      headline == null &&
      facts.isEmpty &&
      items.isEmpty &&
      step == null &&
      availableActions.isEmpty;

  /// Structured form for the `whereAmI` tool result (`onScreen`).
  Map<String, dynamic> toJson() => {
        'status': status.name,
        if (headline != null && headline!.isNotEmpty) 'headline': headline,
        if (facts.isNotEmpty) 'facts': facts,
        if (items.isNotEmpty) 'items': items,
        if (step != null) 'step': step,
        if (canProceed != null) 'canProceed': canProceed,
        if (blockedReason != null && blockedReason!.isNotEmpty)
          'blockedReason': blockedReason,
        if (availableActions.isNotEmpty) 'availableActions': availableActions,
      };

  /// Compact one-line form for the spoken voice context (proactive narration).
  String toContextLine() {
    final parts = <String>[];
    if (status != BabaScreenStatus.ready) parts.add('(${status.name})');
    if (step != null) parts.add('step=$step');
    if (headline != null && headline!.isNotEmpty) parts.add(headline!);
    if (facts.isNotEmpty) {
      parts.add(facts.entries.map((e) => '${e.key}=${e.value}').join(', '));
    }
    if (items.isNotEmpty) parts.add('items: ${items.join(', ')}');
    if (canProceed == false && (blockedReason?.isNotEmpty ?? false)) {
      parts.add('blocked: $blockedReason');
    }
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
