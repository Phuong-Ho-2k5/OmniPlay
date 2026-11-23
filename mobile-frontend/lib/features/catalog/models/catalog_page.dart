import 'catalog_json.dart';
import 'content_summary.dart';

class CatalogPage {
  CatalogPage({
    required List<ContentSummary> items,
    required this.page,
    required this.size,
    required this.totalElements,
  }) : items = List.unmodifiable(items);
  final List<ContentSummary> items;
  final int page, size, totalElements;

  factory CatalogPage.fromJson(Map<String, dynamic> json) {
    final items = catalogList(json['items'])
        .map((v) => ContentSummary.fromJson(catalogObject(v)))
        .toList();
    final size = catalogInt(json['size'], min: 1);
    final total = catalogInt(json['totalElements']);
    final page = catalogInt(json['page']);
    final expectedCount = (total - page * size).clamp(0, size);
    if (size > 50 || page > 2147483647 || items.length != expectedCount) {
      invalidCatalogResponse();
    }
    return CatalogPage(
      items: items,
      page: page,
      size: size,
      totalElements: total,
    );
  }
}
