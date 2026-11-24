import '../../../core/network/api_client.dart';
import '../../auth/data/auth_session_controller.dart';
import '../../auth/data/refresh_coordinator.dart';
import '../../auth/data/session_store.dart';
import '../../catalog/models/catalog_json.dart';
import '../models/playback_metadata.dart';

abstract class PlaybackRepository {
  Future<PlaybackMetadata> fetchMetadata(String mediaId);
  StreamAuthRequest buildStreamRequest(String streamPath);
  Future<bool> refreshAccessToken({
    required int generation,
    required int revision,
  });
}

class RemotePlaybackRepository implements PlaybackRepository {
  RemotePlaybackRepository({
    required this._api,
    required this._baseUri,
    required this._sessions,
    required this._refresh,
  });

  final ApiClient _api;
  final Uri _baseUri;
  final AuthSessionController _sessions;
  final RefreshCoordinator _refresh;

  @override
  Future<PlaybackMetadata> fetchMetadata(String mediaId) async {
    catalogId(mediaId);
    final json = await _api.getJson(
      '/media/$mediaId/playback',
      expectedStatusCode: 200,
    );
    final metadata = PlaybackMetadata.fromJson(json);
    if (metadata.mediaId.toLowerCase() != mediaId.toLowerCase()) {
      invalidCatalogResponse();
    }
    return metadata;
  }

  @override
  StreamAuthRequest buildStreamRequest(String streamPath) {
    final validatedPath = validateStreamPath(streamPath);
    final pair = _sessions.tokens;
    if (pair == null) throw const SessionChangedException();
    return StreamAuthRequest(
      uri: _baseUri.resolve(validatedPath),
      headers: {'Authorization': 'Bearer ${pair.accessToken}'},
      generation: _sessions.generation,
      revision: _sessions.revision,
    );
  }

  @override
  Future<bool> refreshAccessToken({
    required int generation,
    required int revision,
  }) async {
    if (!_sessions.isCurrent(generation)) return false;
    await _refresh.refreshFor(generation: generation, revision: revision);
    return _sessions.isCurrent(generation) && _sessions.tokens != null;
  }
}
