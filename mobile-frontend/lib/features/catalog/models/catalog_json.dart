import '../../../core/network/api_exception.dart';

Never invalidCatalogResponse() => throw const ApiException(
  kind: ApiFailureKind.invalidResponse,
  code: 'INVALID_RESPONSE',
  message: 'Dữ liệu nội dung từ máy chủ không hợp lệ.',
);

Map<String, dynamic> catalogObject(Object? value) =>
    value is Map<String, dynamic> ? value : invalidCatalogResponse();

String catalogString(Object? value) =>
    value is String ? value : invalidCatalogResponse();

String catalogId(Object? value) {
  final id = catalogString(value);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(id)) {
    invalidCatalogResponse();
  }
  return id;
}

int catalogInt(Object? value, {int min = 0}) =>
    value is int && value >= min ? value : invalidCatalogResponse();

List<dynamic> catalogList(Object? value) =>
    value is List ? value : invalidCatalogResponse();

String? catalogNullableString(Object? value) =>
    value == null ? null : catalogString(value);
