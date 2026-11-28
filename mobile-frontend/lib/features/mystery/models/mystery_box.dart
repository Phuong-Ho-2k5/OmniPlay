import '../../catalog/models/catalog_json.dart';
import '../../catalog/models/content_summary.dart';
import '../../catalog/models/content_type.dart';

enum MysteryBoxResultType {
  found('FOUND'),
  noAlternative('NO_ALTERNATIVE'),
  empty('EMPTY');

  const MysteryBoxResultType(this.wireValue);
  final String wireValue;

  static MysteryBoxResultType fromWire(Object? value) {
    final raw = catalogString(value);
    for (final item in MysteryBoxResultType.values) {
      if (item.wireValue == raw) return item;
    }
    invalidCatalogResponse();
  }
}

class MysteryBoxFilter {
  const MysteryBoxFilter({
    this.mediaType,
    this.genreId,
    this.maxDurationSeconds,
  });

  final ContentType? mediaType;
  final String? genreId;
  final int? maxDurationSeconds;

  MysteryBoxFilter copyWith({
    ContentType? mediaType,
    bool clearMediaType = false,
    String? genreId,
    bool clearGenreId = false,
    int? maxDurationSeconds,
    bool clearMaxDuration = false,
  }) => MysteryBoxFilter(
    mediaType: clearMediaType ? null : (mediaType ?? this.mediaType),
    genreId: clearGenreId ? null : (genreId ?? this.genreId),
    maxDurationSeconds: clearMaxDuration
        ? null
        : (maxDurationSeconds ?? this.maxDurationSeconds),
  );
}

class MysteryBoxDrawResponse {
  const MysteryBoxDrawResponse({required this.result, required this.media});

  final MysteryBoxResultType result;
  final ContentSummary? media;

  factory MysteryBoxDrawResponse.fromJson(Map<String, dynamic> json) {
    final result = MysteryBoxResultType.fromWire(json['result']);
    final rawMedia = json['media'];
    final media = rawMedia == null
        ? null
        : ContentSummary.fromJson(catalogObject(rawMedia));
    if (result != MysteryBoxResultType.empty && media == null) {
      invalidCatalogResponse();
    }
    return MysteryBoxDrawResponse(result: result, media: media);
  }
}
