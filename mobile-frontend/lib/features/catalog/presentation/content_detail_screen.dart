import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../data/catalog_repository.dart';
import '../models/content_type.dart';
import '../models/genre.dart';
import 'catalog_thumbnail.dart';
import 'content_detail_view_model.dart';

class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen({
    super.key,
    required this.repository,
    required this.id,
    required this.type,
    required this.genres,
  });
  final CatalogRepository repository;
  final String id;
  final ContentType type;
  final List<Genre> genres;
  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  late final ContentDetailViewModel _viewModel;
  @override
  void initState() {
    super.initState();
    _viewModel = ContentDetailViewModel(widget.repository);
    unawaited(_reload());
  }

  Future<void> _reload() => _viewModel.load(id: widget.id, type: widget.type);
  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.type == ContentType.post ? 'Bài viết' : 'Chi tiết nội dung',
      ),
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
                      onPressed: () => Navigator.of(context).pop(),
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CatalogThumbnail(
                          repository: widget.repository,
                          path: item.thumbnailUrl,
                          type: item.type,
                          height: 230,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
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
                    SelectableText(
                      detail.content ?? item.description ?? 'Chưa có mô tả.',
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
  );
}
