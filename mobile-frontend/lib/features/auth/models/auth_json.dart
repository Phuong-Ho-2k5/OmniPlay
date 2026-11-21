import '../../../core/network/api_exception.dart';

Never invalidAuthResponse() => throw const ApiException(
  kind: ApiFailureKind.invalidResponse,
  code: 'INVALID_RESPONSE',
  message: 'Invalid authentication response.',
);

String authString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) invalidAuthResponse();
  return value;
}

DateTime authInstant(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?Z$')
      .hasMatch(value)) {
    invalidAuthResponse();
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      !parsed.isUtc ||
      parsed.year != int.parse(value.substring(0, 4)) ||
      parsed.month != int.parse(value.substring(5, 7)) ||
      parsed.day != int.parse(value.substring(8, 10)) ||
      parsed.hour != int.parse(value.substring(11, 13)) ||
      parsed.minute != int.parse(value.substring(14, 16)) ||
      parsed.second != int.parse(value.substring(17, 19))) {
    invalidAuthResponse();
  }
  return parsed;
}
