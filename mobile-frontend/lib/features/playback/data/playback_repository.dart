import '../../../core/network/api_client.dart';
import '../../auth/data/auth_session_controller.dart';
import '../../auth/data/refresh_coordinator.dart';
import '../../auth/data/session_store.dart';
import '../../catalog/models/catalog_json.dart';
import '../models/playback_metadata.dart';
import '../models/playback_report.dart';

abstract class PlaybackRepository {
  Future<PlaybackMetadata> fetchMetadata(String mediaId);
  StreamAuthRequest buildStreamRequest(String streamPath);
  Future<bool> refreshAccessToken({
    required int generation,
    required int revision,
  });
  Future<PlaybackAttempt> createAttempt({
    required String attemptId,
    required String mediaId,
    String? playlistItemId,
  });
  Future<PlaybackProgressResult> reportProgress({
    required String mediaId,
    required PlaybackReport report,
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

  @override
  Future<PlaybackAttempt> createAttempt({
    required String attemptId,
    required String mediaId,
    String? playlistItemId,
  }) async {
    catalogId(attemptId);
    catalogId(mediaId);
    if (playlistItemId != null) catalogId(playlistItemId);
    final json = await _api.postJson(
      '/me/playback-attempts',
      body: {
        'attemptId': attemptId,
        'mediaId': mediaId,
        'playlistItemId': playlistItemId,
      },
    );
    return PlaybackAttempt.fromJson(json);
  }

  @override
  Future<PlaybackProgressResult> reportProgress({
    required String mediaId,
    required PlaybackReport report,
  }) async {
    catalogId(mediaId);
    final json = await _api.putJson(
      '/me/progress/$mediaId',
      body: report.toJson(),
      expectedStatusCode: 200,
    );
    return PlaybackProgressResult.fromJson(json);
  }
}
