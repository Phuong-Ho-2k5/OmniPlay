import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../data/playlist_repository.dart';
import '../models/cleanup_suggestion.dart';
import 'cleanup_suggestions_view_model.dart';

class CleanupSuggestionsScreen extends StatefulWidget {
  const CleanupSuggestionsScreen({
    super.key,
    required this.repository,
    this.playlistNames = const {},
    this.onChanged,
  });

  final PlaylistRepository repository;
  final Map<String, String> playlistNames;
  final VoidCallback? onChanged;

  @override
  State<CleanupSuggestionsScreen> createState() =>
      _CleanupSuggestionsScreenState();
}

class _CleanupSuggestionsScreenState extends State<CleanupSuggestionsScreen> {
  late final CleanupSuggestionsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = CleanupSuggestionsViewModel(
      widget.repository,
      onChanged: widget.onChanged,
    );
    unawaited(_viewModel.load());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _handleAction(
    CleanupSuggestionItem item,
    CleanupAction action,
  ) async {
    if (action == CleanupAction.remove) {
      final playlistName = widget.playlistNames[item.playlistId];
      final targetDesc = playlistName != null
          ? 'playlist "$playlistName"'
          : 'playlist này';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Gỡ bài khỏi playlist?'),
          content: Text(
            'Bạn có chắc muốn gỡ "${item.title}" khỏi $targetDesc? Nhạc gốc trong kho vẫn được giữ nguyên.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Gỡ khỏi playlist'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final ok = await _viewModel.applyAction(item, action);
    if (!mounted || !ok) return;
    final feedback = _viewModel.state.feedbackMessage;
    if (feedback != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(feedback)));
      _viewModel.clearFeedback();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dọn playlist'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_viewModel.load()),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            final state = _viewModel.state;
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
                            : Icons.check_circle_outline,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.message ?? 'Không có bài nhạc nào cần dọn lúc này. Gợi ý sẽ xuất hiện khi một bài trong playlist bị bỏ qua từ 6 lần trở lên.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (state.message != null)
                        FilledButton(
                          onPressed: () => unawaited(_viewModel.load()),
                          child: const Text('Thử lại'),
                        ),
                    ],
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.loading) const LinearProgressIndicator(),
                if (state.actionError != null) ...[
                  MaterialBanner(
                    content: Text(state.actionError!),
                    actions: [
                      TextButton(
                        onPressed: _viewModel.clearActionError,
                        child: const Text('Đóng'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Bạn luôn là người quyết định. Gợi ý xuất hiện khi bài nhạc bị bỏ qua hợp lệ từ 6 lần trở lên trong cùng playlist; OmniPlay không tự gỡ bài.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in state.items) ...[
                  _CleanupItemCard(
                    item: item,
                    playlistName: widget.playlistNames[item.playlistId],
                    busy: state.isBusy(item.playlistItemId),
                    onAction: (action) =>
                        unawaited(_handleAction(item, action)),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CleanupItemCard extends StatelessWidget {
  const _CleanupItemCard({
    required this.item,
    required this.playlistName,
    required this.busy,
    required this.onAction,
  });

  final CleanupSuggestionItem item;
  final String? playlistName;
  final bool busy;
  final void Function(CleanupAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      ?playlistName,
      '${item.skipCount} lần bỏ qua',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleParts.join(' • '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: busy ? null : () => onAction(CleanupAction.keep),
                  child: const Text('Giữ bài'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => onAction(CleanupAction.dismiss),
                  child: const Text('Bỏ qua'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: busy ? null : () => onAction(CleanupAction.remove),
                  child: const Text('Gỡ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
