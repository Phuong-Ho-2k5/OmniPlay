import '../../catalog/models/catalog_json.dart';
import '../../catalog/models/content_type.dart';

enum QuestSourceScope {
  any('ANY', 'Kho nội dung'),
  saved('SAVED', 'Đã lưu');

  const QuestSourceScope(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static QuestSourceScope fromWire(Object? value) {
    final raw = catalogString(value);
    for (final scope in QuestSourceScope.values) {
      if (scope.wireValue == raw) return scope;
    }
    invalidCatalogResponse();
  }
}

enum QuestStatus {
  active('ACTIVE', 'Đang thực hiện'),
  claimable('CLAIMABLE', 'Sẵn sàng nhận thưởng'),
  claimed('CLAIMED', 'Đã nhận'),
  expired('EXPIRED', 'Hết hạn');

  const QuestStatus(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static QuestStatus fromWire(Object? value) {
    final raw = catalogString(value);
    for (final status in QuestStatus.values) {
      if (status.wireValue == raw) return status;
    }
    invalidCatalogResponse();
  }
}

class DailyQuest {
  DailyQuest({
    required this.id,
    required this.code,
    required this.title,
    required this.slot,
    required this.sourceScope,
    required this.mediaType,
    required this.targetCount,
    required this.progressCount,
    required this.status,
    required this.xpReward,
    required List<String> eligibleMediaIds,
  }) : eligibleMediaIds = List.unmodifiable(eligibleMediaIds);

  final String id;
  final String code;
  final String title;
  final int slot;
  final QuestSourceScope sourceScope;
  final ContentType? mediaType;
  final int targetCount;
  final int progressCount;
  final QuestStatus status;
  final int xpReward;
  final List<String> eligibleMediaIds;

  double get progressRatio =>
      targetCount <= 0 ? 0 : (progressCount / targetCount).clamp(0.0, 1.0);

  DailyQuest copyWith({int? progressCount, QuestStatus? status}) => DailyQuest(
    id: id,
    code: code,
    title: title,
    slot: slot,
    sourceScope: sourceScope,
    mediaType: mediaType,
    targetCount: targetCount,
    progressCount: progressCount ?? this.progressCount,
    status: status ?? this.status,
    xpReward: xpReward,
    eligibleMediaIds: eligibleMediaIds,
  );

  static ContentType? _parseMediaType(Object? value) {
    if (value == null) return null;
    final raw = catalogString(value);
    for (final type in ContentType.values) {
      if (type != ContentType.post && type.apiValue == raw) return type;
    }
    invalidCatalogResponse();
  }

  factory DailyQuest.fromJson(Map<String, dynamic> json) {
    return DailyQuest(
      id: catalogId(json['id']),
      code: catalogString(json['code']),
      title: catalogString(json['title']),
      slot: catalogInt(json['slot'], min: 1),
      sourceScope: QuestSourceScope.fromWire(json['sourceScope']),
      mediaType: _parseMediaType(json['mediaType']),
      targetCount: catalogInt(json['targetCount'], min: 1),
      progressCount: catalogInt(json['progressCount']),
      status: QuestStatus.fromWire(json['status']),
      xpReward: catalogInt(json['xpReward'], min: 1),
      eligibleMediaIds: catalogList(json['eligibleMediaIds'])
          .map(catalogId)
          .toList(),
    );
  }
}

class DailyQuestSet {
  DailyQuestSet({
    required this.questSetId,
    required this.questDate,
    required this.issuedAt,
    required this.expiresAt,
    required List<DailyQuest> quests,
  }) : quests = List.unmodifiable(quests);

  final String questSetId;
  final String questDate;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final List<DailyQuest> quests;

  int get completedCount => quests
      .where(
        (q) =>
            q.status == QuestStatus.claimable ||
            q.status == QuestStatus.claimed,
      )
      .length;

  DailyQuestSet copyWith({List<DailyQuest>? quests}) => DailyQuestSet(
    questSetId: questSetId,
    questDate: questDate,
    issuedAt: issuedAt,
    expiresAt: expiresAt,
    quests: quests ?? this.quests,
  );

  factory DailyQuestSet.fromJson(Map<String, dynamic> json) {
    final issuedAt = DateTime.tryParse(catalogString(json['issuedAt']))
        ?.toUtc();
    final expiresAt = DateTime.tryParse(catalogString(json['expiresAt']))
        ?.toUtc();
    if (issuedAt == null || expiresAt == null) invalidCatalogResponse();
    return DailyQuestSet(
      questSetId: catalogId(json['questSetId']),
      questDate: catalogString(json['questDate']),
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      quests: catalogList(json['quests'])
          .map((v) => DailyQuest.fromJson(catalogObject(v)))
          .toList(),
    );
  }
}
