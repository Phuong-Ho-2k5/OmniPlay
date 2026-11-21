import 'package:material_ui/material_ui.dart';

import 'auth_form_state.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title, subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('OmniPlay'),
      automaticallyImplyLeading: false,
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthFeedback extends StatelessWidget {
  const AuthFeedback({super.key, required this.state});
  final AuthFormState state;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (state.status == AuthFormStatus.submitting)
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: CircularProgressIndicator(),
        ),
      if (state.message != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              state.message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: state.status == AuthFormStatus.error
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ),
        ),
    ],
  );
}

class PasswordInput extends StatefulWidget {
  const PasswordInput({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.enabled,
    this.error,
    this.onSubmitted,
    this.newPassword = false,
    this.next = false,
  });
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final bool enabled, newPassword, next;
  final String? error;
  final VoidCallback? onSubmitted;
  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => TextField(
    key: widget.fieldKey,
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _hidden,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [
      widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
    ],
    textInputAction: widget.next ? TextInputAction.next : TextInputAction.done,
    onSubmitted: (_) => widget.onSubmitted?.call(),
    decoration: InputDecoration(
      labelText: widget.label,
      errorText: widget.error,
      errorMaxLines: 3,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        onPressed: widget.enabled
            ? () => setState(() => _hidden = !_hidden)
            : null,
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}
