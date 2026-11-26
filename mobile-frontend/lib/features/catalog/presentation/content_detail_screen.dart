import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../playback/models/listening_session.dart';
import '../../playback/presentation/coordinated_audio_player_widget.dart';
import '../../playback/presentation/media_player_view_model.dart';
import '../../playback/presentation/media_player_widget.dart';
import '../../playback/presentation/player_coordinator.dart';
import '../../playlist/data/playlist_repository.dart';
import '../../saved/data/saved_repository.dart';
import '../data/catalog_repository.dart';
import '../models/content_type.dart';
import '../models/genre.dart';
import 'catalog_message.dart';
import 'catalog_thumbnail.dart';
import 'content_detail_view_model.dart';

class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen({
    super.key,
    required this.repository,
    required this.id,
    required this.type,
    required this.genres,
    this.savedRepository,
    this.onSavedChanged,
    this.playlistRepository,
    this.onPlaylistsChanged,
    this.createPlayerViewModel,
    this.playerCoordinator,
  });
  final CatalogRepository repository;
  final String id;
  final ContentType type;
  final List<Genre> genres;
  final SavedRepository? savedRepository;
  final VoidCallback? onSavedChanged;
  final PlaylistRepository? playlistRepository;
  final VoidCallback? onPlaylistsChanged;
  final MediaPlayerViewModel Function({
    required String mediaId,
    required ContentType type,
    Future<void> Function()? onBeforeVideoPlay,
  })?
  createPlayerViewModel;
  final PlayerCoordinator? playerCoordinator;
  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  late final ContentDetailViewModel _viewModel;
  MediaPlayerViewModel? _activePlayer;
  bool _exiting = false;
  @override
  void initState() {
    super.initState();
    _viewModel = ContentDetailViewModel(
      widget.repository,
      savedRepository: widget.savedRepository,
    );
    unawaited(_reload());
  }

  Future<void> _reload() => _viewModel.load(id: widget.id, type: widget.type);

  Future<void> _toggleSaved() async {
    final result = await _viewModel.toggleSaved();
    if (result != null) {
      widget.onSavedChanged?.call();
    }
  }

  Future<void> _showAddToPlaylistSheet() async {
    final repo = widget.playlistRepository;
    if (repo == null) return;
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => _PickPlaylistSheet(repository: repo),
    );
    if (selectedId == null || !mounted) return;
    try {
      await repo.addItem(playlistId: selectedId, mediaId: widget.id);
      if (!mounted) return;
      widget.onPlaylistsChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm bài nhạc vào playlist.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(catalogErrorMessage(error))));
    }
  }

  Future<void> _handleExit() async {
    if (_exiting) return;
    _exiting = true;
    await _activePlayer?.stopAndFlush();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      unawaited(_handleExit());
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.type == ContentType.post ? 'Bài viết' : 'Chi tiết nội dung',
        ),
        actions: [
          if (widget.type == ContentType.music &&
              widget.playlistRepository != null)
            IconButton(
              tooltip: 'Thêm vào playlist',
              icon: const Icon(Icons.playlist_add),
              onPressed: () => unawaited(_showAddToPlaylistSheet()),
            ),
          if (widget.savedRepository != null)
            ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) {
                final detail = _viewModel.state.detail;
                if (detail == null) return const SizedBox.shrink();
                final saved = detail.summary.saved;
                final saving = _viewModel.state.saving;
                return IconButton(
                  tooltip: saved ? 'Bỏ lưu' : 'Lưu nội dung',
                  onPressed: saving ? null : () => unawaited(_toggleSaved()),
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            final state = _viewModel.state;
            final detail = state.detail;
            if (state.loading && detail == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (detail == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.unavailable
                            ? Icons.hide_source
                            : Icons.cloud_off_outlined,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.message ?? 'Không thể tải nội dung.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (!state.unavailable)
                        FilledButton(
                          onPressed: _reload,
                          child: const Text('Thử lại'),
                        ),
                      TextButton(
                        onPressed: () => unawaited(_handleExit()),
                        child: const Text('Quay lại danh sách'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final item = detail.summary;
            final names = widget.genres
                .where((genre) => item.genreIds.contains(genre.id))
                .map((g) => g.name)
                .toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.type != ContentType.post) ...[
                        if (item.type != ContentType.video ||
                            widget.createPlayerViewModel == null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CatalogThumbnail(
                              repository: widget.repository,
                              path: item.thumbnailUrl,
                              type: item.type,
                              height: 230,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (item.type != ContentType.video &&
                            widget.playerCoordinator != null) ...[
                          CoordinatedAudioPlayerWidget(
                            key: ValueKey(
                              'audio:${item.type.apiValue}:${item.id}',
                            ),
                            coordinator: widget.playerCoordinator!,
                            mediaId: item.id,
                            sessionType: ListeningSessionType.fromContentType(
                              item.type,
                            )!,
                            title: item.title,
                          ),
                          const SizedBox(height: 20),
                        ] else if (widget.createPlayerViewModel != null) ...[
                          MediaPlayerWidget(
                            key: ValueKey(
                              'player:${item.type.apiValue}:${item.id}',
                            ),
                            createViewModel: () =>
                                widget.createPlayerViewModel!(
                                  mediaId: item.id,
                                  type: item.type,
                                  onBeforeVideoPlay: widget
                                      .playerCoordinator
                                      ?.notifyVideoStarted,
                                ),
                            onViewModelChanged: (vm) => _activePlayer = vm,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      if (state.saveError != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            state.saveError!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(item.type.label)),
                          if (item.durationLabel != null)
                            Chip(label: Text(item.durationLabel!)),
                          if (item.saved)
                            const Chip(
                              avatar: Icon(Icons.bookmark, size: 18),
                              label: Text('Đã lưu'),
                            ),
                          for (final name in names) Chip(label: Text(name)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (item.type == ContentType.post)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(
                              detail.content ??
                                  item.description ??
                                  'Chưa có nội dung bài viết.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(height: 1.6),
                            ),
                          ),
                        )
                      else
                        SelectableText(
                          detail.content ??
                              item.description ??
                              'Chưa có mô tả.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _PickPlaylistSheet extends StatefulWidget {
  const _PickPlaylistSheet({required this.repository});

  final PlaylistRepository repository;

  @override
  State<_PickPlaylistSheet> createState() => _PickPlaylistSheetState();
}

class _PickPlaylistSheetState extends State<_PickPlaylistSheet> {
  bool _loading = true;
  String? _error;
  List<({String id, String name, int count})> _playlists = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final page = await widget.repository.list(page: 0, size: 50);
      if (!mounted) return;
      setState(() {
        _playlists = [
          for (final p in page.items)
            (id: p.id, name: p.name, count: p.itemCount),
        ];
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
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Chọn playlist', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, textAlign: TextAlign.center)
          else if (_playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Bạn chưa có playlist nào. Hãy tạo playlist ở tab Playlist trước.',
                textAlign: TextAlign.center,
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _playlists.length,
                itemBuilder: (context, index) {
                  final p = _playlists[index];
                  return ListTile(
                    leading: const Icon(Icons.queue_music),
                    title: Text(p.name),
                    subtitle: Text('${p.count} bài nhạc'),
                    onTap: () => Navigator.of(context).pop(p.id),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}
