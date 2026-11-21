import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../models/registered_user.dart';
import 'auth_form_state.dart';
import 'auth_form_validator.dart';

class RegisterViewModel extends ChangeNotifier {
  RegisterViewModel(this._repository);
  final AuthRepository _repository;
  RegisteredUser? _registeredUser;
  AuthFormState _state = AuthFormState(AuthFormStatus.idle);
  bool _disposed = false;
  RegisteredUser? get registeredUser => _registeredUser;
  AuthFormState get state => _state;
  Future<void> submit({
    required String email,
    required String password,
    required String displayName,
    required String confirmPassword,
  }) async {
    if (_disposed || _state.status == AuthFormStatus.submitting) return;
    final errors = AuthFormValidator.register(
      email: email,
      password: password,
      displayName: displayName,
      confirmPassword: confirmPassword,
    );
    if (errors.isNotEmpty) {
      _update(AuthFormState(AuthFormStatus.error, fieldErrors: errors));
      return;
    }
    _registeredUser = null;
    _update(AuthFormState(AuthFormStatus.submitting));
    try {
      final user = await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (_disposed) return;
      _registeredUser = user;
      _update(AuthFormState(AuthFormStatus.success));
    } catch (error) {
      _update(AuthFormState.failure(error, registration: true));
    }
  }

  void _update(AuthFormState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
