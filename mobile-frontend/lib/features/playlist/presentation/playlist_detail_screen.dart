import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../catalog/presentation/catalog_message.dart';
import '../../playback/presentation/player_coordinator.dart';
import '../data/playlist_repository.dart';
import '../models/playlist.dart';

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.repository,
    required this.playlistId,
    required this.playerCoordinator,
    this.onChanged,
  });

  final PlaylistRepository repository;
  final String playlistId;
  final PlayerCoordinator playerCoordinator;
  final VoidCallback? onChanged;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  PlaylistDetail? _detail;
  bool _loading = true;
  String? _error;
  String? _actionError;
  final Set<String> _removingMediaIds = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _actionError = null;
    });
    try {
      final detail = await widget.repository.detail(widget.playlistId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = catalogErrorMessage(error);
        _loading = false;
      });
    }
  }

  List<MusicQueueTrack> _availableTracks() {
    final detail = _detail;
    if (detail == null) return const [];
    return [
      for (final item in detail.items)
        if (item.available)
          MusicQueueTrack(
            mediaId: item.mediaId,
            title: item.title,
            playlistItemId: item.playlistItemId,
          ),
    ];
  }

  Future<void> _playFrom({String? mediaId}) async {
    final tracks = _availableTracks();
    if (tracks.isEmpty) return;
    final startIdx = mediaId == null
        ? 0
        : tracks.indexWhere((t) => t.mediaId == mediaId);
    await widget.playerCoordinator.playMusicQueue(
      tracks: tracks,
      startIndex: startIdx < 0 ? 0 : startIdx,
      autoPlay: true,
    );
  }

  Future<void> _removeItem(PlaylistItemSummary item) async {
    if (_removingMediaIds.contains(item.mediaId)) return;
    setState(() {
      _removingMediaIds.add(item.mediaId);
      _actionError = null;
    });
    try {
      await widget.repository.removeItem(
        playlistId: widget.playlistId,
        mediaId: item.mediaId,
      );
      if (!mounted) return;
      final current = _detail;
      if (current != null) {
        setState(() {
          _detail = PlaylistDetail(
            id: current.id,
            name: current.name,
            items: current.items
                .where((e) => e.mediaId != item.mediaId)
                .toList(),
          );
        });
      }
      widget.onChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionError = catalogErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _removingMediaIds.remove(item.mediaId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableCount = _availableTracks().length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_detail?.name ?? 'Chi tiết playlist'),
        actions: [
          if (availableCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: () => unawaited(_playFrom()),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Phát'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading && _detail == null
            ? const Center(child: CircularProgressIndicator())
            : _detail == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        _error ?? 'Không thể tải playlist.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => unawaited(_load()),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            : _detail!.items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_note_outlined, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Playlist chưa có bài nhạc nào.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  if (_actionError != null)
                    MaterialBanner(
                      content: Text(_actionError!),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => _actionError = null),
                          child: const Text('Đóng'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _detail!.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _detail!.items[index];
                        final removing = _removingMediaIds.contains(
                          item.mediaId,
                        );
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: !item.available
                                ? Text(
                                    'Ngừng phục vụ',
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  )
                                : null,
                            onTap: item.available
                                ? () => unawaited(
                                    _playFrom(mediaId: item.mediaId),
                                  )
                                : null,
                            trailing: IconButton(
                              tooltip: 'Gỡ khỏi playlist',
                              onPressed: removing
                                  ? null
                                  : () => unawaited(_removeItem(item)),
                              icon: removing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.remove_circle_outline),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
