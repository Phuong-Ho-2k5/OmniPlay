import 'catalog_json.dart';
import 'content_type.dart';

class ContentSummary {
  ContentSummary({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required List<String> genreIds,
    required this.saved,
  }) : genreIds = List.unmodifiable(genreIds);
  final String id, title;
  final ContentType type;
  final String? description, thumbnailUrl;
  final int? durationSeconds;
  final List<String> genreIds;
  final bool saved;

  factory ContentSummary.fromJson(Map<String, dynamic> json) {
    final rawType = catalogString(json['type']);
    final types = ContentType.values.where((t) => t.apiValue == rawType);
    if (types.isEmpty || json['saved'] is! bool) invalidCatalogResponse();
    final type = types.single;
    final thumbnail = catalogNullableString(json['thumbnailUrl']);
    final duration = json['durationSeconds'] == null
        ? null
        : catalogInt(json['durationSeconds'], min: 1);
    final genres = catalogList(json['genreIds']).map(catalogId).toList();
    if (type == ContentType.post &&
        (thumbnail != null || duration != null || genres.isNotEmpty)) {
      invalidCatalogResponse();
    }
    if (type != ContentType.post && duration == null) invalidCatalogResponse();
    return ContentSummary(
      id: catalogId(json['id']),
      type: type,
      title: catalogString(json['title']),
      description: catalogNullableString(json['description']),
      thumbnailUrl: thumbnail,
      durationSeconds: duration,
      genreIds: genres,
      saved: json['saved'] as bool,
    );
  }

  String? get durationLabel {
    final seconds = durationSeconds;
    if (seconds == null) return null;
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
