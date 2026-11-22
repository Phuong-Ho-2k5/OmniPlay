import 'package:material_ui/material_ui.dart';

import 'auth_form_state.dart';
import 'auth_form_widgets.dart';
import 'login_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.createViewModel,
    required this.registerScreenBuilder,
    this.notice,
  });
  final LoginViewModel Function() createViewModel;
  final WidgetBuilder registerScreenBuilder;
  final String? notice;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginViewModel _model;
  final _email = TextEditingController(), _password = TextEditingController();
  String? _successMessage;
  bool _registerOpen = false;
  @override
  void initState() {
    super.initState();
    _model = widget.createViewModel();
  }

  @override
  void dispose() {
    _model.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _successMessage = null);
    await _model.submit(email: _email.text, password: _password.text);
  }

  Future<void> _openRegister() async {
    if (_registerOpen || _model.state.status == AuthFormStatus.submitting) {
      return;
    }
    setState(() => _registerOpen = true);
    final email = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: widget.registerScreenBuilder));
    if (!mounted) return;
    if (email != null) {
      _email.text = email;
      _password.clear();
      _model.reset();
    }
    setState(() {
      _registerOpen = false;
      if (email != null) {
        _successMessage = 'Đăng ký thành công. Vui lòng đăng nhập.';
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) {
      final state = _model.state;
      final busy = state.status == AuthFormStatus.submitting;
      return AuthPage(
        title: 'Đăng nhập',
        subtitle: 'Chào mừng bạn trở lại với OmniPlay.',
        children: [
          if (widget.notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(widget.notice!, textAlign: TextAlign.center),
              ),
            ),
          if (_successMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(_successMessage!, textAlign: TextAlign.center),
              ),
            ),
          TextField(
            key: const Key('login.email'),
            controller: _email,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: InputDecoration(
              labelText: 'Email',
              errorText: state.fieldErrors['email'],
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          PasswordInput(
            fieldKey: const Key('login.password'),
            controller: _password,
            label: 'Mật khẩu',
            enabled: !busy,
            error: state.fieldErrors['password'],
            onSubmitted: busy ? null : _submit,
          ),
          const SizedBox(height: 20),
          AuthFeedback(state: state),
          FilledButton(
            key: const Key('login.submit'),
            onPressed: busy ? null : _submit,
            child: Text(busy ? 'Đang đăng nhập…' : 'Đăng nhập'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: busy || _registerOpen ? null : _openRegister,
            child: const Text('Tạo tài khoản'),
          ),
        ],
      );
    },
  );
}
