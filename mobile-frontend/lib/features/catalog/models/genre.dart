import 'catalog_json.dart';

class Genre {
  const Genre({required this.id, required this.name});
  final String id, name;
  factory Genre.fromJson(Map<String, dynamic> json) =>
      Genre(id: catalogId(json['id']), name: catalogString(json['name']));
}
