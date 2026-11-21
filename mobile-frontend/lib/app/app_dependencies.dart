import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../features/auth/data/session_store.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/login_view_model.dart';
import '../features/auth/presentation/register_view_model.dart';
import '../features/connection/data/health_repository.dart';
import '../features/connection/presentation/connection_view_model.dart';

class AppDependencies {
  AppDependencies(AppConfig config, {http.Client? client})
    : _client = client ?? http.Client() {
    apiClient = ApiClient(
      client: _client,
      baseUri: config.apiBaseUri,
      accessTokenProvider: () => sessionStore.tokens?.accessToken,
    );
    authRepository = RemoteAuthRepository(apiClient);
    connectionViewModel = ConnectionViewModel(
      RemoteHealthRepository(apiClient),
    );
  }
  final http.Client _client;
  final sessionStore = InMemorySessionStore();
  late final ApiClient apiClient;
  late final AuthRepository authRepository;
  late final ConnectionViewModel connectionViewModel;

  LoginViewModel createLoginViewModel() =>
      LoginViewModel(authRepository, sessionStore);
  RegisterViewModel createRegisterViewModel() =>
      RegisterViewModel(authRepository);

  void dispose() {
    connectionViewModel.dispose();
    sessionStore.dispose();
    _client.close();
  }
}
