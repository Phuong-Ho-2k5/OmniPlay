import '../../catalog/models/catalog_json.dart';
import '../../catalog/models/content_summary.dart';
import '../../catalog/models/content_type.dart';

class SavedContentSummary {
  const SavedContentSummary({
    required this.summary,
    required this.available,
    required this.savedAt,
  });

  final ContentSummary summary;
  final bool available;
  final DateTime savedAt;

  factory SavedContentSummary.fromJson(Map<String, dynamic> json) {
    final summary = ContentSummary.fromJson(json);
    final available = json['available'];
    if (available is! bool) invalidCatalogResponse();
    final rawSavedAt = catalogString(json['savedAt']);
    final savedAt = DateTime.tryParse(rawSavedAt)?.toUtc();
    if (savedAt == null) invalidCatalogResponse();
    return SavedContentSummary(
      summary: summary,
      available: available,
      savedAt: savedAt,
    );
  }
}

class SavedPage {
  SavedPage({
    required List<SavedContentSummary> items,
    required this.page,
    required this.size,
    required this.totalElements,
  }) : items = List.unmodifiable(items);

  final List<SavedContentSummary> items;
  final int page;
  final int size;
  final int totalElements;

  factory SavedPage.fromJson(Map<String, dynamic> json) {
    final items = catalogList(json['items'])
        .map((v) => SavedContentSummary.fromJson(catalogObject(v)))
        .toList();
    final size = catalogInt(json['size'], min: 1);
    final total = catalogInt(json['totalElements']);
    final page = catalogInt(json['page']);
    final expectedCount = (total - page * size).clamp(0, size);
    if (size > 50 || page > 2147483647 || items.length != expectedCount) {
      invalidCatalogResponse();
    }
    return SavedPage(
      items: items,
      page: page,
      size: size,
      totalElements: total,
    );
  }
}

class SavedStateResult {
  const SavedStateResult({
    required this.id,
    required this.type,
    required this.saved,
  });

  final String id;
  final ContentType type;
  final bool saved;

  factory SavedStateResult.fromJson(Map<String, dynamic> json) {
    final id = catalogId(json['id']);
    final rawType = catalogString(json['type']);
    ContentType? type;
    for (final candidate in ContentType.values) {
      if (candidate.apiValue == rawType) {
        type = candidate;
        break;
      }
    }
    if (type == null) invalidCatalogResponse();
    final saved = json['saved'];
    if (saved is! bool) invalidCatalogResponse();
    return SavedStateResult(id: id, type: type, saved: saved);
  }
}
