import '../../catalog/models/catalog_json.dart';
import '../../catalog/models/content_type.dart';
import 'playback_report.dart';

enum ListeningSessionType {
  music('music', 'Nhạc', ContentType.music),
  podcast('podcast', 'Podcast', ContentType.podcast);

  const ListeningSessionType(this.apiValue, this.label, this.contentType);
  final String apiValue;
  final String label;
  final ContentType contentType;

  static ListeningSessionType? fromContentType(ContentType type) =>
      switch (type) {
        ContentType.music => ListeningSessionType.music,
        ContentType.podcast => ListeningSessionType.podcast,
        _ => null,
      };

  static ListeningSessionType fromApi(Object? value) {
    final text = catalogString(value);
    for (final candidate in values) {
      if (candidate.apiValue == text) return candidate;
    }
    invalidCatalogResponse();
  }
}

class ListeningQueueItem {
  const ListeningQueueItem({required this.mediaId, required this.position});

  final String mediaId;
  final int position;

  factory ListeningQueueItem.fromJson(Map<String, dynamic> json) =>
      ListeningQueueItem(
        mediaId: catalogId(json['mediaId']),
        position: catalogInt(json['position']),
      );
}

class ListeningSessionState {
  ListeningSessionState({
    required this.type,
    required this.currentMediaId,
    required this.positionSeconds,
    required this.isPaused,
    required List<ListeningQueueItem> queue,
  }) : queue = List.unmodifiable(queue);

  final ListeningSessionType type;
  final String? currentMediaId;
  final double positionSeconds;
  final bool isPaused;
  final List<ListeningQueueItem> queue;

  List<String> get queueMediaIds => [for (final item in queue) item.mediaId];

  factory ListeningSessionState.empty(ListeningSessionType type) =>
      ListeningSessionState(
        type: type,
        currentMediaId: null,
        positionSeconds: 0,
        isPaused: true,
        queue: const [],
      );

  factory ListeningSessionState.fromJson(Map<String, dynamic> json) {
    final type = ListeningSessionType.fromApi(json['type']);
    final rawMedia = json['currentMediaId'];
    final mediaId = rawMedia == null ? null : catalogId(rawMedia);
    final rawPos = json['positionSeconds'];
    if (rawPos is! num || rawPos.isNaN || rawPos.isInfinite || rawPos < 0) {
      invalidCatalogResponse();
    }
    final paused = json['isPaused'];
    if (paused is! bool) invalidCatalogResponse();
    final items = catalogList(json['queue'])
        .map((e) => ListeningQueueItem.fromJson(catalogObject(e)))
        .toList();
    return ListeningSessionState(
      type: type,
      currentMediaId: mediaId,
      positionSeconds: rawPos.toDouble(),
      isPaused: paused,
      queue: items,
    );
  }
}

class SaveListeningSessionPayload {
  const SaveListeningSessionPayload({
    required this.currentMediaId,
    required this.positionSeconds,
    required this.queue,
    this.playbackReport,
  });

  final String? currentMediaId;
  final double positionSeconds;
  final List<String> queue;
  final PlaybackReport? playbackReport;

  Map<String, dynamic> toJson() => {
    'currentMediaId': currentMediaId,
    'positionSeconds': roundToMillis(positionSeconds),
    'queue': queue,
    if (playbackReport != null) 'playbackReport': playbackReport!.toJson(),
  };
}
