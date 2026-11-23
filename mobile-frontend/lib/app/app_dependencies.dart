import 'dart:async';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_transport.dart';
import '../features/auth/data/refresh_coordinator.dart';
import '../features/auth/data/auth_session_controller.dart';
import '../features/auth/data/secure_token_store.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/login_view_model.dart';
import '../features/auth/presentation/register_view_model.dart';
import '../features/connection/data/health_repository.dart';
import '../features/connection/presentation/connection_view_model.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/catalog/presentation/catalog_view_model.dart';

class AppDependencies {
  AppDependencies(
    AppConfig config, {
    http.Client? client,
    SecureTokenStore? tokenStore,
    DateTime Function()? now,
  }) : _client = client ?? http.Client() {
    final transport = ApiTransport(client: _client, baseUri: config.apiBaseUri);
    authRepository = RemoteAuthRepository(transport);
    sessionStore = AuthSessionController(
      store: tokenStore ?? SecureTokenStore(),
      now: now,
      revokeSession: (token) => authRepository.logout(refreshToken: token),
    );
    final refresh = RefreshCoordinator(
      repository: authRepository,
      sessions: sessionStore,
    );
    apiClient = ApiClient(
      transport: transport,
      sessions: sessionStore,
      refresh: refresh,
    );
    catalogRepository = RemoteCatalogRepository(apiClient);
    connectionViewModel = ConnectionViewModel(
      RemoteHealthRepository(apiClient),
    );
    unawaited(sessionStore.restore());
  }
  final http.Client _client;
  late final AuthSessionController sessionStore;
  late final ApiClient apiClient;
  late final AuthRepository authRepository;
  late final CatalogRepository catalogRepository;
  late final ConnectionViewModel connectionViewModel;

  LoginViewModel createLoginViewModel() =>
      LoginViewModel(authRepository, sessionStore);
  RegisterViewModel createRegisterViewModel() =>
      RegisterViewModel(authRepository);
  CatalogViewModel createCatalogViewModel() =>
      CatalogViewModel(catalogRepository);

  void dispose() {
    connectionViewModel.dispose();
    sessionStore.dispose();
    _client.close();
  }
}
