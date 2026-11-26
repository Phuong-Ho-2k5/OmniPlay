import '../../../core/network/api_client.dart';
import '../../catalog/models/catalog_json.dart';
import '../models/playlist.dart';

abstract class PlaylistRepository {
  Future<PlaylistPage> list({int page = 0, int size = 20});
  Future<PlaylistSummary> create({
    required String name,
    required String requestId,
  });
  Future<PlaylistDetail> detail(String id);
  Future<PlaylistRenamed> rename({required String id, required String name});
  Future<void> delete(String id);
  Future<PlaylistItemAdded> addItem({
    required String playlistId,
    required String mediaId,
  });
  Future<void> removeItem({
    required String playlistId,
    required String mediaId,
  });
}

class RemotePlaylistRepository implements PlaylistRepository {
  RemotePlaylistRepository(this._api);

  final ApiClient _api;

  @override
  Future<PlaylistPage> list({int page = 0, int size = 20}) async {
    final path = Uri(
      path: '/me/playlists',
      queryParameters: {'page': '$page', 'size': '$size'},
    ).toString();
    final parsed = PlaylistPage.fromJson(
      await _api.getJson(path, expectedStatusCode: 200),
    );
    if (parsed.page != page || parsed.size != size) {
      invalidCatalogResponse();
    }
    return parsed;
  }

  @override
  Future<PlaylistSummary> create({
    required String name,
    required String requestId,
  }) async {
    catalogId(requestId);
    final json = await _api.postJson(
      '/me/playlists',
      body: {'name': name, 'requestId': requestId},
    );
    return PlaylistSummary.fromJson(json);
  }

  @override
  Future<PlaylistDetail> detail(String id) async {
    catalogId(id);
    final json = await _api.getJson(
      '/me/playlists/$id',
      expectedStatusCode: 200,
    );
    return PlaylistDetail.fromJson(json);
  }

  @override
  Future<PlaylistRenamed> rename({
    required String id,
    required String name,
  }) async {
    catalogId(id);
    final json = await _api.patchJson(
      '/me/playlists/$id',
      body: {'name': name},
      expectedStatusCode: 200,
    );
    return PlaylistRenamed.fromJson(json);
  }

  @override
  Future<void> delete(String id) async {
    catalogId(id);
    await _api.deleteNoContent('/me/playlists/$id');
  }

  @override
  Future<PlaylistItemAdded> addItem({
    required String playlistId,
    required String mediaId,
  }) async {
    catalogId(playlistId);
    catalogId(mediaId);
    final json = await _api.putJson(
      '/me/playlists/$playlistId/items/$mediaId',
      expectedStatusCode: 200,
    );
    return PlaylistItemAdded.fromJson(json);
  }

  @override
  Future<void> removeItem({
    required String playlistId,
    required String mediaId,
  }) async {
    catalogId(playlistId);
    catalogId(mediaId);
    await _api.deleteNoContent('/me/playlists/$playlistId/items/$mediaId');
  }
}
