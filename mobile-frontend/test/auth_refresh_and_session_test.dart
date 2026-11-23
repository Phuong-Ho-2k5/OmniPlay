import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omniplay_mobile/core/network/api_client.dart';
import 'package:omniplay_mobile/core/network/api_exception.dart';
import 'package:omniplay_mobile/core/network/api_transport.dart';
import 'package:omniplay_mobile/features/auth/data/auth_repository.dart';
import 'package:omniplay_mobile/features/auth/data/auth_session_controller.dart';
import 'package:omniplay_mobile/features/auth/data/refresh_coordinator.dart';
import 'package:omniplay_mobile/features/auth/data/secure_token_store.dart';
import 'package:omniplay_mobile/features/auth/models/token_pair.dart';

class InMemoryTokenStore implements SecureTokenStore {
  TokenPair? value;
  int writeCount = 0;
  int deleteCount = 0;

  @override
  Future<TokenPair?> read() async => value;

  @override
  Future<void> write(TokenPair pair) async {
    writeCount++;
    value = pair;
  }

  @override
  Future<void> delete() async {
    deleteCount++;
    value = null;
  }
}

void main() {
  TokenPair makePair(String access, String refresh, {DateTime? expiresAt}) =>
      TokenPair(
        accessToken: access,
        refreshToken: refresh,
        tokenType: 'Bearer',
        accessExpiresIn: 900,
        refreshExpiresAt:
            expiresAt ?? DateTime.utc(2026, 12, 1, 0, 0, 0),
      );

  test(
    'T02: concurrent JSON and thumbnail requests share a single refresh and retry once',
    () async {
      final store = InMemoryTokenStore();
      var refreshCalls = 0;
      final refreshGate = Completer<void>();

      final mockHttp = MockClient((request) async {
        if (request.url.path == '/auth/refresh') {
          refreshCalls++;
          await refreshGate.future;
          return http.Response(
            jsonEncode(makePair('access-v2', 'refresh-v2').toJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        final auth = request.headers['Authorization'];
        if (auth == 'Bearer access-v1') {
          return http.Response(
            jsonEncode({
              'code': 'ACCESS_TOKEN_EXPIRED',
              'message': 'Expired',
              'fieldErrors': {},
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        if (auth == 'Bearer access-v2') {
          if (request.url.path == '/catalog') {
            return http.Response(
              jsonEncode({'items': [], 'page': 0, 'size': 20, 'totalElements': 0}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/genres') {
            return http.Response(
              jsonEncode({'items': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('/thumbnail')) {
            return http.Response.bytes(
              Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
              200,
              headers: {'content-type': 'image/png'},
            );
          }
        }
        return http.Response('unexpected', 500);
      });

      final transport = ApiTransport(
        client: mockHttp,
        baseUri: Uri.parse('http://localhost:8080'),
      );
      final authRepo = RemoteAuthRepository(transport);
      final sessions = AuthSessionController(
        store: store,
        now: () => DateTime.utc(2026, 11, 23, 12),
        revokeSession: (t) => authRepo.logout(refreshToken: t),
      );
      await sessions.install(makePair('access-v1', 'refresh-v1'));

      final coordinator = RefreshCoordinator(
        repository: authRepo,
        sessions: sessions,
      );
      final api = ApiClient(
        transport: transport,
        sessions: sessions,
        refresh: coordinator,
      );

      final futures = Future.wait([
        api.getJson('/catalog', expectedStatusCode: 200),
        api.getJson('/genres', expectedStatusCode: 200),
        api.getBytes(
          '/media/20000000-0000-4000-8000-000000000001/thumbnail',
        ),
      ]);

      // Allow all 3 requests to hit 401 and coalesce on the single refresh flight.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(refreshCalls, 1);
      refreshGate.complete();

      final results = await futures;
      expect(refreshCalls, 1);
      expect(sessions.tokens?.accessToken, 'access-v2');
      expect(sessions.tokens?.refreshToken, 'refresh-v2');
      expect(store.value?.refreshToken, 'refresh-v2');
      expect((results[2] as Uint8List).length, 4);
    },
  );

  test(
    'T02: rejected refresh clears session and signs out',
    () async {
      final store = InMemoryTokenStore();
      final mockHttp = MockClient((request) async {
        if (request.url.path == '/auth/refresh') {
          return http.Response(
            jsonEncode({
              'code': 'REFRESH_TOKEN_INVALID',
              'message': 'Revoked',
              'fieldErrors': {},
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'code': 'ACCESS_TOKEN_EXPIRED',
            'message': 'Expired',
            'fieldErrors': {},
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final transport = ApiTransport(
        client: mockHttp,
        baseUri: Uri.parse('http://localhost:8080'),
      );
      final authRepo = RemoteAuthRepository(transport);
      final sessions = AuthSessionController(
        store: store,
        now: () => DateTime.utc(2026, 11, 23, 12),
      );
      await sessions.install(makePair('access-v1', 'refresh-v1'));

      final api = ApiClient(
        transport: transport,
        sessions: sessions,
        refresh: RefreshCoordinator(repository: authRepo, sessions: sessions),
      );

      await expectLater(
        api.getJson('/catalog', expectedStatusCode: 200),
        throwsA(isA<ApiException>()),
      );
      expect(sessions.phase, AuthSessionPhase.signedOut);
      expect(sessions.tokens, isNull);
      expect(store.value, isNull);
    },
  );

  test('logout clears local tokens even when offline and restore rejects expired', () async {
    final store = InMemoryTokenStore();
    final sessions = AuthSessionController(
      store: store,
      now: () => DateTime.utc(2026, 11, 23, 12),
      revokeSession: (_) async => throw const ApiException(
        kind: ApiFailureKind.network,
        code: 'NETWORK_ERROR',
        message: 'offline',
      ),
    );

    await sessions.install(makePair('access-v1', 'refresh-v1'));
    final outcome = await sessions.logout();
    expect(outcome, LogoutOutcome.connectionUnconfirmed);
    expect(sessions.phase, AuthSessionPhase.signedOut);
    expect(sessions.tokens, isNull);
    expect(store.value, isNull);

    // Expired stored token is deleted on restore
    store.value = makePair(
      'old',
      'old-refresh',
      expiresAt: DateTime.utc(2026, 11, 23, 11, 59, 59),
    );
    await sessions.restore();
    expect(sessions.phase, AuthSessionPhase.signedOut);
    expect(store.value, isNull);
  });
}
