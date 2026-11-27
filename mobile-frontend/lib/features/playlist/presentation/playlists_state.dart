import '../models/playlist.dart';

class PlaylistsState {
  PlaylistsState({
    required List<PlaylistSummary> items,
    required this.loading,
    required this.loadingMore,
    required this.page,
    required this.size,
    required this.totalElements,
    this.cleanupSuggestionCount = 0,
    this.message,
    this.moreMessage,
    this.actionError,
  }) : items = List.unmodifiable(items);

  final List<PlaylistSummary> items;
  final bool loading;
  final bool loadingMore;
  final int page;
  final int size;
  final int totalElements;
  final int cleanupSuggestionCount;
  final String? message;
  final String? moreMessage;
  final String? actionError;

  bool get canLoadMore =>
      !loading && page >= 0 && (page + 1) * size < totalElements;
}
