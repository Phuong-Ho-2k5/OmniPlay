enum AppEnvironment { dev, demo }

class AppConfig {
  const AppConfig._(this.environment, this.apiBaseUri);

  final AppEnvironment environment;
  final Uri apiBaseUri;

  factory AppConfig.fromEnvironment() => AppConfig.fromValues(
    environment: const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
  );

  factory AppConfig.fromValues({
    required String environment,
    required String apiBaseUrl,
  }) {
    final env = switch (environment) {
      'dev' => AppEnvironment.dev,
      'demo' => AppEnvironment.demo,
      _ => throw ArgumentError('APP_ENV must be dev or demo.'),
    };
    final value = apiBaseUrl.trim().isEmpty && env == AppEnvironment.dev
        ? 'http://10.0.2.2:8080'
        : apiBaseUrl.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.port < 1 ||
        uri.port > 65535 ||
        (env == AppEnvironment.demo && uri.scheme != 'https')) {
      throw ArgumentError(
        'API_BASE_URL must be a server origin; demo requires HTTPS.',
      );
    }
    return AppConfig._(env, uri.replace(path: ''));
  }
}
