import '../../../core/network/api_client.dart';
import '../../catalog/models/catalog_json.dart';
import '../models/mystery_box.dart';

abstract class MysteryBoxRepository {
  Future<MysteryBoxDrawResponse> draw(
    MysteryBoxFilter filter, {
    String? excludeMediaId,
  });
}

class RemoteMysteryBoxRepository implements MysteryBoxRepository {
  RemoteMysteryBoxRepository(this._api);

  final ApiClient _api;

  @override
  Future<MysteryBoxDrawResponse> draw(
    MysteryBoxFilter filter, {
    String? excludeMediaId,
  }) async {
    if (filter.genreId != null) catalogId(filter.genreId);
    if (excludeMediaId != null) catalogId(excludeMediaId);
    final body = <String, dynamic>{
      if (filter.mediaType != null) 'mediaType': filter.mediaType!.apiValue,
      'genreId': ?filter.genreId,
      'maxDurationSeconds': ?filter.maxDurationSeconds,
      'excludeMediaId': ?excludeMediaId,
    };
    final json = await _api.postJson(
      '/mystery-box/draw',
      body: body,
      expectedStatusCode: 200,
    );
    return MysteryBoxDrawResponse.fromJson(json);
  }
}
