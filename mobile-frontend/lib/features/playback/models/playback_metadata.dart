import '../../catalog/models/catalog_json.dart';
import '../../catalog/models/content_type.dart';

final RegExp _streamPathPattern = RegExp(
  r'^/media/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/stream$',
);

String validateStreamPath(String value) {
  if (!_streamPathPattern.hasMatch(value)) {
    invalidCatalogResponse();
  }
  return value;
}

class PlaybackMetadata {
  const PlaybackMetadata({
    required this.mediaId,
    required this.type,
    required this.durationSeconds,
    required this.resumePositionSeconds,
    required this.completed,
    required this.streamPath,
  });

  final String mediaId;
  final ContentType type;
  final int durationSeconds;
  final double resumePositionSeconds;
  final bool completed;
  final String streamPath;

  factory PlaybackMetadata.fromJson(Map<String, dynamic> json) {
    final id = catalogId(json['mediaId']);
    final rawType = catalogString(json['type']);
    ContentType? type;
    for (final candidate in ContentType.values) {
      if (candidate.apiValue == rawType) {
        type = candidate;
        break;
      }
    }
    if (type == null || type == ContentType.post) invalidCatalogResponse();
    final duration = catalogInt(json['durationSeconds'], min: 1);
    final rawResume = json['resumePositionSeconds'];
    if (rawResume is! num ||
        rawResume.isNaN ||
        rawResume.isInfinite ||
        rawResume < 0) {
      invalidCatalogResponse();
    }
    final completed = json['completed'];
    if (completed is! bool) invalidCatalogResponse();
    final rawPath = json['streamPath'];
    if (rawPath is! String) invalidCatalogResponse();
    final streamPath = validateStreamPath(rawPath);
    return PlaybackMetadata(
      mediaId: id,
      type: type,
      durationSeconds: duration,
      resumePositionSeconds: rawResume.toDouble(),
      completed: completed,
      streamPath: streamPath,
    );
  }
}

class StreamAuthRequest {
  const StreamAuthRequest({
    required this.uri,
    required this.headers,
    required this.generation,
    required this.revision,
  });

  final Uri uri;
  final Map<String, String> headers;
  final int generation;
  final int revision;
}
