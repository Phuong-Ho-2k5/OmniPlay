import '../../../core/network/api_client.dart';
import '../models/registered_user.dart';
import '../models/token_pair.dart';

abstract interface class AuthRepository {
  Future<RegisteredUser> register({
    required String email,
    required String password,
    required String displayName,
  });
  Future<TokenPair> login({required String email, required String password});
}

class RemoteAuthRepository implements AuthRepository {
  const RemoteAuthRepository(this._client);
  final ApiClient _client;
  @override
  Future<RegisteredUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async => RegisteredUser.fromJson(
    await _client.postJson(
      '/auth/register',
      body: {'email': email, 'password': password, 'displayName': displayName},
      expectedStatusCode: 201,
    ),
  );
  @override
  Future<TokenPair> login({
    required String email,
    required String password,
  }) async => TokenPair.fromJson(
    await _client.postJson(
      '/auth/login',
      body: {'email': email, 'password': password},
      expectedStatusCode: 200,
    ),
  );
}
