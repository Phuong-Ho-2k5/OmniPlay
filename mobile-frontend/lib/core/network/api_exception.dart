enum ApiFailureKind { network, timeout, http, invalidResponse }

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.code,
    required this.message,
    this.fieldErrors = const {},
    this.statusCode,
  });

  final ApiFailureKind kind;
  final String code;
  final String message;
  final Map<String, String> fieldErrors;
  final int? statusCode;
}
