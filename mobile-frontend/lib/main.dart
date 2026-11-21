import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    OmniPlayApp(dependencies: AppDependencies(AppConfig.fromEnvironment())),
  );
}
