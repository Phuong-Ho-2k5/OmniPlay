import 'dart:convert';

import '../../features/auth/data/auth_session_controller.dart';
import '../../features/auth/data/refresh_coordinator.dart';
import '../../features/auth/data/session_store.dart';
import 'api_exception.dart';
import 'api_transport.dart';

class ApiClient {
  ApiClient({
    required this._transport,
    required this._sessions,
    required this._refresh,
  });
  final ApiTransport _transport;
  final AuthSessionController _sessions;
  final RefreshCoordinator _refresh;
  static const _authPaths = {
    '/auth/register',
    '/auth/login',
    '/auth/refresh',
    '/auth/logout',
  };

  Future<Map<String, dynamic>> getJson(
    String path, {
    int? expectedStatusCode,
    bool authenticated = true,
  }) => _request(
    'GET',
    path,
    expectedStatusCode: expectedStatusCode,
    authenticated: authenticated,
  );

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    required int expectedStatusCode,
    bool authenticated = true,
  }) => _request(
    'POST',
    path,
    encodedBody: jsonEncode(body),
    expectedStatusCode: expectedStatusCode,
    authenticated: authenticated,
  );

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    String? encodedBody,
    int? expectedStatusCode,
    required bool authenticated,
  }) async {
    final publicPath = Uri.parse(path).path;
    if (!authenticated ||
        _authPaths.contains(publicPath) ||
        (method == 'GET' && publicPath == '/actuator/health')) {
      return _transport.sendJson(
        method,
        path,
        encodedBody: encodedBody,
        expectedStatusCode: expectedStatusCode,
      );
    }
    final pair = _sessions.tokens;
    if (pair == null) throw const SessionChangedException();
    final generation = _sessions.generation, revision = _sessions.revision;
    try {
      final result = await _transport.sendJson(
        method,
        path,
        encodedBody: encodedBody,
        expectedStatusCode: expectedStatusCode,
        accessToken: pair.accessToken,
      );
      if (!_sessions.isCurrent(generation)) {
        throw const SessionChangedException();
      }
      return result;
    } on ApiException catch (error) {
      if (!_sessions.isCurrent(generation)) {
        throw const SessionChangedException();
      }
      if (error.statusCode != 401 || error.code != 'ACCESS_TOKEN_EXPIRED') {
        if (error.statusCode == 401 &&
            _sessions.isCurrent(generation, revision)) {
          await _sessions.clear(notice: 'Vui lòng đăng nhập lại để tiếp tục.');
        }
        rethrow;
      }
    }
    await _refresh.refreshFor(generation: generation, revision: revision);
    if (!_sessions.isCurrent(generation) || _sessions.tokens == null) {
      throw const SessionChangedException();
    }
    final retriedRevision = _sessions.revision;
    try {
      final result = await _transport.sendJson(
        method,
        path,
        encodedBody: encodedBody,
        expectedStatusCode: expectedStatusCode,
        accessToken: _sessions.tokens!.accessToken,
      );
      if (!_sessions.isCurrent(generation)) {
        throw const SessionChangedException();
      }
      return result;
    } on ApiException catch (error) {
      if (!_sessions.isCurrent(generation)) {
        throw const SessionChangedException();
      }
      if (error.statusCode == 401 &&
          _sessions.isCurrent(generation, retriedRevision)) {
        await _sessions.clear(
          notice: 'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.',
        );
      }
      rethrow;
    }
  }
}
