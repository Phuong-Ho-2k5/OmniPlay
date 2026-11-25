import '../../../core/network/api_client.dart';
import '../models/listening_session.dart';

abstract class ListeningSessionRepository {
  Future<ListeningSessionState> getSession(ListeningSessionType type);
  Future<ListeningSessionState> saveSession(
    ListeningSessionType type,
    SaveListeningSessionPayload payload,
  );
}

class RemoteListeningSessionRepository implements ListeningSessionRepository {
  RemoteListeningSessionRepository(this._api);

  final ApiClient _api;

  @override
  Future<ListeningSessionState> getSession(ListeningSessionType type) async {
    final json = await _api.getJson(
      '/me/listening-sessions/${type.apiValue}',
      expectedStatusCode: 200,
    );
    return ListeningSessionState.fromJson(json);
  }

  @override
  Future<ListeningSessionState> saveSession(
    ListeningSessionType type,
    SaveListeningSessionPayload payload,
  ) async {
    final json = await _api.putJson(
      '/me/listening-sessions/${type.apiValue}',
      body: payload.toJson(),
      expectedStatusCode: 200,
    );
    return ListeningSessionState.fromJson(json);
  }
}
