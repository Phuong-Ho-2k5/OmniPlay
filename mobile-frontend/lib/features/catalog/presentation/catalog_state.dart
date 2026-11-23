import '../models/catalog_query.dart';
import '../models/content_summary.dart';
import '../models/genre.dart';

class CatalogState {
  CatalogState({
    required this.query,
    required List<ContentSummary> items,
    required List<Genre> genres,
    required this.loading,
    required this.loadingMore,
    required this.loadingGenres,
    required this.page,
    required this.totalElements,
    this.message,
    this.moreMessage,
    this.genresMessage,
  }) : items = List.unmodifiable(items),
       genres = List.unmodifiable(genres);
  final CatalogQuery query;
  final List<ContentSummary> items;
  final List<Genre> genres;
  final bool loading, loadingMore, loadingGenres;
  final int page, totalElements;
  final String? message, moreMessage, genresMessage;
  bool get canLoadMore =>
      !loading && page >= 0 && (page + 1) * query.size < totalElements;
}
