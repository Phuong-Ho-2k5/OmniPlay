import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_exception.dart';
import '../../catalog/presentation/catalog_message.dart';
import '../models/playlist.dart';
import 'playlists_view_model.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({
    super.key,
    required this.viewModel,
    required this.onOpenPlaylist,
    required this.onLogout,
  });

  final PlaylistsViewModel viewModel;
  final void Function(String playlistId) onOpenPlaylist;
  final VoidCallback onLogout;

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  static const Uuid _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.loadInitial());
  }

  Future<void> _showCreateDialog() async {
    // Generated once per create dialog; preserved across network retries (idempotent POST).
    final requestId = _uuid.v4();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PlaylistNameDialog(
        title: 'Tạo playlist mới',
        confirmLabel: 'Tạo',
        onSubmit: (name) =>
            widget.viewModel.createPlaylist(name: name, requestId: requestId),
      ),
    );
  }

  Future<void> _showRenameDialog(PlaylistSummary playlist) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PlaylistNameDialog(
        title: 'Đổi tên playlist',
        initialName: playlist.name,
        confirmLabel: 'Lưu',
        onSubmit: (name) =>
            widget.viewModel.renamePlaylist(id: playlist.id, name: name),
      ),
    );
  }

  Future<void> _confirmDelete(PlaylistSummary playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa playlist?'),
        content: Text(
          'Bạn có chắc muốn xóa playlist "${playlist.name}"? Các bài nhạc gốc trong kho vẫn được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.viewModel.deletePlaylist(playlist.id);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Playlist'),
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
          onPressed: () => unawaited(widget.viewModel.refresh()),
        ),
        IconButton(
          tooltip: 'Đăng xuất',
          icon: const Icon(Icons.logout),
          onPressed: widget.onLogout,
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => unawaited(_showCreateDialog()),
      icon: const Icon(Icons.add),
      label: const Text('Tạo playlist'),
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final state = widget.viewModel.state;
          if (state.loading && state.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.message != null
                          ? Icons.cloud_off_outlined
                          : Icons.queue_music,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message ?? 'Bạn chưa có playlist nào.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    if (state.message != null)
                      FilledButton(
                        onPressed: () =>
                            unawaited(widget.viewModel.loadInitial()),
                        child: const Text('Thử lại'),
                      ),
                  ],
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              if (state.loading)
                const SliverToBoxAdapter(child: LinearProgressIndicator()),
              if (state.actionError != null)
                SliverToBoxAdapter(
                  child: MaterialBanner(
                    content: Text(state.actionError!),
                    actions: [
                      TextButton(
                        onPressed: widget.viewModel.clearActionError,
                        child: const Text('Đóng'),
                      ),
                    ],
                  ),
                ),
              if (state.message != null)
                SliverToBoxAdapter(
                  child: ListTile(
                    title: Text(state.message!),
                    trailing: TextButton(
                      onPressed: () => unawaited(widget.viewModel.refresh()),
                      child: const Text('Thử lại'),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                sliver: SliverList.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final playlist = state.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.queue_music),
                          title: Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('${playlist.itemCount} bài nhạc'),
                          onTap: () => widget.onOpenPlaylist(playlist.id),
                          trailing: PopupMenuButton<_PlaylistMenuAction>(
                            onSelected: (action) {
                              if (action == _PlaylistMenuAction.rename) {
                                unawaited(_showRenameDialog(playlist));
                              } else {
                                unawaited(_confirmDelete(playlist));
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: _PlaylistMenuAction.rename,
                                child: Text('Đổi tên'),
                              ),
                              PopupMenuItem(
                                value: _PlaylistMenuAction.delete,
                                child: Text('Xóa'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (state.moreMessage != null)
                        Text(state.moreMessage!, textAlign: TextAlign.center),
                      if (state.loadingMore)
                        const CircularProgressIndicator()
                      else if (state.canLoadMore)
                        OutlinedButton(
                          onPressed: () =>
                              unawaited(widget.viewModel.loadMore()),
                          child: Text(
                            state.moreMessage == null ? 'Tải thêm' : 'Thử lại',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

enum _PlaylistMenuAction { rename, delete }

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.onSubmit,
    this.initialName = '',
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final Future<Object?> Function(String trimmedName) onSubmit;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _controller;
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty || trimmed.runes.length > 120) {
      setState(() => _errorText = 'Tên playlist phải có từ 1 đến 120 ký tự.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await widget.onSubmit(trimmed);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      final fieldMsg = error is ApiException ? error.fieldErrors['name'] : null;
      setState(() {
        _submitting = false;
        _errorText = fieldMsg ?? catalogErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      enabled: !_submitting,
      maxLength: 120,
      decoration: InputDecoration(
        labelText: 'Tên playlist',
        errorText: _errorText,
      ),
      onSubmitted: (_) => unawaited(_submit()),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _submitting ? null : () => unawaited(_submit()),
        child: _submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(widget.confirmLabel),
      ),
    ],
  );
}
