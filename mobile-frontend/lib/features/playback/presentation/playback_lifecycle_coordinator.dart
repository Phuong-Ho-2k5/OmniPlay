import 'dart:async';

typedef StopAndFlushCallback = Future<void> Function();

/// Coordinates active playback instances so logout or session teardown
/// can stop playback and best-effort flush progress before clearing tokens.
class PlaybackLifecycleCoordinator {
  final Set<StopAndFlushCallback> _callbacks = {};

  void Function() register(StopAndFlushCallback callback) {
    _callbacks.add(callback);
    return () => _callbacks.remove(callback);
  }

  Future<void> stopAndFlushAll({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_callbacks.isEmpty) return;
    final snapshot = List<StopAndFlushCallback>.of(_callbacks);
    await Future.wait([
      for (final cb in snapshot)
        (() async {
          try {
            await cb().timeout(timeout);
          } catch (_) {
            // Logout must proceed even if network or player flush fails.
          }
        })(),
    ]);
  }
}
