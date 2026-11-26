import '../models/saved_content_summary.dart';

class SavedState {
  SavedState({
    required List<SavedContentSummary> items,
    required this.loading,
    required this.loadingMore,
    required this.page,
    required this.size,
    required this.totalElements,
    required Set<String> pendingKeys,
    this.message,
    this.moreMessage,
    this.actionError,
  }) : items = List.unmodifiable(items),
       pendingKeys = Set.unmodifiable(pendingKeys);

  final List<SavedContentSummary> items;
  final bool loading;
  final bool loadingMore;
  final int page;
  final int size;
  final int totalElements;
  final Set<String> pendingKeys;
  final String? message;
  final String? moreMessage;
  final String? actionError;

  bool get canLoadMore =>
      !loading && page >= 0 && (page + 1) * size < totalElements;
}
