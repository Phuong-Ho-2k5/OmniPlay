import 'package:material_ui/material_ui.dart';

import '../../../app/app_dependencies.dart';
import '../../connection/presentation/connection_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: dependencies.sessionStore,
    builder: (context, _) => dependencies.sessionStore.tokens == null
        ? LoginScreen(
            createViewModel: dependencies.createLoginViewModel,
            registerScreenBuilder: (_) => RegisterScreen(
              createViewModel: dependencies.createRegisterViewModel,
            ),
          )
        : ConnectionScreen(
            viewModel: dependencies.connectionViewModel,
            notice: 'Đăng nhập thành công',
          ),
  );
}
