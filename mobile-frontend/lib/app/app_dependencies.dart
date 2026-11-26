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
import '../features/playback/data/listening_session_repository.dart';
import '../features/playback/data/playback_repository.dart';
import '../features/playback/presentation/media_player_view_model.dart';
import '../features/playback/presentation/playback_lifecycle_coordinator.dart';
import '../features/playback/presentation/player_coordinator.dart';
import '../features/playlist/data/playlist_repository.dart';
import '../features/playlist/presentation/playlists_view_model.dart';
import '../features/saved/data/saved_repository.dart';
import '../features/saved/presentation/saved_view_model.dart';
import '../features/catalog/models/content_type.dart';

class AppDependencies {
  AppDependencies(
    AppConfig config, {
    http.Client? client,
    SecureTokenStore? tokenStore,
    DateTime Function()? now,
  }) : _client = client ?? http.Client() {
    final transport = ApiTransport(client: _client, baseUri: config.apiBaseUri);
    authRepository = RemoteAuthRepository(transport);
    playbackLifecycleCoordinator = PlaybackLifecycleCoordinator();
    sessionStore = AuthSessionController(
      store: tokenStore ?? SecureTokenStore(),
      now: now,
      revokeSession: (token) => authRepository.logout(refreshToken: token),
      beforeLogout: () => playbackLifecycleCoordinator.stopAndFlushAll(),
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
    playbackRepository = RemotePlaybackRepository(
      api: apiClient,
      baseUri: config.apiBaseUri,
      sessions: sessionStore,
      refresh: refresh,
    );
    listeningSessionRepository = RemoteListeningSessionRepository(apiClient);
    savedRepository = RemoteSavedRepository(apiClient);
    playlistRepository = RemotePlaylistRepository(apiClient);
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
  late final PlaybackRepository playbackRepository;
  late final ListeningSessionRepository listeningSessionRepository;
  late final SavedRepository savedRepository;
  late final PlaylistRepository playlistRepository;
  late final PlaybackLifecycleCoordinator playbackLifecycleCoordinator;
  late final ConnectionViewModel connectionViewModel;

  LoginViewModel createLoginViewModel() =>
      LoginViewModel(authRepository, sessionStore);
  RegisterViewModel createRegisterViewModel() =>
      RegisterViewModel(authRepository);
  CatalogViewModel createCatalogViewModel() =>
      CatalogViewModel(catalogRepository);
  SavedViewModel createSavedViewModel() => SavedViewModel(savedRepository);
  PlaylistsViewModel createPlaylistsViewModel() =>
      PlaylistsViewModel(playlistRepository);
  PlayerCoordinator createPlayerCoordinator() => PlayerCoordinator(
    playbackRepository: playbackRepository,
    sessionRepository: listeningSessionRepository,
    catalogRepository: catalogRepository,
    lifecycleCoordinator: playbackLifecycleCoordinator,
  );
  MediaPlayerViewModel createMediaPlayerViewModel({
    required String mediaId,
    required ContentType type,
    Future<void> Function()? onBeforeVideoPlay,
  }) => MediaPlayerViewModel(
    repository: playbackRepository,
    mediaId: mediaId,
    type: type,
    lifecycleCoordinator: playbackLifecycleCoordinator,
    onBeforeVideoPlay: onBeforeVideoPlay,
  );

  void dispose() {
    connectionViewModel.dispose();
    sessionStore.dispose();
    _client.close();
  }
}
