import 'dart:async';
import 'dart:convert';
import 'dart:io' show IOException;

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiTransport {
  ApiTransport({
    required this._client,
    required this._baseUri,
    this._timeout = const Duration(seconds: 10),
  });
  final http.Client _client;
  final Uri _baseUri;
  final Duration _timeout;

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    required int expectedStatusCode,
  }) => sendJson(
    'POST',
    path,
    encodedBody: jsonEncode(body),
    expectedStatusCode: expectedStatusCode,
  );

  Future<void> postNoContent(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    await _request(
      'POST',
      path,
      encodedBody: jsonEncode(body),
      expectedStatusCode: 204,
      noContent: true,
    );
  }

  Future<Map<String, dynamic>> sendJson(
    String method,
    String path, {
    String? encodedBody,
    int? expectedStatusCode,
    String? accessToken,
  }) async => (await _request(
    method,
    path,
    encodedBody: encodedBody,
    expectedStatusCode: expectedStatusCode,
    accessToken: accessToken,
  ))!;

  Future<Map<String, dynamic>?> _request(
    String method,
    String path, {
    String? encodedBody,
    int? expectedStatusCode,
    String? accessToken,
    bool noContent = false,
  }) async {
    final relative = Uri.parse(path);
    if (!path.startsWith('/') || relative.hasAuthority || relative.hasScheme) {
      throw ArgumentError(
        'API path must be relative to the configured server root.',
      );
    }
    final abort = Completer<void>.sync();
    final request = http.AbortableRequest(
      method,
      _baseUri.resolveUri(relative),
      abortTrigger: abort.future,
    )..headers['Accept'] = 'application/json';
    if (encodedBody != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.bodyBytes = utf8.encode(encodedBody);
    }
    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    final http.Response response;
    try {
      response =
          await (() async => http.Response.fromStream(
            await _client.send(request),
          ))().timeout(
            _timeout,
            onTimeout: () {
              abort.complete();
              throw TimeoutException('Request timed out.');
            },
          );
    } on TimeoutException {
      throw const ApiException(
        kind: ApiFailureKind.timeout,
        code: 'REQUEST_TIMEOUT',
        message: 'Request timed out.',
      );
    } on http.ClientException {
      throw const ApiException(
        kind: ApiFailureKind.network,
        code: 'NETWORK_ERROR',
        message: 'Unable to connect.',
      );
    } on IOException {
      throw const ApiException(
        kind: ApiFailureKind.network,
        code: 'NETWORK_ERROR',
        message: 'Unable to connect.',
      );
    }
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) data = decoded;
    } on FormatException {
      /* Preserve HTTP failures even when a gateway returns HTML. */
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final fields = <String, String>{};
      final raw = data?['fieldErrors'];
      if (raw is Map) {
        for (final entry in raw.entries) {
          if (entry.key is String && entry.value is String) {
            fields[entry.key as String] = entry.value as String;
          }
        }
      }
      throw ApiException(
        kind: ApiFailureKind.http,
        statusCode: response.statusCode,
        code: data?['code'] is String ? data!['code'] as String : 'HTTP_ERROR',
        message: data?['message'] is String
            ? data!['message'] as String
            : 'Server could not process the request.',
        fieldErrors: Map.unmodifiable(fields),
      );
    }
    if ((expectedStatusCode != null &&
            response.statusCode != expectedStatusCode) ||
        (noContent ? response.bodyBytes.isNotEmpty : data == null)) {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        code: 'INVALID_RESPONSE',
        message: 'Invalid server response.',
      );
    }
    return data;
  }
}
