import '../models/daily_quest.dart';

class QuestsState {
  QuestsState({
    this.questSet,
    required this.loading,
    this.message,
    Set<String> claimingQuestIds = const {},
    Map<String, String> claimErrors = const {},
    this.latestTotalXp,
    this.latestLevel,
    this.notice,
  }) : claimingQuestIds = Set.unmodifiable(claimingQuestIds),
       claimErrors = Map.unmodifiable(claimErrors);

  final DailyQuestSet? questSet;
  final bool loading;
  final String? message;
  final Set<String> claimingQuestIds;
  final Map<String, String> claimErrors;
  final int? latestTotalXp;
  final int? latestLevel;
  final String? notice;

  bool isClaiming(String questId) => claimingQuestIds.contains(questId);
  String? claimErrorFor(String questId) => claimErrors[questId];
}
