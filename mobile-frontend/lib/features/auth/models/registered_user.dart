import 'auth_json.dart';

class RegisteredUser {
  const RegisteredUser({
    required this.userId,
    required this.email,
    required this.displayName,
  });
  final String userId;
  final String email;
  final String displayName;
  factory RegisteredUser.fromJson(Map<String, dynamic> json) {
    final id = authString(json, 'userId');
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      invalidAuthResponse();
    }
    return RegisteredUser(
      userId: id,
      email: authString(json, 'email'),
      displayName: authString(json, 'displayName'),
    );
  }
}
