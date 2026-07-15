import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/features/baba/domain/baba_context.dart';

/// Locks the "wrap the app" snapshot spine: screens register live providers,
/// `whereAmI` (snapshot) folds in that real-time data under `onScreen`,
/// unregistering removes it, and a throwing provider can never break whereAmI.
///
/// Default location is '/', which BabaAppMap maps to the 'home' screen, so we
/// register under 'home' — no router/app needed for this logic.
void main() {
  final ctx = BabaContext.instance;

  test('base snapshot always exposes route + screen identity', () {
    final snap = ctx.snapshot();
    expect(snap['route'], '/');
    expect(snap['screen'], 'home');
    expect(snap.containsKey('onScreen'), false); // nothing registered yet
  });

  test('a registered provider surfaces live data under onScreen', () {
    ctx.registerSnapshot('home', () => {'skyDate': '2026-07-14', 'live': true});
    final snap = ctx.snapshot();
    expect(snap['onScreen'], {'skyDate': '2026-07-14', 'live': true});
    ctx.unregisterSnapshot('home');
  });

  test('providers are pulled fresh on every snapshot (real-time)', () {
    var counter = 0;
    ctx.registerSnapshot('home', () => {'n': ++counter});
    expect((ctx.snapshot()['onScreen'] as Map)['n'], 1);
    expect((ctx.snapshot()['onScreen'] as Map)['n'], 2);
    ctx.unregisterSnapshot('home');
  });

  test('unregistering removes the live data again', () {
    ctx.registerSnapshot('home', () => {'x': 1});
    expect(ctx.snapshot().containsKey('onScreen'), true);
    ctx.unregisterSnapshot('home');
    expect(ctx.snapshot().containsKey('onScreen'), false);
  });

  test('an empty snapshot is treated as no data', () {
    ctx.registerSnapshot('home', () => {});
    expect(ctx.snapshot().containsKey('onScreen'), false);
    ctx.unregisterSnapshot('home');
  });

  test('a throwing provider never breaks whereAmI', () {
    ctx.registerSnapshot('home', () => throw StateError('boom'));
    final snap = ctx.snapshot(); // must not throw
    expect(snap['screen'], 'home');
    expect(snap.containsKey('onScreen'), false);
    ctx.unregisterSnapshot('home');
  });
}
