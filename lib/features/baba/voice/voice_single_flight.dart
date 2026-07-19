import 'dart:async';

/// Coalesces concurrent requests for the same asynchronous voice operation.
///
/// Voice warm-up and auto-start can be requested by independent lifecycle/UI
/// paths. Sharing the in-flight future keeps those callers from opening or
/// subscribing to duplicate sockets.
///
/// Operations must not recursively await [run] on this same instance: like a
/// mutex, the active operation owns the flight until it completes.
class VoiceSingleFlight {
  Future<void>? _current;

  Future<void>? get current => _current;

  Future<void> run(Future<void> Function() operation) {
    final existing = _current;
    if (existing != null) return existing;

    final completer = Completer<void>();
    _current = completer.future;
    Future.sync(operation)
        .then(completer.complete, onError: completer.completeError);
    return completer.future.whenComplete(() {
      if (identical(_current, completer.future)) _current = null;
    });
  }
}
