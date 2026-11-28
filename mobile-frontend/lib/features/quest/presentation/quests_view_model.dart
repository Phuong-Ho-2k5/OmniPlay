import 'package:flutter/foundation.dart';

import '../../catalog/presentation/catalog_message.dart';
import '../../playback/models/playback_report.dart';
import '../data/quest_repository.dart';
import '../models/daily_quest.dart';
import 'quests_state.dart';

class QuestsViewModel extends ChangeNotifier {
  QuestsViewModel(this._repository);

  final QuestRepository _repository;

  DailyQuestSet? _questSet;
  bool _loading = false;
  String? _message;
  bool _disposed = false;
  int _sequence = 0;

  QuestsState get state =>
      QuestsState(questSet: _questSet, loading: _loading, message: _message);

  String? activeQuestSetIdFor(DateTime nowUtc) {
    final current = _questSet;
    if (current == null) return null;
    return nowUtc.toUtc().isBefore(current.expiresAt)
        ? current.questSetId
        : null;
  }

  void applyProgressUpdates(List<QuestProgressUpdate> updates) {
    final current = _questSet;
    if (_disposed || current == null || updates.isEmpty) return;
    final byId = {for (final u in updates) u.questId: u};
    var changed = false;
    final nextQuests = [
      for (final q in current.quests)
        if (byId.containsKey(q.id))
          (() {
            final u = byId[q.id]!;
            changed = true;
            return q.copyWith(
              progressCount: u.progressCount,
              status: QuestStatus.fromWire(u.status),
            );
          })()
        else
          q,
    ];
    if (changed) {
      _questSet = current.copyWith(quests: nextQuests);
      _emit();
    }
  }

  Future<void> ensureToday() async {
    if (_disposed) return;
    final seq = ++_sequence;
    _loading = true;
    _message = null;
    _emit();

    try {
      final fetched = await _repository.ensureToday();
      if (_disposed || seq != _sequence) return;
      _questSet = fetched;
      _message = null;
    } catch (error) {
      if (_disposed || seq != _sequence) return;
      _message = catalogErrorMessage(error);
    } finally {
      if (!_disposed && seq == _sequence) {
        _loading = false;
        _emit();
      }
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sequence++;
    super.dispose();
  }
}
