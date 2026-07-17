import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/features/baba/domain/baba_context.dart';
import 'package:aurogram/features/baba/domain/baba_snapshot.dart';

/// Locks the "wrap the app" snapshot spine: screens register live [BabaSnapshot]
/// providers, `whereAmI` (snapshot) folds in that real-time data under
/// `onScreen` (as JSON), unregistering removes it, and a throwing provider can
/// never break whereAmI.
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

  test('a registered provider surfaces live data under onScreen (as JSON)', () {
    ctx.registerSnapshot(
      'home',
      () => BabaSnapshot.ready(
        headline: 'The home dashboard',
        facts: {'skyDate': '2026-07-14', 'live': true},
      ),
    );
    final snap = ctx.snapshot();
    final onScreen = snap['onScreen'] as Map<String, dynamic>;
    expect(onScreen['status'], 'ready');
    expect(onScreen['headline'], 'The home dashboard');
    expect(onScreen['facts'], {'skyDate': '2026-07-14', 'live': true});
    ctx.unregisterSnapshot('home');
  });

  test('providers are pulled fresh on every snapshot (real-time)', () {
    var counter = 0;
    ctx.registerSnapshot('home', () => BabaSnapshot.ready(facts: {'n': ++counter}));
    expect(((ctx.snapshot()['onScreen'] as Map)['facts'] as Map)['n'], 1);
    expect(((ctx.snapshot()['onScreen'] as Map)['facts'] as Map)['n'], 2);
    ctx.unregisterSnapshot('home');
  });

  test('status is carried through even with no facts (e.g. loading)', () {
    ctx.registerSnapshot(
        'home', () => const BabaSnapshot.loading(headline: 'Preparing'));
    final onScreen = ctx.snapshot()['onScreen'] as Map<String, dynamic>;
    expect(onScreen['status'], 'loading');
    expect(onScreen['headline'], 'Preparing');
    ctx.unregisterSnapshot('home');
  });

  test('unregistering removes the live data again', () {
    ctx.registerSnapshot('home', () => BabaSnapshot.ready(facts: {'x': 1}));
    expect(ctx.snapshot().containsKey('onScreen'), true);
    ctx.unregisterSnapshot('home');
    expect(ctx.snapshot().containsKey('onScreen'), false);
  });

  test('a fully empty snapshot is treated as no data', () {
    ctx.registerSnapshot('home', () => const BabaSnapshot.empty());
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
