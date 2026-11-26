import '../../catalog/models/catalog_json.dart';

DateTime _parseUtc(Object? raw) {
  final parsed = DateTime.tryParse(catalogString(raw))?.toUtc();
  if (parsed == null) invalidCatalogResponse();
  return parsed;
}

class PlaylistSummary {
  const PlaylistSummary({
    required this.id,
    required this.name,
    required this.itemCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int itemCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlaylistSummary copyWith({String? name, DateTime? updatedAt}) =>
      PlaylistSummary(
        id: id,
        name: name ?? this.name,
        itemCount: itemCount,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory PlaylistSummary.fromJson(Map<String, dynamic> json) =>
      PlaylistSummary(
        id: catalogId(json['id']),
        name: catalogString(json['name']),
        itemCount: catalogInt(json['itemCount']),
        createdAt: _parseUtc(json['createdAt']),
        updatedAt: _parseUtc(json['updatedAt']),
      );
}

class PlaylistPage {
  PlaylistPage({
    required List<PlaylistSummary> items,
    required this.page,
    required this.size,
    required this.totalElements,
  }) : items = List.unmodifiable(items);

  final List<PlaylistSummary> items;
  final int page;
  final int size;
  final int totalElements;

  factory PlaylistPage.fromJson(Map<String, dynamic> json) {
    final items = catalogList(json['items'])
        .map((v) => PlaylistSummary.fromJson(catalogObject(v)))
        .toList();
    final size = catalogInt(json['size'], min: 1);
    final total = catalogInt(json['totalElements']);
    final page = catalogInt(json['page']);
    final expectedCount = (total - page * size).clamp(0, size);
    if (size > 50 || page > 2147483647 || items.length != expectedCount) {
      invalidCatalogResponse();
    }
    return PlaylistPage(
      items: items,
      page: page,
      size: size,
      totalElements: total,
    );
  }
}

class PlaylistItemSummary {
  const PlaylistItemSummary({
    required this.playlistItemId,
    required this.mediaId,
    required this.title,
    required this.position,
    required this.skipCount,
    required this.available,
  });

  final String playlistItemId;
  final String mediaId;
  final String title;
  final int position;
  final int skipCount;
  final bool available;

  factory PlaylistItemSummary.fromJson(Map<String, dynamic> json) {
    final available = json['available'];
    if (available is! bool) invalidCatalogResponse();
    return PlaylistItemSummary(
      playlistItemId: catalogId(json['playlistItemId']),
      mediaId: catalogId(json['mediaId']),
      title: catalogString(json['title']),
      position: catalogInt(json['position']),
      skipCount: catalogInt(json['skipCount']),
      available: available,
    );
  }
}

class PlaylistDetail {
  PlaylistDetail({
    required this.id,
    required this.name,
    required List<PlaylistItemSummary> items,
  }) : items = List.unmodifiable(items);

  final String id;
  final String name;
  final List<PlaylistItemSummary> items;

  factory PlaylistDetail.fromJson(Map<String, dynamic> json) => PlaylistDetail(
    id: catalogId(json['id']),
    name: catalogString(json['name']),
    items: catalogList(json['items'])
        .map((v) => PlaylistItemSummary.fromJson(catalogObject(v)))
        .toList(),
  );
}

class PlaylistRenamed {
  const PlaylistRenamed({
    required this.id,
    required this.name,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final DateTime updatedAt;

  factory PlaylistRenamed.fromJson(Map<String, dynamic> json) =>
      PlaylistRenamed(
        id: catalogId(json['id']),
        name: catalogString(json['name']),
        updatedAt: _parseUtc(json['updatedAt']),
      );
}

class PlaylistItemAdded {
  const PlaylistItemAdded({
    required this.playlistItemId,
    required this.mediaId,
    required this.position,
  });

  final String playlistItemId;
  final String mediaId;
  final int position;

  factory PlaylistItemAdded.fromJson(Map<String, dynamic> json) =>
      PlaylistItemAdded(
        playlistItemId: catalogId(json['playlistItemId']),
        mediaId: catalogId(json['mediaId']),
        position: catalogInt(json['position']),
      );
}
