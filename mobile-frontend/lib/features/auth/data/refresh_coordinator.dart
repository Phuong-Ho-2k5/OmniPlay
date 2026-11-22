import '../../../core/network/api_exception.dart';
import 'auth_repository.dart';
import 'auth_session_controller.dart';
import 'session_store.dart';

class RefreshCoordinator {
  RefreshCoordinator({required this._repository, required this._sessions});
  final AuthRepository _repository;
  final AuthSessionController _sessions;
  Future<void>? _inFlight;
  int? _flightGeneration;

  Future<void> refreshFor({required int generation, required int revision}) {
    if (!_sessions.isCurrent(generation) || _sessions.tokens == null) {
      return Future.error(const SessionChangedException());
    }
    if (_sessions.revision != revision) return Future.value();
    if (_inFlight != null && _flightGeneration == generation) return _inFlight!;
    late final Future<void> flight;
    flight = _perform(generation, revision, _sessions.tokens!.refreshToken)
        .whenComplete(() {
          if (identical(_inFlight, flight)) _inFlight = null;
        });
    _flightGeneration = generation;
    _inFlight = flight;
    return flight;
  }

  Future<void> _perform(int generation, int revision, String token) async {
    try {
      final pair = await _repository.refresh(refreshToken: token);
      if (!await _sessions.replaceIfCurrent(
        pair,
        generation: generation,
        revision: revision,
      )) {
        throw const SessionChangedException();
      }
    } on ApiException catch (error) {
      if (!_sessions.isCurrent(generation, revision)) {
        throw const SessionChangedException();
      }
      if (error.statusCode == 401 &&
          {
            'REFRESH_TOKEN_INVALID',
            'REFRESH_TOKEN_EXPIRED',
          }.contains(error.code)) {
        await _sessions.clear(
          notice: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }
      rethrow;
    }
  }
}
