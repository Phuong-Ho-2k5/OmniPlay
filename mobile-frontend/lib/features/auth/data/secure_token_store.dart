import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_exception.dart';
import '../models/token_pair.dart';

abstract interface class SecureStorageBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecureStorageBackend implements SecureStorageBackend {
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class SecureTokenStore {
  SecureTokenStore({SecureStorageBackend? backend})
    : _backend = backend ?? PlatformSecureStorageBackend();
  static const key = 'omniplay.auth.session.v1';
  final SecureStorageBackend _backend;
  Future<TokenPair?> read() async {
    final raw = await _backend.read(key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) throw const FormatException();
      return TokenPair.fromJson(data);
    } on FormatException {
      throw const CorruptTokenStorageException();
    } on ApiException {
      throw const CorruptTokenStorageException();
    }
  }

  Future<void> write(TokenPair tokens) =>
      _backend.write(key, jsonEncode(tokens.toJson()));
  Future<void> delete() => _backend.delete(key);
}

class CorruptTokenStorageException implements Exception {
  const CorruptTokenStorageException();
}

class SessionStorageException implements Exception {
  const SessionStorageException();
}
