import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

abstract interface class HealthRepository {
  Future<void> check();
}

class RemoteHealthRepository implements HealthRepository {
  const RemoteHealthRepository(this._client);
  final ApiClient _client;

  @override
  Future<void> check() async {
    final data = await _client.getJson(
      '/actuator/health',
      expectedStatusCode: 200,
      authenticated: false,
    );
    if (data['status'] != 'UP') {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        code: 'INVALID_HEALTH_RESPONSE',
        message: 'Unexpected health response.',
      );
    }
  }
}
