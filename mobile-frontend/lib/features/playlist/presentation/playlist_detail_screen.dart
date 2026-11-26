import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../catalog/models/content_type.dart';
import '../../catalog/presentation/catalog_message.dart';
import '../data/playlist_repository.dart';
import '../models/playlist.dart';

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.repository,
    required this.playlistId,
    required this.onOpenMusic,
  });

  final PlaylistRepository repository;
  final String playlistId;
  final void Function(String mediaId, ContentType type) onOpenMusic;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  PlaylistDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_detail?.name ?? 'Chi tiết playlist')),
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
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _detail!.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _detail!.items[index];
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
                              style: TextStyle(color: theme.colorScheme.error),
                            )
                          : null,
                      onTap: item.available
                          ? () => widget.onOpenMusic(
                              item.mediaId,
                              ContentType.music,
                            )
                          : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
