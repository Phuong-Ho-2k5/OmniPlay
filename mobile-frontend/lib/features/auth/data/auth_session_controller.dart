import 'package:flutter/foundation.dart';

import '../models/auth_json.dart';
import '../models/token_pair.dart';
import 'secure_token_store.dart';
import 'session_store.dart';

enum AuthSessionPhase { restoring, signedOut, signedIn, storageError }

enum LogoutOutcome { confirmed, connectionUnconfirmed, localStorageFailure }

class AuthSessionController extends ChangeNotifier implements SessionStore {
  AuthSessionController({
    required this._store,
    DateTime Function()? now,
    this._revokeSession,
    this._beforeLogout,
  }) : _now = now ?? (() => DateTime.now().toUtc());
  final SecureTokenStore _store;
  final DateTime Function() _now;
  final Future<void> Function(String token)? _revokeSession;
  final Future<void> Function()? _beforeLogout;
  Future<LogoutOutcome>? _logoutInFlight;
  Future<void>? _storageRetryInFlight;
  int? _logoutGeneration;
  bool _logoutUnconfirmed = false;
  Future<void> _storageQueue = Future<void>.value();
  TokenPair? _tokens;
  int _generation = 0, _revision = 0;
  bool _disposed = false, _deletePending = false;
  AuthSessionPhase _phase = AuthSessionPhase.restoring;
  String? _notice;
  @override
  TokenPair? get tokens => _tokens;
  @override
  int get generation => _generation;
  @override
  int get revision => _revision;
  AuthSessionPhase get phase => _phase;
  String? get notice => _notice;
  bool isCurrent(int generation, [int? revision]) =>
      !_disposed &&
      _generation == generation &&
      (revision == null || _revision == revision);

  Future<T> _serialized<T>(Future<T> Function() action) {
    final operation = _storageQueue.then((_) => action());
    _storageQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace stack) {},
    );
    return operation;
  }

  Future<void> restore() {
    final generation = ++_generation;
    _revision++;
    _tokens = null;
    _phase = AuthSessionPhase.restoring;
    _notice = null;
    _notify();
    return _serialized(() async {
      if (!isCurrent(generation)) return;
      try {
        TokenPair? restored;
        if (_deletePending) {
          await _store.delete();
          _deletePending = false;
        } else {
          try {
            restored = await _store.read();
          } on CorruptTokenStorageException {
            if (!isCurrent(generation)) return;
            _deletePending = true;
            await _store.delete();
            _deletePending = false;
            _notice = 'Phiên đã lưu không hợp lệ. Vui lòng đăng nhập lại.';
          }
        }
        if (!isCurrent(generation)) return;
        if (restored != null && !_now().isBefore(restored.refreshExpiresAt)) {
          _deletePending = true;
          await _store.delete();
          _deletePending = false;
          restored = null;
          if (isCurrent(generation)) {
            _notice = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
          }
        }
        if (!isCurrent(generation)) return;
        _tokens = restored;
        _phase = restored == null
            ? AuthSessionPhase.signedOut
            : AuthSessionPhase.signedIn;
        _notify();
      } catch (_) {
        if (!isCurrent(generation)) return;
        _phase = AuthSessionPhase.storageError;
        _notice = _deletePending
            ? 'Không thể xóa phiên trên thiết bị. Vui lòng thử lại.'
            : 'Không thể mở phiên đã lưu. Vui lòng thử lại.';
        _notify();
      }
    });
  }

  @override
  Future<void> install(TokenPair pair) {
    if (!_now().isBefore(pair.refreshExpiresAt)) invalidAuthResponse();
    final generation = ++_generation;
    _revision++;
    _tokens = null;
    _phase = AuthSessionPhase.restoring;
    _notice = null;
    _logoutUnconfirmed = false;
    _notify();
    return _serialized(() async {
      if (!isCurrent(generation)) return;
      try {
        await _store.write(pair);
      } catch (_) {
        if (!isCurrent(generation)) return;
        await _storageFailure(generation);
        throw const SessionStorageException();
      }
      if (!isCurrent(generation)) return;
      _tokens = pair;
      _revision++;
      _deletePending = false;
      _phase = AuthSessionPhase.signedIn;
      _notify();
    });
  }

  Future<bool> replaceIfCurrent(
    TokenPair pair, {
    required int generation,
    required int revision,
  }) {
    if (!isCurrent(generation, revision) || _tokens == null) {
      return Future.value(false);
    }
    if (!_now().isBefore(pair.refreshExpiresAt)) invalidAuthResponse();
    return _serialized(() async {
      if (!isCurrent(generation, revision) || _tokens == null) return false;
      try {
        await _store.write(pair);
      } catch (_) {
        if (!isCurrent(generation, revision)) return false;
        await _storageFailure(generation);
        throw const SessionStorageException();
      }
      if (!isCurrent(generation, revision)) return false;
      _tokens = pair;
      _revision++;
      _phase = AuthSessionPhase.signedIn;
      _notify();
      return true;
    });
  }

  @override
  Future<void> clear({String? notice}) {
    final generation = ++_generation;
    _revision++;
    _tokens = null;
    _phase = AuthSessionPhase.signedOut;
    _notice = notice;
    _deletePending = true;
    _notify();
    return _serialized(() async {
      try {
        // This delete is ordered before every later install, even if its generation changed.
        await _store.delete();
        _deletePending = false;
      } catch (_) {
        if (isCurrent(generation)) {
          _phase = AuthSessionPhase.storageError;
          _notice = 'Không thể xóa phiên trên thiết bị. Vui lòng thử lại.';
          _notify();
        }
        throw const SessionStorageException();
      }
    });
  }

  Future<void> retryStorage() {
    if (!_deletePending) return restore();
    if (_storageRetryInFlight != null) return _storageRetryInFlight!;
    // A storage-only retry retains the signed-out identity so its pending logout can still finish.
    final generation = _generation;
    _phase = AuthSessionPhase.restoring;
    _notice = 'Đang xóa phiên trên thiết bị…';
    _notify();
    late final Future<void> retry;
    retry =
        _serialized(() async {
          try {
            await _store.delete();
            if (!isCurrent(generation)) return;
            _deletePending = false;
            _phase = AuthSessionPhase.signedOut;
            _notice = _logoutGeneration != generation
                ? 'Vui lòng đăng nhập lại.'
                : _logoutInFlight != null
                ? 'Đã xóa phiên trên thiết bị. Đang chờ xác nhận đăng xuất…'
                : _logoutUnconfirmed
                ? 'Đã xóa phiên trên thiết bị. Chưa xác nhận đăng xuất trên máy chủ.'
                : 'Đã đăng xuất.';
            _notify();
          } catch (_) {
            if (isCurrent(generation)) {
              _phase = AuthSessionPhase.storageError;
              _notice = 'Không thể xóa phiên trên thiết bị. Vui lòng thử lại.';
              _notify();
            }
            throw const SessionStorageException();
          }
        }).whenComplete(() {
          if (identical(_storageRetryInFlight, retry)) {
            _storageRetryInFlight = null;
          }
        });
    _storageRetryInFlight = retry;
    return retry;
  }

  Future<LogoutOutcome> logout() {
    if (_logoutInFlight != null && _logoutGeneration == _generation) {
      return _logoutInFlight!;
    }
    final preLogout = _beforeLogout;
    if (preLogout == null) {
      return _beginLogout();
    }
    final generation = _generation;
    late final Future<LogoutOutcome> flight;
    flight =
        (() async {
          try {
            await preLogout();
          } catch (_) {
            // Best-effort progress flush never blocks logout.
          }
          if (!isCurrent(generation)) {
            return LogoutOutcome.confirmed;
          }
          return _executeLogout();
        })().whenComplete(() {
          if (identical(_logoutInFlight, flight)) _logoutInFlight = null;
        });
    _logoutGeneration = generation;
    _logoutInFlight = flight;
    return flight;
  }

  Future<LogoutOutcome> _beginLogout() {
    final token = _tokens?.refreshToken;
    final local = clear(
      notice: 'Đang đăng xuất…',
    ).then<bool>((_) => true, onError: (Object _, StackTrace stack) => false);
    final generation = _generation;
    late final Future<LogoutOutcome> flight;
    flight = _finishLogout(local, _revoke(token), generation).whenComplete(() {
      if (identical(_logoutInFlight, flight)) _logoutInFlight = null;
    });
    _logoutGeneration = generation;
    _logoutInFlight = flight;
    return flight;
  }

  Future<LogoutOutcome> _executeLogout() {
    final token = _tokens?.refreshToken;
    final local = clear(
      notice: 'Đang đăng xuất…',
    ).then<bool>((_) => true, onError: (Object _, StackTrace stack) => false);
    final generation = _generation;
    _logoutGeneration = generation;
    return _finishLogout(local, _revoke(token), generation);
  }

  Future<bool> _revoke(String? token) async {
    if (token == null) return !_logoutUnconfirmed;
    try {
      final revoke = _revokeSession;
      if (revoke == null) return false;
      await revoke(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<LogoutOutcome> _finishLogout(
    Future<bool> local,
    Future<bool> remote,
    int generation,
  ) async {
    final results = await Future.wait([local, remote]);
    final localCleared =
        results[0] || (isCurrent(generation) && !_deletePending);
    final serverConfirmed = results[1];
    if (isCurrent(generation)) {
      _logoutUnconfirmed = !serverConfirmed;
      if (!localCleared) {
        if (_storageRetryInFlight != null) {
          _phase = AuthSessionPhase.restoring;
          _notice = 'Đang xóa phiên trên thiết bị…';
        } else {
          _phase = AuthSessionPhase.storageError;
          _notice =
              'Không thể xóa phiên trên thiết bị. Vui lòng thử lại.'
              '${serverConfirmed ? '' : ' Chưa xác nhận đăng xuất trên máy chủ.'}';
        }
      } else {
        _notice = serverConfirmed ? 'Đã đăng xuất.' : 'Đã xóa phiên trên thiết bị. Chưa xác nhận đăng xuất trên máy chủ. Vui lòng kiểm tra kết nối.';
      }
      _notify();
    }
    return !localCleared
        ? LogoutOutcome.localStorageFailure
        : serverConfirmed
        ? LogoutOutcome.confirmed
        : LogoutOutcome.connectionUnconfirmed;
  }

  Future<void> _storageFailure(int generation) async {
    if (!isCurrent(generation)) return;
    final failedGeneration = ++_generation;
    _revision++;
    _tokens = null;
    _phase = AuthSessionPhase.storageError;
    _notice = 'Không thể lưu phiên trên thiết bị. Vui lòng đăng nhập lại.';
    _deletePending = true;
    _notify();
    try {
      await _store.delete();
      if (isCurrent(failedGeneration)) _deletePending = false;
    } catch (_) {
      /* Retry keeps authenticated access blocked. */
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _tokens = null;
    super.dispose();
  }
}
