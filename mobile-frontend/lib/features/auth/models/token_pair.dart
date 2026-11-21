import 'auth_json.dart';

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.accessExpiresIn,
    required this.refreshExpiresAt,
  });
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int accessExpiresIn;
  final DateTime refreshExpiresAt;
  factory TokenPair.fromJson(Map<String, dynamic> json) {
    if (json['tokenType'] != 'Bearer' ||
        json['accessExpiresIn'] is! int ||
        json['accessExpiresIn'] != 900) {
      invalidAuthResponse();
    }
    return TokenPair(
      accessToken: authString(json, 'accessToken'),
      refreshToken: authString(json, 'refreshToken'),
      tokenType: 'Bearer',
      accessExpiresIn: 900,
      refreshExpiresAt: authInstant(authString(json, 'refreshExpiresAt')),
    );
  }
}
