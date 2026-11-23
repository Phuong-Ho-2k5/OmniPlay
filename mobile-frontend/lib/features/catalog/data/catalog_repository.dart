import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../models/catalog_json.dart';
import '../models/catalog_page.dart';
import '../models/catalog_query.dart';
import '../models/content_detail.dart';
import '../models/content_type.dart';
import '../models/genre.dart';

abstract class CatalogRepository {
  Future<CatalogPage> list(CatalogQuery query);
  Future<ContentDetail> detail({required String id, required ContentType type});
  Future<List<Genre>> genres();
  Future<Uint8List> thumbnail(String relativePath);
}

class RemoteCatalogRepository implements CatalogRepository {
  RemoteCatalogRepository(this._api);
  final ApiClient _api;

  @override
  Future<CatalogPage> list(CatalogQuery query) async {
    final page = CatalogPage.fromJson(
      await _api.getJson(query.path, expectedStatusCode: 200),
    );
    if (page.page != query.page || page.size != query.size) {
      invalidCatalogResponse();
    }
    return page;
  }

  @override
  Future<ContentDetail> detail({
    required String id,
    required ContentType type,
  }) async {
    catalogId(id);
    final path = Uri(
      path: '/catalog/$id',
      queryParameters: {'type': type.apiValue},
    ).toString();
    final value = ContentDetail.fromJson(
      await _api.getJson(path, expectedStatusCode: 200),
    );
    if (value.summary.id.toLowerCase() != id.toLowerCase() ||
        value.summary.type != type) {
      invalidCatalogResponse();
    }
    return value;
  }

  @override
  Future<List<Genre>> genres() async {
    final response = await _api.getJson('/genres', expectedStatusCode: 200);
    return List.unmodifiable(
      catalogList(response['items'])
          .map((v) => Genre.fromJson(catalogObject(v))),
    );
  }

  @override
  Future<Uint8List> thumbnail(String relativePath) async {
    // Only the exact UUID route can receive credentials. No URL supplied by content can change host.
    if (!RegExp(
      r'^/media/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/thumbnail$',
    ).hasMatch(relativePath)) {
      invalidCatalogResponse();
    }
    return _api.getBytes(relativePath);
  }
}
