import 'package:flutter/material.dart';

import 'connection_state.dart' as connection;
import 'connection_view_model.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key, required this.viewModel});
  final ConnectionViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('OmniPlay')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) {
                final state = viewModel.state;
                final loading =
                    state.status == connection.ConnectionStatus.loading;
                final failed =
                    state.status == connection.ConnectionStatus.error;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Kiểm tra kết nối',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kiểm tra kết nối đến dịch vụ OmniPlay.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (loading) const CircularProgressIndicator(),
                    if (state.status == connection.ConnectionStatus.success)
                      Semantics(
                        liveRegion: true,
                        child: const Text('Kết nối thành công'),
                      ),
                    if (failed)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          state.message!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: loading ? null : viewModel.checkConnection,
                      child: Text(
                        failed
                            ? 'Thử lại'
                            : loading
                            ? 'Đang kiểm tra…'
                            : 'Kiểm tra',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
