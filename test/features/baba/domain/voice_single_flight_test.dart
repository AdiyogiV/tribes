import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/features/baba/voice/voice_single_flight.dart';

void main() {
  group('VoiceSingleFlight', () {
    test('coalesces concurrent requests into one operation', () async {
      final gate = VoiceSingleFlight();
      final release = Completer<void>();
      var calls = 0;

      final first = gate.run(() async {
        calls++;
        await release.future;
      });
      final second = gate.run(() async {
        calls++;
      });

      expect(calls, 1);
      expect(gate.current, isNotNull);

      release.complete();
      await Future.wait([first, second]);

      expect(calls, 1);
      expect(gate.current, isNull);
    });

    test('allows a new operation after completion', () async {
      final gate = VoiceSingleFlight();
      var calls = 0;

      await gate.run(() async => calls++);
      await gate.run(() async => calls++);

      expect(calls, 2);
    });

    test('clears an asynchronously failed operation so callers can retry',
        () async {
      final gate = VoiceSingleFlight();
      var calls = 0;

      await expectLater(
        gate.run(() async {
          calls++;
          throw StateError('boom');
        }),
        throwsStateError,
      );
      await gate.run(() async => calls++);

      expect(calls, 2);
    });

    test('converts a synchronous throw and still allows retry', () async {
      final gate = VoiceSingleFlight();
      var calls = 0;

      await expectLater(
        gate.run(() {
          calls++;
          throw StateError('boom');
        }),
        throwsStateError,
      );
      await gate.run(() async => calls++);

      expect(calls, 2);
    });
  });
}
