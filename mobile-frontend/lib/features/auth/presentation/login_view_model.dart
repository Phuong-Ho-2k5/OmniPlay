import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../data/session_store.dart';
import 'auth_form_state.dart';
import 'auth_form_validator.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._repository, this._sessions);
  final AuthRepository _repository;
  final SessionStore _sessions;
  AuthFormState _state = AuthFormState(AuthFormStatus.idle);
  bool _disposed = false;
  AuthFormState get state => _state;
  Future<void> submit({required String email, required String password}) async {
    if (_disposed || _state.status == AuthFormStatus.submitting) return;
    final errors = AuthFormValidator.login(email: email, password: password);
    if (errors.isNotEmpty) {
      _update(AuthFormState(AuthFormStatus.error, fieldErrors: errors));
      return;
    }
    _update(AuthFormState(AuthFormStatus.submitting));
    try {
      final tokens = await _repository.login(email: email, password: password);
      if (_disposed) return;
      _sessions.replace(tokens);
      _update(AuthFormState(AuthFormStatus.success));
    } catch (error) {
      _update(AuthFormState.failure(error, registration: false));
    }
  }

  void reset() {
    if (!_disposed && _state.status != AuthFormStatus.submitting) {
      _update(AuthFormState(AuthFormStatus.idle));
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
