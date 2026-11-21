import 'dart:convert';

class AuthFormValidator {
  static Map<String, String> register({
    required String email,
    required String password,
    required String displayName,
    required String confirmPassword,
  }) {
    final errors = login(email: email, password: password);
    final name = displayName.trim();
    if (name.isEmpty ||
        name.runes.length > 100 ||
        !_isUnicode(name) ||
        name.contains('\u0000')) {
      errors['displayName'] = 'Tên hiển thị phải có từ 1 đến 100 ký tự.';
    }
    if (confirmPassword.isEmpty || password != confirmPassword) {
      errors['confirmPassword'] = 'Mật khẩu xác nhận không khớp.';
    }
    return errors;
  }

  static Map<String, String> login({
    required String email,
    required String password,
  }) {
    final errors = <String, String>{};
    final address = email.trim();
    if (address.isEmpty ||
        address.runes.length > 255 ||
        !_isUnicode(address) ||
        address.contains('\u0000')) {
      errors['email'] = 'Vui lòng nhập email không quá 255 ký tự.';
    }
    if (!_isUnicode(password) ||
        password.runes.length < 8 ||
        utf8.encode(password).length > 72) {
      errors['password'] =
          'Mật khẩu cần ít nhất 8 ký tự và không quá 72 byte UTF-8.';
    }
    return errors;
  }

  static bool _isUnicode(String value) {
    for (var i = 0; i < value.length; i++) {
      final unit = value.codeUnitAt(i);
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (++i >= value.length) return false;
        final next = value.codeUnitAt(i);
        if (next < 0xDC00 || next > 0xDFFF) return false;
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        return false;
      }
    }
    return true;
  }
}
