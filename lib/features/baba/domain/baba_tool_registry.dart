import 'package:flutter/foundation.dart';

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
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final BabaToolHandler defaultHandler;

  /// The functionDeclaration handed to Gemini at session start.
  Map<String, dynamic> get declaration => {
        'name': name,
        'description': description,
        'parameters': parameters,
      };
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
    try {
      final result = await handler(args);
      // `ok` is the ONE field the model reflexively trusts to decide whether an
      // action worked (and whether to tell the user it's done). So it must be
      // truthful: a handler that couldn't perform the action MUST return
      // ok:false (e.g. the owning screen isn't open, or args were invalid).
      // We default to true only when the handler stays silent on `ok`; an
      // explicit handler value always wins. Do NOT reduce this to
      // `{'ok': true, ...result}` — that once masked failures as success and
      // made Baba claim the chart was ready when nothing had been saved.
      final ok = result['ok'] as bool? ?? true;
      return {...result, 'ok': ok};
    } catch (e) {
      return {'ok': false, 'error': e.toString(), 'tool': name};
    }
  }
}
