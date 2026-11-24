import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../catalog/models/content_type.dart';
import 'media_player_view_model.dart';

class MediaPlayerWidget extends StatefulWidget {
  const MediaPlayerWidget({super.key, required this.createViewModel});

  final MediaPlayerViewModel Function() createViewModel;

  @override
  State<MediaPlayerWidget> createState() => _MediaPlayerWidgetState();
}

class _MediaPlayerWidgetState extends State<MediaPlayerWidget> {
  late final MediaPlayerViewModel _viewModel;
  double? _draggingSeconds;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.createViewModel();
    unawaited(_viewModel.load());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _viewModel,
    builder: (context, _) {
      final state = _viewModel.state;
      final theme = Theme.of(context);
      final totalSeconds = state.duration.inMilliseconds / 1000.0;
      final currentSeconds =
          _draggingSeconds ??
          (state.position.inMilliseconds / 1000.0).clamp(
            0.0,
            totalSeconds > 0 ? totalSeconds : 0.0,
          );

      return Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_viewModel.type == ContentType.video &&
                  state.ready &&
                  _viewModel.videoController != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio:
                        _viewModel.videoController!.value.aspectRatio > 0
                        ? _viewModel.videoController!.value.aspectRatio
                        : 16 / 9,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_viewModel.videoController!),
                        if (state.buffering) const CircularProgressIndicator(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (state.loading) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ] else if (state.message != null) ...[
                Row(
                  children: [
                    Icon(
                      state.unavailable || state.fileMissing
                          ? Icons.error_outline
                          : Icons.wifi_off_outlined,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(state.message!)),
                  ],
                ),
                if (!state.unavailable) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () => unawaited(_viewModel.retry()),
                      child: const Text('Thử lại'),
                    ),
                  ),
                ],
              ] else if (state.ready) ...[
                Row(
                  children: [
                    IconButton.filled(
                      tooltip: state.playing ? 'Tạm dừng' : 'Phát',
                      icon: Icon(
                        state.playing ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: () => unawaited(_viewModel.togglePlayPause()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Slider(
                            min: 0,
                            max: totalSeconds > 0 ? totalSeconds : 1,
                            value: totalSeconds > 0
                                ? currentSeconds.clamp(0.0, totalSeconds)
                                : 0,
                            onChanged: totalSeconds > 0
                                ? (v) => setState(() => _draggingSeconds = v)
                                : null,
                            onChangeEnd: totalSeconds > 0
                                ? (v) {
                                    setState(() => _draggingSeconds = null);
                                    unawaited(
                                      _viewModel.seek(
                                        Duration(
                                          milliseconds: (v * 1000).round(),
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _format(
                                    Duration(
                                      milliseconds: (currentSeconds * 1000)
                                          .round(),
                                    ),
                                  ),
                                  style: theme.textTheme.bodySmall,
                                ),
                                if (state.buffering)
                                  Text(
                                    'Đang đệm…',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                Text(
                                  _format(state.duration),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đã phát thực tế: ${state.coveragePercent}%',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (state.completed)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Hoàn thành',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  String _format(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final mins = (total ~/ 60).toString().padLeft(2, '0');
    final secs = (total % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
