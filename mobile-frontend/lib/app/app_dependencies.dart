import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../features/connection/data/health_repository.dart';
import '../features/connection/presentation/connection_view_model.dart';

class AppDependencies {
  AppDependencies(AppConfig config, {http.Client? client})
    : _client = client ?? http.Client() {
    connectionViewModel = ConnectionViewModel(
      RemoteHealthRepository(
        ApiClient(client: _client, baseUri: config.apiBaseUri),
      ),
    );
  }
  final http.Client _client;
  late final ConnectionViewModel connectionViewModel;

  void dispose() {
    connectionViewModel.dispose();
    _client.close();
  }
}
