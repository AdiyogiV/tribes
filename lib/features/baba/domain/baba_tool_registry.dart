import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

import 'package:aurogram/features/baba/domain/baba_context.dart';

/// Result a tool handler returns to Baba.
typedef BabaToolHandler = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> args);

/// A single action Baba is allowed to perform on the app.
///
/// [parameters] is a JSON-Schema object (the Gemini functionDeclaration
/// `parameters` shape). [defaultHandler] runs the action; a screen may override
/// it at runtime with [BabaToolRegistry.bindHandler] WITHOUT changing the
/// declaration (see the registry docs for why that matters).
class BabaTool {
  const BabaTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.defaultHandler,
    this.appendsWorldState = true,
    this.isMutation = false,
    this.requiresRequestId = false,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final BabaToolHandler defaultHandler;

  /// Whether the observe-on-every-action envelope (the fresh `state` +
  /// `settled`) should ride this tool's result. TRUE for actions that CHANGE
  /// the screen (navigate, the set* tools, advanceOnboarding) — Baba must see
  /// where he landed. FALSE for pure DATA READS (getTransits, getMyChart,
  /// getMyForecast, getToday, getMyWellness): they don't touch the screen, and
  /// stapling the current screen's `onScreen` onto a data payload actively
  /// backfires — the "narrate only what's on screen" law then makes Baba
  /// distrust real data he just fetched (he'd fetch the live gochar, then
  /// stall because the Home dashboard doesn't literally list those signs).
  final bool appendsWorldState;

  /// Whether this tool changes app or user state. Mutation results are always
  /// normalized to the canonical applied/blocked/rejected/failed envelope.
  final bool isMutation;

  /// Require a caller-generated key for consequential retryable operations.
  final bool requiresRequestId;

  /// The functionDeclaration handed to Gemini at session start.
  Map<String, dynamic> get declaration {
    if (!requiresRequestId) {
      return {
        'name': name,
        'description': description,
        'parameters': parameters,
      };
    }
    final properties =
        Map<String, dynamic>.from(parameters['properties'] as Map? ?? const {});
    properties['requestId'] = {
      'type': 'string',
      'description': 'Unique id for this user-requested operation. Reuse the '
          'same id when retrying the same operation.',
    };
    final required = <dynamic>[
      ...(parameters['required'] as List? ?? const []),
      if (!(parameters['required'] as List? ?? const []).contains('requestId'))
        'requestId',
    ];
    return {
      'name': name,
      'description': description,
      'parameters': {
        ...parameters,
        'properties': properties,
        'required': required,
      },
    };
  }
}

/// App-scoped, **whitelisted** catalog of what Baba may do.
///
/// ## Why a stable global catalog (not per-screen declarations)
/// Baba is a companion that WRAPS the whole app, so his tools must be available
/// across every screen and every call. But the Gemini Live session fixes its
/// tool list at connect time — you can't add/remove declarations mid-call
/// without reconnecting (which drops the audio). So:
///
///   * **Declarations are global + stable** — registered once at app start via
///     [register]. Every voice session is told the full set, so Baba can call
///     any tool from anywhere. Tools are "there across."
///   * **Behavior is per-screen** — a screen that owns a tool's action binds a
///     live handler with [bindHandler] on entry and [unbindHandler] on exit.
///     The DECLARATION never changes (Gemini's view is stable, no reconnect);
///     only the handler swaps. When no screen has bound it, the tool's
///     [BabaTool.defaultHandler] runs — which can simply report it isn't
///     available on the current screen.
class BabaToolRegistry extends ChangeNotifier {
  BabaToolRegistry._();
  static final BabaToolRegistry instance = BabaToolRegistry._();

  final Map<String, BabaTool> _tools = {};
  final Map<String, BabaToolHandler> _boundHandlers = {};
  final LinkedHashMap<String, Future<Map<String, dynamic>>>
      _idempotentRequests = LinkedHashMap();
  static const int _maxIdempotentRequests = 100;

  // How many tool dispatches are currently in flight (incl. their settle window).
  // Lets other code tell whether a state change was Baba-driven: an action that
  // navigates (e.g. sign-in) will find this > 0, so it can skip a redundant
  // proactive announce — the tool result already carries the settled state.
  int _dispatchDepth = 0;

  /// True while a tool call is being dispatched (through to its settled result).
  bool get isDispatching => _dispatchDepth > 0;

  /// Upper bound on how long a single tool handler may run before dispatch
  /// gives up and returns ok:false. A wedged handler (a hung network call, a
  /// future that never completes) would otherwise leave the voice relay
  /// waiting for a tool_response — dead air until the relay's own watchdog
  /// fires. Kept just under the relay's CX_TOOL_TIMEOUT_MS (12s) so the client
  /// returns a specific reason FIRST; every real handler here finishes in well
  /// under a second (a geocode/profile save is a few seconds at most).
  static const Duration _handlerTimeout = Duration(seconds: 10);

  /// Register a global tool declaration (idempotent by name). Call once at app
  /// start so the tool is available across every screen/session.
  void register(BabaTool tool) {
    _tools[tool.name] = tool;
    notifyListeners();
  }

  void registerAll(Iterable<BabaTool> tools) {
    for (final t in tools) {
      _tools[t.name] = t;
    }
    notifyListeners();
  }

  /// A screen attaches live behavior to an already-declared tool. Does NOT
  /// change the declaration, so no session reconnect is needed.
  void bindHandler(String toolName, BabaToolHandler handler) {
    _boundHandlers[toolName] = handler;
  }

  /// A screen detaches its behavior (on dispose) — the tool falls back to its
  /// [BabaTool.defaultHandler].
  void unbindHandler(String toolName) {
    _boundHandlers.remove(toolName);
  }

  /// Function declarations to hand Gemini at session start (the stable catalog).
  List<Map<String, dynamic>> get declarations =>
      _tools.values.map((t) => t.declaration).toList(growable: false);

  bool get isEmpty => _tools.isEmpty;

  /// Dispatch a tool call from Baba. Prefers a screen-bound handler, else the
  /// tool's default. Always returns a result map (an error map for
  /// unknown/failed tools) so the model is never left hanging on a call.
  Future<Map<String, dynamic>> dispatch(
      String name, Map<String, dynamic> args) async {
    final tool = _tools[name];
    if (tool == null) {
      return {'ok': false, 'error': 'unknown_tool', 'tool': name};
    }
    final handler = _boundHandlers[name] ?? tool.defaultHandler;
    final requestId = args['requestId']?.toString().trim();
    if (tool.requiresRequestId && (requestId == null || requestId.isEmpty)) {
      final rejected = _normalizeMutationResult({
        'ok': false,
        'reason': 'requestId is required for this mutation',
      }, forcedStatus: 'rejected');
      return tool.appendsWorldState
          ? await _withWorldState(rejected)
          : rejected;
    }

    _dispatchDepth++;
    try {
      Future<Map<String, dynamic>> pending;
      if (tool.requiresRequestId) {
        final key = '$name:$requestId';
        pending =
            _idempotentRequests[key] ??= handler(args).timeout(_handlerTimeout);
        while (_idempotentRequests.length > _maxIdempotentRequests) {
          _idempotentRequests.remove(_idempotentRequests.keys.first);
        }
      } else {
        pending = handler(args).timeout(_handlerTimeout);
      }
      final result = await pending;
      // `ok` is the ONE field the model reflexively trusts to decide whether an
      // action worked (and whether to tell the user it's done). So it must be
      // truthful: a handler that couldn't perform the action MUST return
      // ok:false (e.g. the owning screen isn't open, or args were invalid).
      // We default to true only when the handler stays silent on `ok`; an
      // explicit handler value always wins. Do NOT reduce this to
      // `{'ok': true, ...result}` — that once masked failures as success and
      // made Baba claim the chart was ready when nothing had been saved.
      final ok = result['ok'] as bool? ?? true;
      final legacy = {...result, 'ok': ok};
      final out = tool.isMutation ? _normalizeMutationResult(legacy) : legacy;
      // Data reads don't change the screen — narrate the payload straight, no
      // world-state envelope (see [BabaTool.appendsWorldState]).
      return tool.appendsWorldState ? await _withWorldState(out) : out;
    } on TimeoutException {
      final result = {
        'ok': false,
        'status': 'failed',
        'error': 'timeout',
        'tool': name,
        'reason': 'the app took too long to respond',
      };
      return await _withWorldState(result);
    } catch (e) {
      return await _withWorldState({
        'ok': false,
        'status': 'failed',
        'error': e.toString(),
        'tool': name,
      });
    } finally {
      _dispatchDepth--;
    }
  }

  Map<String, dynamic> _normalizeMutationResult(
    Map<String, dynamic> result, {
    String? forcedStatus,
  }) {
    final existing = result['status']?.toString();
    final status = forcedStatus ??
        existing ??
        (result['ok'] == true
            ? 'applied'
            : result['blocked'] == true
                ? 'blocked'
                : 'failed');
    return {
      ...result,
      'status': status,
      'ok': status == 'applied',
      'blocked': status == 'blocked',
    };
  }

  /// The observe-on-every-action envelope: after a handler runs, wait for the UI
  /// it triggered to SETTLE (see [BabaContext.settle] — it waits out even a
  /// deferred navigation instead of guessing a frame count), then re-ground Baba
  /// by appending the FRESH world state + a `settled` flag to the result. This
  /// is what makes every action self-correcting: Baba always sees the TRUE
  /// resulting state, never his assumption of it, and can never outrun his own
  /// effects. `settled` is false while the resulting screen is still loading —
  /// a signal to guided flows (and the playbook) to wait, not to charge ahead.
  ///
  /// A handler that already computed the post-action state (rare) can set
  /// `state`/`settled` itself; we never overwrite an explicit value.
  Future<Map<String, dynamic>> _withWorldState(
      Map<String, dynamic> result) async {
    await BabaContext.instance.settle();
    final state = BabaContext.instance.worldState();
    final onScreen = state['onScreen'];
    final loading = onScreen is Map && onScreen['status'] == 'loading';
    // Order matters for how the model READS this: lead with the RESULT
    // (`ok`, `reason`, `missing`, ...) and trail with the bulky `state` blob.
    // When an action FAILS (e.g. submitBirthDetails ok:false, missing:[place]),
    // burying ok:false after ~500 chars of "everything's ready on screen" is
    // exactly how the model glosses over it and falsely narrates success. The
    // failure signal must come first.
    return {
      ...result,
      if (!result.containsKey('state')) 'state': state,
      if (!result.containsKey('settled')) 'settled': !loading,
    };
  }
}
