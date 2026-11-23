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
import 'package:omniplay_mobile/features/catalog/data/catalog_repository.dart';
import 'package:omniplay_mobile/features/catalog/models/catalog_page.dart';
import 'package:omniplay_mobile/features/catalog/models/catalog_query.dart';
import 'package:omniplay_mobile/features/catalog/models/content_type.dart';

class _MemStore implements SecureTokenStore {
  TokenPair? _pair;
  @override
  Future<void> delete() async => _pair = null;
  @override
  Future<TokenPair?> read() async => _pair;
  @override
  Future<void> write(TokenPair pair) async => _pair = pair;
}

void main() {
  test('CatalogQuery picks /catalog vs /catalog/search and encodes Vietnamese & special chars', () {
    expect(const CatalogQuery().path, '/catalog?page=0&size=20');
    expect(
      const CatalogQuery(type: ContentType.video, page: 1, size: 10).path,
      '/catalog?type=VIDEO&page=1&size=10',
    );

    const search = CatalogQuery(
      keyword: '  Nhạc & % + #  ',
      type: ContentType.music,
      genreId: '10000000-0000-4000-8000-000000000001',
    );
    final uri = Uri.parse(search.path);
    expect(uri.path, '/catalog/search');
    expect(uri.queryParameters['q'], 'Nhạc & % + #');
    expect(uri.queryParameters['type'], 'MUSIC');
    expect(uri.queryParameters['genreId'], '10000000-0000-4000-8000-000000000001');
  });

  test('CatalogPage rejects malformed count or size > 50 and accepts valid empty page', () {
    // Valid empty page beyond end
    final emptyBeyond = CatalogPage.fromJson({
      'items': <Object>[],
      'page': 1,
      'size': 20,
      'totalElements': 10,
    });
    expect(emptyBeyond.items, isEmpty);
    expect(emptyBeyond.totalElements, 10);

    // Invalid: items empty when page 0 has totalElements 5
    expect(
      () => CatalogPage.fromJson({
        'items': <Object>[],
        'page': 0,
        'size': 20,
        'totalElements': 5,
      }),
      throwsA(isA<ApiException>()),
    );

    // Invalid: size > 50
    expect(
      () => CatalogPage.fromJson({
        'items': <Object>[],
        'page': 0,
        'size': 51,
        'totalElements': 0,
      }),
      throwsA(isA<ApiException>()),
    );
  });

  test('RemoteCatalogRepository.thumbnail blocks external URLs before sending credentials', () async {
    var networkCalled = false;
    final mockHttp = MockClient((request) async {
      networkCalled = true;
      return http.Response.bytes(
        Uint8List.fromList([0xff, 0xd8, 0xff]),
        200,
        headers: {'content-type': 'image/jpeg'},
      );
    });
    final transport = ApiTransport(
      client: mockHttp,
      baseUri: Uri.parse('http://localhost:8080'),
    );
    final sessions = AuthSessionController(
      store: _MemStore(),
      now: () => DateTime.utc(2026, 11, 23, 12),
    );
    await sessions.install(
      TokenPair(
        accessToken: 'secret-jwt',
        refreshToken: 'refresh',
        tokenType: 'Bearer',
        accessExpiresIn: 900,
        refreshExpiresAt: DateTime.utc(2026, 12, 1),
      ),
    );
    final api = ApiClient(
      transport: transport,
      sessions: sessions,
      refresh: RefreshCoordinator(
        repository: RemoteAuthRepository(transport),
        sessions: sessions,
      ),
    );
    final repo = RemoteCatalogRepository(api);

    await expectLater(
      repo.thumbnail('https://evil.example/media/20000000-0000-4000-8000-000000000001/thumbnail'),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      repo.thumbnail('/media/../etc/passwd'),
      throwsA(isA<ApiException>()),
    );
    expect(networkCalled, isFalse);

    final bytes = await repo.thumbnail(
      '/media/20000000-0000-4000-8000-000000000001/thumbnail',
    );
    expect(networkCalled, isTrue);
    expect(bytes, isNotEmpty);

    // Also verify invalid detail response id mismatch
    final badHttp = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'id': '20000000-0000-4000-8000-000000000099',
          'type': 'POST',
          'title': 'Wrong ID',
          'description': 'Desc',
          'thumbnailUrl': null,
          'durationSeconds': null,
          'genreIds': [],
          'saved': false,
          'content': 'Body',
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final badRepo = RemoteCatalogRepository(
      ApiClient(
        transport: ApiTransport(
          client: badHttp,
          baseUri: Uri.parse('http://localhost:8080'),
        ),
        sessions: sessions,
        refresh: RefreshCoordinator(
          repository: RemoteAuthRepository(transport),
          sessions: sessions,
        ),
      ),
    );
    await expectLater(
      badRepo.detail(
        id: '20000000-0000-4000-8000-000000000001',
        type: ContentType.post,
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
