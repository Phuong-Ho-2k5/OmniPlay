import '../models/daily_quest.dart';

class QuestsState {
  const QuestsState({this.questSet, required this.loading, this.message});

  final DailyQuestSet? questSet;
  final bool loading;
  final String? message;
}
