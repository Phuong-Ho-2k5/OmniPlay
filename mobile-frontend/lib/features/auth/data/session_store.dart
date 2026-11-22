import '../models/token_pair.dart';

abstract interface class SessionStore {
  TokenPair? get tokens;
  int get generation;
  int get revision;
  Future<void> install(TokenPair tokens);
  Future<void> clear({String? notice});
}

class SessionChangedException implements Exception {
  const SessionChangedException();
}
