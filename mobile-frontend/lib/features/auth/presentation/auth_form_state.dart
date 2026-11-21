import '../../../core/network/api_exception.dart';

enum AuthFormStatus { idle, submitting, success, error }

class AuthFormState {
  AuthFormState(
    this.status, {
    this.message,
    Map<String, String> fieldErrors = const {},
  }) : fieldErrors = Map.unmodifiable(fieldErrors);
  final AuthFormStatus status;
  final String? message;
  final Map<String, String> fieldErrors;

  factory AuthFormState.failure(Object error, {required bool registration}) {
    if (error is ApiException) {
      if (error.statusCode == 400) {
        return AuthFormState(
          AuthFormStatus.error,
          message: 'Vui lòng kiểm tra thông tin đã nhập.',
          fieldErrors: error.fieldErrors,
        );
      }
      if (registration &&
          error.statusCode == 409 &&
          error.code == 'EMAIL_ALREADY_USED') {
        return AuthFormState(
          AuthFormStatus.error,
          message: 'Email đã được sử dụng. Bạn có thể quay lại đăng nhập.',
          fieldErrors: {'email': 'Email đã được sử dụng.'},
        );
      }
      if (!registration &&
          error.statusCode == 401 &&
          error.code == 'INVALID_CREDENTIALS') {
        return AuthFormState(
          AuthFormStatus.error,
          message: 'Email hoặc mật khẩu không đúng.',
        );
      }
      if (registration &&
          [
            ApiFailureKind.timeout,
            ApiFailureKind.network,
            ApiFailureKind.invalidResponse,
          ].contains(error.kind)) {
        return AuthFormState(
          AuthFormStatus.error,
          message: 'Việc tạo tài khoản chưa được xác nhận. Bạn có thể quay lại đăng nhập để kiểm tra hoặc thử lại.',
        );
      }
      return AuthFormState(
        AuthFormStatus.error,
        message: switch (error.kind) {
          ApiFailureKind.network =>
            'Không thể kết nối. Hãy kiểm tra mạng và thử lại.',
          ApiFailureKind.timeout =>
            'Kết nối mất quá nhiều thời gian. Vui lòng thử lại.',
          ApiFailureKind.invalidResponse =>
            'Phản hồi chưa hợp lệ. Vui lòng thử lại.',
          ApiFailureKind.http =>
            'Máy chủ chưa thể xử lý yêu cầu. Vui lòng thử lại.',
        },
      );
    }
    return AuthFormState(
      AuthFormStatus.error,
      message: 'Không thể hoàn tất yêu cầu. Vui lòng thử lại.',
    );
  }
}
