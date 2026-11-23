import 'content_type.dart';

class CatalogQuery {
  const CatalogQuery({
    this.keyword = '',
    this.type,
    this.genreId,
    this.page = 0,
    this.size = 20,
  });
  final String keyword;
  final ContentType? type;
  final String? genreId;
  final int page, size;

  CatalogQuery atPage(int value) => CatalogQuery(
    keyword: keyword,
    type: type,
    genreId: genreId,
    page: value,
    size: size,
  );

  String get path => Uri(
    path: keyword.trim().isEmpty && genreId == null
        ? '/catalog'
        : '/catalog/search',
    queryParameters: {
      if (keyword.trim().isNotEmpty) 'q': keyword.trim(),
      if (type != null) 'type': type!.apiValue,
      'genreId': ?genreId,
      'page': '$page',
      'size': '$size',
    },
  ).toString();
}
