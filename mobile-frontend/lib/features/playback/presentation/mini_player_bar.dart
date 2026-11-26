import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/listening_session.dart';
import 'player_coordinator.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({
    super.key,
    required this.coordinator,
    required this.onOpenDetail,
  });

  final PlayerCoordinator coordinator;
  final void Function(String mediaId, ListeningSessionType type) onOpenDetail;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: coordinator,
    builder: (context, _) {
      if (!coordinator.hasAnySession && coordinator.activeType == null) {
        return const SizedBox.shrink();
      }
      final theme = Theme.of(context);
      final activeType = coordinator.activeType ?? ListeningSessionType.music;
      final snap = coordinator.activeSession;
      final mediaId = snap?.mediaId;
      final title =
          snap?.title ?? (mediaId != null ? 'Đang tải…' : 'Chưa có nội dung');

      return Material(
        elevation: 6,
        color: theme.colorScheme.surfaceContainerHighest,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Nhạc'),
                      selected: activeType == ListeningSessionType.music,
                      onSelected: (_) => unawaited(
                        coordinator.switchSession(ListeningSessionType.music),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Podcast'),
                      selected: activeType == ListeningSessionType.podcast,
                      onSelected: (_) => unawaited(
                        coordinator.switchSession(ListeningSessionType.podcast),
                      ),
                    ),
                    const Spacer(),
                    if (coordinator.duration > Duration.zero && mediaId != null)
                      Text(
                        '${_format(coordinator.position)} / ${_format(coordinator.duration)}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: mediaId != null && !coordinator.unavailable
                            ? () => onOpenDetail(mediaId, activeType)
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            if (coordinator.errorMessage != null)
                              Text(
                                coordinator.errorMessage!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              )
                            else if (coordinator.resumedFrom != null &&
                                !coordinator.playing)
                              Text(
                                'Tạm dừng tại ${_format(coordinator.resumedFrom!)} · Nhấn Phát để tiếp tục',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (coordinator.hasMusicQueue)
                      IconButton(
                        tooltip: 'Bài trước',
                        icon: const Icon(Icons.skip_previous),
                        onPressed: coordinator.hasPrevious
                            ? () => unawaited(coordinator.previousTrack())
                            : null,
                      ),
                    if (coordinator.loading || coordinator.buffering)
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (mediaId != null && !coordinator.unavailable)
                      IconButton.filled(
                        tooltip: coordinator.playing ? 'Tạm dừng' : 'Phát',
                        icon: Icon(
                          coordinator.playing ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed: () =>
                            unawaited(coordinator.togglePlayPause()),
                      ),
                    if (coordinator.hasMusicQueue)
                      IconButton(
                        tooltip: 'Bài tiếp theo',
                        icon: const Icon(Icons.skip_next),
                        onPressed: coordinator.hasNext
                            ? () => unawaited(coordinator.nextTrack())
                            : null,
                      ),
                  ],
                ),
              ],
            ),
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
