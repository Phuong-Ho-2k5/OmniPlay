import '../../catalog/models/catalog_json.dart';

enum CleanupAction {
  keep('KEEP'),
  dismiss('DISMISS'),
  remove('REMOVE');

  const CleanupAction(this.wireValue);
  final String wireValue;
}

class CleanupSuggestionItem {
  const CleanupSuggestionItem({
    required this.playlistItemId,
    required this.playlistId,
    required this.mediaId,
    required this.title,
    required this.skipCount,
  });

  final String playlistItemId;
  final String playlistId;
  final String mediaId;
  final String title;
  final int skipCount;

  factory CleanupSuggestionItem.fromJson(Map<String, dynamic> json) {
    final skipCount = json['skipCount'];
    if (skipCount is! int || skipCount < 0) invalidCatalogResponse();
    return CleanupSuggestionItem(
      playlistItemId: catalogId(json['playlistItemId']),
      playlistId: catalogId(json['playlistId']),
      mediaId: catalogId(json['mediaId']),
      title: catalogString(json['title']),
      skipCount: skipCount,
    );
  }
}

class CleanupActionResult {
  const CleanupActionResult({
    required this.playlistItemId,
    required this.removed,
    required this.skipCount,
    required this.suggestionVisible,
  });

  final String playlistItemId;
  final bool removed;
  final int skipCount;
  final bool suggestionVisible;

  factory CleanupActionResult.fromJson(Map<String, dynamic> json) {
    final removed = json['removed'];
    final skipCount = json['skipCount'];
    final suggestionVisible = json['suggestionVisible'];
    if (removed is! bool ||
        skipCount is! int ||
        skipCount < 0 ||
        suggestionVisible is! bool) {
      invalidCatalogResponse();
    }
    return CleanupActionResult(
      playlistItemId: catalogId(json['playlistItemId']),
      removed: removed,
      skipCount: skipCount,
      suggestionVisible: suggestionVisible,
    );
  }
}
