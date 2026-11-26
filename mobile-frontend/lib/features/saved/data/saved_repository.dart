import '../../../core/network/api_client.dart';
import '../../catalog/models/catalog_json.dart';
import '../../catalog/models/content_type.dart';
import '../models/saved_content_summary.dart';

abstract class SavedRepository {
  Future<SavedPage> list({int page = 0, int size = 20});
  Future<SavedStateResult> setSaved({
    required String id,
    required ContentType type,
    required bool saved,
  });
}

class RemoteSavedRepository implements SavedRepository {
  RemoteSavedRepository(this._api);

  final ApiClient _api;

  @override
  Future<SavedPage> list({int page = 0, int size = 20}) async {
    final path = Uri(
      path: '/me/saved',
      queryParameters: {'page': '$page', 'size': '$size'},
    ).toString();
    final parsed = SavedPage.fromJson(
      await _api.getJson(path, expectedStatusCode: 200),
    );
    if (parsed.page != page || parsed.size != size) {
      invalidCatalogResponse();
    }
    return parsed;
  }

  @override
  Future<SavedStateResult> setSaved({
    required String id,
    required ContentType type,
    required bool saved,
  }) async {
    catalogId(id);
    final json = await _api.putJson(
      '/me/saved/$id',
      body: {'type': type.apiValue, 'saved': saved},
      expectedStatusCode: 200,
    );
    final result = SavedStateResult.fromJson(json);
    if (result.id.toLowerCase() != id.toLowerCase() || result.type != type) {
      invalidCatalogResponse();
    }
    return result;
  }
}
