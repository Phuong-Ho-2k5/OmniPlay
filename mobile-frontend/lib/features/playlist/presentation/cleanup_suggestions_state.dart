import '../models/cleanup_suggestion.dart';

class CleanupSuggestionsState {
  CleanupSuggestionsState({
    required List<CleanupSuggestionItem> items,
    required this.loading,
    required Set<String> busyItemIds,
    this.message,
    this.actionError,
    this.feedbackMessage,
  }) : items = List.unmodifiable(items),
       busyItemIds = Set.unmodifiable(busyItemIds);

  final List<CleanupSuggestionItem> items;
  final bool loading;
  final Set<String> busyItemIds;
  final String? message;
  final String? actionError;
  final String? feedbackMessage;

  bool isBusy(String playlistItemId) => busyItemIds.contains(playlistItemId);
}
