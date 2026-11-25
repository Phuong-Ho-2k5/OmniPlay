import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/listening_session.dart';
import 'player_coordinator.dart';

class CoordinatedAudioPlayerWidget extends StatefulWidget {
  const CoordinatedAudioPlayerWidget({
    super.key,
    required this.coordinator,
    required this.mediaId,
    required this.sessionType,
    required this.title,
  });

  final PlayerCoordinator coordinator;
  final String mediaId;
  final ListeningSessionType sessionType;
  final String title;

  @override
  State<CoordinatedAudioPlayerWidget> createState() =>
      _CoordinatedAudioPlayerWidgetState();
}

class _CoordinatedAudioPlayerWidgetState
    extends State<CoordinatedAudioPlayerWidget> {
  double? _draggingSeconds;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.coordinator.openAudio(
        mediaId: widget.mediaId,
        type: widget.sessionType,
        title: widget.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.coordinator,
    builder: (context, _) {
      final c = widget.coordinator;
      final theme = Theme.of(context);
      final isThis = c.isCurrentMedia(widget.mediaId, widget.sessionType);
      final totalSeconds = isThis ? c.duration.inMilliseconds / 1000.0 : 0.0;
      final currentSeconds =
          _draggingSeconds ??
          (isThis ? c.position.inMilliseconds / 1000.0 : 0.0).clamp(
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
              if (isThis && c.loading) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ] else if (isThis && c.errorMessage != null) ...[
                Row(
                  children: [
                    Icon(
                      c.unavailable
                          ? Icons.error_outline
                          : Icons.wifi_off_outlined,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c.errorMessage!)),
                  ],
                ),
                if (!c.unavailable) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () => unawaited(c.retryCurrent()),
                      child: const Text('Thử lại'),
                    ),
                  ),
                ],
              ] else if (isThis && c.ready) ...[
                Row(
                  children: [
                    IconButton.filled(
                      tooltip: c.playing ? 'Tạm dừng' : 'Phát',
                      icon: Icon(c.playing ? Icons.pause : Icons.play_arrow),
                      onPressed: () => unawaited(c.togglePlayPause()),
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
                                      c.seek(
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
                                if (c.buffering)
                                  Text(
                                    'Đang đệm…',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                Text(
                                  _format(c.duration),
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
                      'Đã phát thực tế: ${c.coveragePercent}%',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (c.resumedFrom != null && !c.playing)
                      Text(
                        'Tiếp tục từ ${_format(c.resumedFrom!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    if (c.completed)
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
                if (c.syncError != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.sync_problem_outlined,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.syncError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => unawaited(c.retrySync()),
                        child: const Text('Thử đồng bộ lại'),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Mở trong trình phát'),
                    onPressed: () => unawaited(
                      c.openAudio(
                        mediaId: widget.mediaId,
                        type: widget.sessionType,
                        title: widget.title,
                      ),
                    ),
                  ),
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
