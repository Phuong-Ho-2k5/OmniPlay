import 'package:material_ui/material_ui.dart';

import '../data/catalog_repository.dart';
import '../models/content_summary.dart';
import 'catalog_thumbnail.dart';

class ContentCard extends StatelessWidget {
  const ContentCard({
    super.key,
    required this.item,
    required this.repository,
    required this.onTap,
  });
  final ContentSummary item;
  final CatalogRepository repository;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CatalogThumbnail(
            repository: repository,
            path: item.thumbnailUrl,
            type: item.type,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.type.label,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (item.durationLabel != null) ...[
                      const SizedBox(width: 12),
                      Text(item.durationLabel!),
                    ],
                    const Spacer(),
                    if (item.saved)
                      const Tooltip(
                        message: 'Đã lưu',
                        child: Icon(Icons.bookmark, size: 20),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.description!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
