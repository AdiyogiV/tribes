import 'package:flutter/foundation.dart';

/// A single action Baba is allowed to perform on the app.
///
/// [parameters] is a JSON-Schema object (the Gemini functionDeclaration
/// `parameters` shape). [handler] runs the action and returns a small result
/// map that is sent back to Baba so he knows it worked (or why it didn't).
class BabaTool {
  const BabaTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.handler,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> args) handler;

  /// The functionDeclaration handed to Gemini at session start.
  Map<String, dynamic> get declaration => {
        'name': name,
        'description': description,
        'parameters': parameters,
      };
}

/// App-scoped, **whitelisted** registry of what Baba may do right now.
///
/// This is the guardrail that turns "voice chat" into a safe agent: Baba can
/// ONLY ever call actions that a live surface has registered. Screens register
/// their tools on entry and remove them on exit (see [register]/[unregister]),
/// so onboarding tools aren't callable from the feed, etc.
///
/// NOTE (Rung 2a): the Live session declares its tool set once at connect time,
/// so the tools available for a given call are whatever's registered when
/// [VoiceSessionController.start] runs. Dynamic mid-session tool updates are a
/// later refinement; for onboarding the session starts on the onboarding
/// screen with its tools already registered.
class BabaToolRegistry extends ChangeNotifier {
  BabaToolRegistry._();
  static final BabaToolRegistry instance = BabaToolRegistry._();

  final Map<String, BabaTool> _tools = {};

  /// Function declarations to hand Gemini at session start (empty => no tools).
  List<Map<String, dynamic>> get declarations =>
      _tools.values.map((t) => t.declaration).toList(growable: false);

  bool get isEmpty => _tools.isEmpty;

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

  void unregister(String name) {
    if (_tools.remove(name) != null) notifyListeners();
  }

  void unregisterAll(Iterable<String> names) {
    var changed = false;
    for (final n in names) {
      if (_tools.remove(n) != null) changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Dispatch a tool call from Baba. Always returns a result map (an error map
  /// for unknown/failed tools) so the model is never left hanging on a call.
  Future<Map<String, dynamic>> dispatch(
      String name, Map<String, dynamic> args) async {
    final tool = _tools[name];
    if (tool == null) {
      return {'ok': false, 'error': 'unknown_tool', 'tool': name};
    }
    try {
      final result = await tool.handler(args);
      return {'ok': true, ...result};
    } catch (e) {
      return {'ok': false, 'error': e.toString(), 'tool': name};
    }
  }
}
