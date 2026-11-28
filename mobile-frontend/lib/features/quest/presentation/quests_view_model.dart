import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
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
  final Set<String> _claimingQuestIds = {};
  final Map<String, String> _claimErrors = {};
  int? _latestTotalXp;
  int? _latestLevel;
  String? _notice;
  bool _disposed = false;
  int _sequence = 0;

  QuestsState get state => QuestsState(
    questSet: _questSet,
    loading: _loading,
    message: _message,
    claimingQuestIds: _claimingQuestIds,
    claimErrors: _claimErrors,
    latestTotalXp: _latestTotalXp,
    latestLevel: _latestLevel,
    notice: _notice,
  );

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
      _claimErrors.clear();
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

  Future<ClaimQuestResult?> claimQuest(DailyQuest quest) async {
    if (_disposed || _claimingQuestIds.contains(quest.id)) return null;
    _claimingQuestIds.add(quest.id);
    _claimErrors.remove(quest.id);
    _notice = null;
    _emit();

    try {
      final result = await _repository.claimQuest(quest.id);
      if (_disposed) return result;
      _latestTotalXp = result.totalXp;
      _latestLevel = result.level;
      _updateSingleQuestStatus(quest.id, result.status);
      _claimErrors.remove(quest.id);
      return result;
    } on ApiException catch (error) {
      if (_disposed) return null;
      if (error.code == 'QUEST_EXPIRED') {
        _updateSingleQuestStatus(quest.id, QuestStatus.expired);
        _notice =
            'Quest đã hết hạn do sang ngày mới. Đang tải bộ Quest hôm nay.';
        unawaited(ensureToday());
      } else {
        _claimErrors[quest.id] = error.message.isNotEmpty
            ? error.message
            : catalogErrorMessage(error);
      }
      return null;
    } catch (error) {
      if (!_disposed) {
        _claimErrors[quest.id] = catalogErrorMessage(error);
      }
      return null;
    } finally {
      if (!_disposed) {
        _claimingQuestIds.remove(quest.id);
        _emit();
      }
    }
  }

  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    _emit();
  }

  void _updateSingleQuestStatus(String questId, QuestStatus status) {
    final current = _questSet;
    if (current == null) return;
    _questSet = current.copyWith(
      quests: [
        for (final q in current.quests)
          q.id == questId ? q.copyWith(status: status) : q,
      ],
    );
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
