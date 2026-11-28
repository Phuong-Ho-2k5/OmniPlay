import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../catalog/data/catalog_repository.dart';
import '../../catalog/models/content_type.dart';
import '../../catalog/presentation/catalog_thumbnail.dart';
import '../models/mystery_box.dart';
import 'mystery_box_view_model.dart';

class MysteryBoxResultScreen extends StatelessWidget {
  const MysteryBoxResultScreen({
    super.key,
    required this.viewModel,
    required this.catalogRepository,
    required this.onOpenItem,
  });

  final MysteryBoxViewModel viewModel;
  final CatalogRepository catalogRepository;
  final void Function(String id, ContentType type) onOpenItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Dành cho bạn')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final state = viewModel.state;
            final media = state.media;
            final result = state.resultType;

            if (state.errorMessage != null && media == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 48),
                      const SizedBox(height: 16),
                      Text(state.errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: state.drawing
                            ? null
                            : () => unawaited(
                                viewModel.draw(excludeCurrent: false),
                              ),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (result == MysteryBoxResultType.empty || media == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có nội dung phù hợp',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Không có Video, Nhạc hoặc Podcast khả dụng nào khớp với tất cả bộ lọc bạn đã chọn. Hãy nới bộ lọc để thử lại.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Chỉnh bộ lọc'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final isNoAlternative =
                result == MysteryBoxResultType.noAlternative;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.drawing) const LinearProgressIndicator(),
                if (state.errorMessage != null) ...[
                  MaterialBanner(
                    content: Text(state.errorMessage!),
                    actions: [
                      TextButton(
                        onPressed: state.drawing
                            ? null
                            : () => unawaited(
                                viewModel.draw(excludeCurrent: true),
                              ),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (state.saveError != null) ...[
                  MaterialBanner(
                    content: Text(state.saveError!),
                    actions: [
                      TextButton(
                        onPressed: viewModel.clearSaveError,
                        child: const Text('Đóng'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (isNoAlternative) ...[
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Không còn lựa chọn khác khớp bộ lọc hiện tại. Bạn có thể phát nội dung này hoặc chỉnh lại bộ lọc.',
                              style: TextStyle(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CatalogThumbnail(
                        repository: catalogRepository,
                        path: media.thumbnailUrl,
                        type: media.type,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Chip(
                                  label: Text(media.type.label),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (media.durationLabel != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    media.durationLabel!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                                const Spacer(),
                                IconButton(
                                  tooltip: media.saved
                                      ? 'Bỏ lưu'
                                      : 'Lưu nội dung',
                                  onPressed: state.saving
                                      ? null
                                      : () =>
                                            unawaited(viewModel.toggleSaved()),
                                  icon: state.saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          media.saved
                                              ? Icons.bookmark
                                              : Icons.bookmark_border,
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              media.title,
                              style: theme.textTheme.titleLarge,
                            ),
                            if (media.description != null &&
                                media.description!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(media.description!),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => onOpenItem(media.id, media.type),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      isNoAlternative ? 'Phát nội dung này' : 'Phát ngay',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (!isNoAlternative) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: state.drawing
                          ? null
                          : () =>
                                unawaited(viewModel.draw(excludeCurrent: true)),
                      icon: const Icon(Icons.casino_outlined),
                      label: Text(
                        state.drawing ? 'Đang mở hộp khác...' : 'Mở hộp khác',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Chỉnh bộ lọc'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
