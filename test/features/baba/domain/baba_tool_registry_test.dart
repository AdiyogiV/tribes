import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';

/// Proves the tool-call machinery Baba relies on: registration, dispatch,
/// per-screen handler binding/fallback, the whitelist, and error handling.
/// (The live voice loop + real navigation need a device; this locks the logic.)
void main() {
  final registry = BabaToolRegistry.instance;

  BabaTool echoTool(String name, {String tag = 'default'}) => BabaTool(
        name: name,
        description: 'test',
        parameters: const {'type': 'object', 'properties': {}},
        defaultHandler: (args) async => {'ran': tag, 'echo': args['x']},
      );

  test('unknown tool is rejected (whitelist)', () async {
    final res = await registry.dispatch('nope_not_registered', {});
    expect(res['ok'], false);
    expect(res['error'], 'unknown_tool');
  });

  test('registered tool runs its default handler and merges result', () async {
    registry.register(echoTool('t_default'));
    final res = await registry.dispatch('t_default', {'x': 42});
    expect(res['ok'], true);
    expect(res['ran'], 'default');
    expect(res['echo'], 42);
  });

  test('a screen can bind a live handler; unbinding falls back to default',
      () async {
    registry.register(echoTool('t_bind'));

    // Screen binds its own behavior (declaration unchanged, no reconnect).
    registry.bindHandler('t_bind', (args) async => {'ran': 'bound'});
    var res = await registry.dispatch('t_bind', {});
    expect(res['ran'], 'bound');

    // Screen leaves -> falls back to the tool's default handler.
    registry.unbindHandler('t_bind');
    res = await registry.dispatch('t_bind', {'x': 'y'});
    expect(res['ran'], 'default');
    expect(res['echo'], 'y');
  });

  test('a handler that reports non-performance surfaces ok:false (not masked)',
      () async {
    // Regression: the dispatcher used to force `ok:true` onto every result, so
    // a "screen not open" / bad-args handler still looked like success and Baba
    // told the user the action worked when nothing had been saved.
    registry.register(BabaTool(
      name: 't_unavailable',
      description: 'test',
      parameters: const {'type': 'object', 'properties': {}},
      defaultHandler: (_) async =>
          {'ok': false, 'available': false, 'message': 'screen not open'},
    ));
    final res = await registry.dispatch('t_unavailable', {});
    expect(res['ok'], false);
    expect(res['available'], false);
    expect(res['message'], 'screen not open');
  });

  test('a silent handler still defaults to ok:true', () async {
    registry.register(echoTool('t_silent'));
    final res = await registry.dispatch('t_silent', {'x': 1});
    expect(res['ok'], true);
    expect(res['echo'], 1);
  });

  test('a throwing handler is caught and reported, never left hanging',
      () async {
    registry.register(BabaTool(
      name: 't_throw',
      description: 'test',
      parameters: const {'type': 'object', 'properties': {}},
      defaultHandler: (_) async => throw StateError('boom'),
    ));
    final res = await registry.dispatch('t_throw', {});
    expect(res['ok'], false);
    expect(res['error'], contains('boom'));
  });

  test('declarations expose the whitelisted catalog for the session', () {
    registry.register(echoTool('t_decl'));
    final names = registry.declarations.map((d) => d['name']).toList();
    expect(names, contains('t_decl'));
  });
}
