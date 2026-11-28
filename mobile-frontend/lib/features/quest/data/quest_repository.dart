import '../../../core/network/api_client.dart';
import '../../catalog/models/catalog_json.dart';
import '../../catalog/models/catalog_page.dart';
import '../models/daily_quest.dart';

abstract class QuestRepository {
  Future<DailyQuestSet> ensureToday();
  Future<DailyQuestSet> getToday();
  Future<CatalogPage> getQuestMedia(
    String questId, {
    int page = 0,
    int size = 20,
  });
  Future<ClaimQuestResult> claimQuest(String questId);
}

class RemoteQuestRepository implements QuestRepository {
  RemoteQuestRepository(this._api);

  final ApiClient _api;

  @override
  Future<DailyQuestSet> ensureToday() async {
    final json = await _api.postJson(
      '/me/quests/today/ensure',
      expectedStatusCode: 200,
    );
    return DailyQuestSet.fromJson(json);
  }

  @override
  Future<DailyQuestSet> getToday() async {
    final json = await _api.getJson(
      '/me/quests/today',
      expectedStatusCode: 200,
    );
    return DailyQuestSet.fromJson(json);
  }

  @override
  Future<CatalogPage> getQuestMedia(
    String questId, {
    int page = 0,
    int size = 20,
  }) async {
    catalogId(questId);
    final path = Uri(
      path: '/me/quests/$questId/media',
      queryParameters: {'page': '$page', 'size': '$size'},
    ).toString();
    final parsed = CatalogPage.fromJson(
      await _api.getJson(path, expectedStatusCode: 200),
    );
    if (parsed.page != page || parsed.size != size) {
      invalidCatalogResponse();
    }
    return parsed;
  }

  @override
  Future<ClaimQuestResult> claimQuest(String questId) async {
    catalogId(questId);
    final json = await _api.postJson(
      '/me/quests/$questId/claim',
      expectedStatusCode: 200,
    );
    return ClaimQuestResult.fromJson(json);
  }
}
