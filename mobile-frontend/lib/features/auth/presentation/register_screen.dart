import 'package:material_ui/material_ui.dart';

import 'auth_form_state.dart';
import 'auth_form_widgets.dart';
import 'register_view_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.createViewModel});
  final RegisterViewModel Function() createViewModel;
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final RegisterViewModel _model;
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController();
  @override
  void initState() {
    super.initState();
    _model = widget.createViewModel();
  }

  @override
  void dispose() {
    _model.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await _model.submit(
      email: _email.text,
      password: _password.text,
      displayName: _name.text,
      confirmPassword: _confirmation.text,
    );
    if (!mounted || _model.state.status != AuthFormStatus.success) return;
    Navigator.of(context).pop(_model.registeredUser!.email);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) {
      final state = _model.state;
      final busy = state.status == AuthFormStatus.submitting;
      return PopScope(
        canPop: !busy,
        child: AuthPage(
          title: 'Đăng ký',
          subtitle: 'Tạo tài khoản để bắt đầu khám phá.',
          children: [
            TextField(
              key: const Key('register.displayName'),
              controller: _name,
              enabled: !busy,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.nickname],
              decoration: InputDecoration(
                labelText: 'Tên hiển thị',
                errorText: state.fieldErrors['displayName'],
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('register.email'),
              controller: _email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: state.fieldErrors['email'],
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            PasswordInput(
              fieldKey: const Key('register.password'),
              controller: _password,
              label: 'Mật khẩu',
              enabled: !busy,
              error: state.fieldErrors['password'],
              newPassword: true,
              next: true,
            ),
            const SizedBox(height: 16),
            PasswordInput(
              fieldKey: const Key('register.confirmPassword'),
              controller: _confirmation,
              label: 'Xác nhận mật khẩu',
              enabled: !busy,
              error: state.fieldErrors['confirmPassword'],
              newPassword: true,
              onSubmitted: busy ? null : _submit,
            ),
            const SizedBox(height: 20),
            AuthFeedback(state: state),
            FilledButton(
              key: const Key('register.submit'),
              onPressed: busy ? null : _submit,
              child: Text(busy ? 'Đang đăng ký…' : 'Đăng ký'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Quay lại đăng nhập'),
            ),
          ],
        ),
      );
    },
  );
}
