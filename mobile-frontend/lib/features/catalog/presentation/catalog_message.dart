import '../../../core/network/api_exception.dart';

String catalogErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.code == 'CONTENT_UNAVAILABLE') {
      return 'Nội dung không còn khả dụng.';
    }
    if (error.kind == ApiFailureKind.network ||
        error.kind == ApiFailureKind.timeout) {
      return 'Không thể kết nối đến máy chủ. Vui lòng thử lại.';
    }
    if (error.code == 'VALIDATION_ERROR') {
      return error.fieldErrors.isEmpty
          ? error.message
          : error.fieldErrors.values.join('\n');
    }
    if (error.kind == ApiFailureKind.invalidResponse) {
      return 'Dữ liệu từ máy chủ không hợp lệ. Vui lòng thử lại.';
    }
    if (error.statusCode == 401) return 'Phiên đăng nhập không còn hợp lệ.';
  }
  return 'Không thể tải nội dung. Vui lòng thử lại.';
}
