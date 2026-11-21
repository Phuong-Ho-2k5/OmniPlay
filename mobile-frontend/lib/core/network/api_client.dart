import 'dart:async';
import 'dart:convert';
import 'dart:io' show IOException;

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required this._client,
    required this._baseUri,
    this._timeout = const Duration(seconds: 10),
    this._accessTokenProvider,
  });

  final http.Client _client;
  final Uri _baseUri;
  final Duration _timeout;
  final String? Function()? _accessTokenProvider;

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    required int expectedStatusCode,
    bool authenticated = false,
  }) => _request(
    'POST',
    path,
    body: body,
    expectedStatusCode: expectedStatusCode,
    authenticated: authenticated,
  );

  Future<Map<String, dynamic>> getJson(
    String path, {
    int? expectedStatusCode,
    bool authenticated = true,
  }) => _request(
    'GET',
    path,
    expectedStatusCode: expectedStatusCode,
    authenticated: authenticated,
  );

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    int? expectedStatusCode,
    required bool authenticated,
  }) async {
    final relative = Uri.parse(path);
    if (!path.startsWith('/') || relative.hasAuthority || relative.hasScheme) {
      throw ArgumentError(
        'API path must be relative to the configured server root.',
      );
    }
    final http.Response response;
    // Signal the transport before returning a timeout to a caller that may retry.
    final abort = Completer<void>.sync();
    final request = http.AbortableRequest(
      method,
      _baseUri.resolveUri(relative),
      abortTrigger: abort.future,
    )..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.bodyBytes = utf8.encode(jsonEncode(body));
    }
    if (authenticated) {
      final token = _accessTokenProvider?.call();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }
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
      // An HTTP failure can be HTML or an empty response from a gateway.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final fields = <String, String>{};
      final rawFields = data?['fieldErrors'];
      if (rawFields is Map) {
        for (final entry in rawFields.entries) {
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
    if (data == null ||
        (expectedStatusCode != null &&
            response.statusCode != expectedStatusCode)) {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        code: 'INVALID_RESPONSE',
        message: 'Invalid server response.',
      );
    }
    return data;
  }
}
