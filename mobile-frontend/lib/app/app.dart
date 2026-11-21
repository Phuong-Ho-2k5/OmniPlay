import 'package:material_ui/material_ui.dart';

import '../features/auth/presentation/auth_gate.dart';
import 'app_dependencies.dart';

class OmniPlayApp extends StatefulWidget {
  const OmniPlayApp({super.key, required this.dependencies});
  final AppDependencies dependencies;

  @override
  State<OmniPlayApp> createState() => _OmniPlayAppState();
}

class _OmniPlayAppState extends State<OmniPlayApp> {
  @override
  void dispose() {
    widget.dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OmniPlay',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3564E0)),
    ),
    home: AuthGate(dependencies: widget.dependencies),
  );
}
