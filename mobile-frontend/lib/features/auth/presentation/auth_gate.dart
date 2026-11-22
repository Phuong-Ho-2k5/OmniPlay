import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../app/app_dependencies.dart';
import '../data/auth_session_controller.dart';
import '../data/secure_token_store.dart';
import '../../connection/presentation/connection_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: dependencies.sessionStore,
    builder: (context, _) {
      final sessions = dependencies.sessionStore;
      if (sessions.phase == AuthSessionPhase.restoring) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (sessions.phase == AuthSessionPhase.storageError) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sessions.notice ?? 'Không thể mở phiên đã lưu.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await sessions.retryStorage();
                        } on SessionStorageException {
                          /* State displays the error. */
                        }
                      },
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return sessions.tokens == null
          ? LoginScreen(
              notice: sessions.notice,
              createViewModel: dependencies.createLoginViewModel,
              registerScreenBuilder: (_) => RegisterScreen(
                createViewModel: dependencies.createRegisterViewModel,
              ),
            )
          : ConnectionScreen(
              viewModel: dependencies.connectionViewModel,
              notice: 'Đã đăng nhập',
              onLogout: () => unawaited(sessions.logout()),
            );
    },
  );
}
