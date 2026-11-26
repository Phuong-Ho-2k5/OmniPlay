import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../catalog/data/catalog_repository.dart';
import '../../catalog/models/content_type.dart';
import '../../catalog/presentation/catalog_thumbnail.dart';
import 'saved_view_model.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({
    super.key,
    required this.viewModel,
    required this.catalogRepository,
    required this.onOpenItem,
    required this.onLogout,
  });

  final SavedViewModel viewModel;
  final CatalogRepository catalogRepository;
  final void Function(String id, ContentType type) onOpenItem;
  final VoidCallback onLogout;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.loadInitial());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Đã lưu'),
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
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final state = widget.viewModel.state;
          final theme = Theme.of(context);

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
                          : Icons.bookmark_border,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message ?? 'Bạn chưa lưu nội dung nào.',
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
                padding: const EdgeInsets.all(12),
                sliver: SliverList.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final savedItem = state.items[index];
                    final item = savedItem.summary;
                    final key = SavedViewModel.itemKey(item.id, item.type);
                    final pending = state.pendingKeys.contains(key);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: savedItem.available
                              ? () => widget.onOpenItem(item.id, item.type)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (savedItem.available &&
                                    item.type != ContentType.post) ...[
                                  SizedBox(
                                    width: 92,
                                    height: 68,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CatalogThumbnail(
                                        repository: widget.catalogRepository,
                                        path: item.thumbnailUrl,
                                        type: item.type,
                                        height: 68,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ] else ...[
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      savedItem.available
                                          ? Icons.article_outlined
                                          : Icons.hide_source,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Chip(
                                            label: Text(item.type.label),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          if (item.durationLabel != null &&
                                              savedItem.available)
                                            Chip(
                                              label: Text(item.durationLabel!),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          if (!savedItem.available)
                                            Chip(
                                              label: const Text(
                                                'Ngừng phục vụ',
                                              ),
                                              backgroundColor: theme
                                                  .colorScheme
                                                  .errorContainer,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                        ],
                                      ),
                                      if (!savedItem.available) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Nội dung không còn khả dụng. Bạn vẫn có thể bỏ lưu khỏi danh sách.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme.colorScheme.error,
                                              ),
                                        ),
                                      ] else if (item.description != null &&
                                          item.description!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.description!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Bỏ lưu',
                                  onPressed: pending
                                      ? null
                                      : () => unawaited(
                                          widget.viewModel.unsaveItem(
                                            savedItem,
                                          ),
                                        ),
                                  icon: pending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.bookmark_remove_outlined,
                                        ),
                                ),
                              ],
                            ),
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
