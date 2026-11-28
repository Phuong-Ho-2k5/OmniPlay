import '../../catalog/models/catalog_json.dart';

double roundToMillis(double seconds) => (seconds * 1000).round() / 1000.0;

class PlaybackAttempt {
  const PlaybackAttempt({
    required this.attemptId,
    required this.mediaId,
    required this.playlistItemId,
    required this.startedAt,
  });

  final String attemptId;
  final String mediaId;
  final String? playlistItemId;
  final DateTime startedAt;

  factory PlaybackAttempt.fromJson(Map<String, dynamic> json) {
    final rawStarted = catalogString(json['startedAt']);
    final startedAt = DateTime.tryParse(rawStarted)?.toUtc();
    if (startedAt == null) invalidCatalogResponse();
    final rawItem = json['playlistItemId'];
    return PlaybackAttempt(
      attemptId: catalogId(json['attemptId']),
      mediaId: catalogId(json['mediaId']),
      playlistItemId: rawItem == null ? null : catalogId(rawItem),
      startedAt: startedAt,
    );
  }
}

class PlaybackSegment {
  const PlaybackSegment({
    required this.eventSeq,
    required this.startSecond,
    required this.endSecond,
    required this.playedFrom,
    required this.playedTo,
  });

  final int eventSeq;
  final double startSecond;
  final double endSecond;
  final DateTime playedFrom;
  final DateTime playedTo;

  Map<String, dynamic> toJson() => {
    'eventSeq': eventSeq,
    'startSecond': roundToMillis(startSecond),
    'endSecond': roundToMillis(endSecond),
    'playedFrom': playedFrom.toUtc().toIso8601String(),
    'playedTo': playedTo.toUtc().toIso8601String(),
  };
}

class PlaybackReport {
  const PlaybackReport({
    required this.attemptId,
    required this.resumePositionSeconds,
    this.questSetId,
    required this.segments,
  });

  final String attemptId;
  final double resumePositionSeconds;
  final String? questSetId;
  final List<PlaybackSegment> segments;

  Map<String, dynamic> toJson() => {
    'attemptId': attemptId,
    'resumePositionSeconds': roundToMillis(resumePositionSeconds),
    if (questSetId != null) 'questSetId': questSetId,
    'segments': [for (final s in segments) s.toJson()],
  };
}

class QuestProgressUpdate {
  const QuestProgressUpdate({
    required this.questId,
    required this.progressCount,
    required this.status,
  });

  final String questId;
  final int progressCount;
  final String status;

  factory QuestProgressUpdate.fromJson(Map<String, dynamic> json) =>
      QuestProgressUpdate(
        questId: catalogId(json['questId']),
        progressCount: catalogInt(json['progressCount']),
        status: catalogString(json['status']),
      );
}

class PlaybackProgressResult {
  PlaybackProgressResult({
    required this.mediaId,
    required this.resumePositionSeconds,
    required this.coveredSeconds,
    required this.completed,
    List<QuestProgressUpdate> questUpdates = const [],
  }) : questUpdates = List.unmodifiable(questUpdates);

  final String mediaId;
  final double resumePositionSeconds;
  final double coveredSeconds;
  final bool completed;
  final List<QuestProgressUpdate> questUpdates;

  factory PlaybackProgressResult.fromJson(Map<String, dynamic> json) {
    final resume = json['resumePositionSeconds'];
    final covered = json['coveredSeconds'];
    final completed = json['completed'];
    if (resume is! num ||
        resume.isNaN ||
        resume.isInfinite ||
        resume < 0 ||
        covered is! num ||
        covered.isNaN ||
        covered.isInfinite ||
        covered < 0 ||
        completed is! bool) {
      invalidCatalogResponse();
    }
    final rawUpdates = json['questUpdates'];
    final updates = rawUpdates == null
        ? const <QuestProgressUpdate>[]
        : catalogList(rawUpdates)
              .map((v) => QuestProgressUpdate.fromJson(catalogObject(v)))
              .toList();
    return PlaybackProgressResult(
      mediaId: catalogId(json['mediaId']),
      resumePositionSeconds: resume.toDouble(),
      coveredSeconds: covered.toDouble(),
      completed: completed,
      questUpdates: updates,
    );
  }
}

class PlaybackSkipResult {
  const PlaybackSkipResult({
    required this.playlistItemId,
    required this.skipCount,
    required this.suggestionVisible,
    required this.recorded,
  });

  final String? playlistItemId;
  final int skipCount;
  final bool suggestionVisible;
  final bool recorded;

  factory PlaybackSkipResult.fromJson(Map<String, dynamic> json) {
    final rawItem = json['playlistItemId'];
    final skipCount = json['skipCount'];
    final suggestionVisible = json['suggestionVisible'];
    final recorded = json['recorded'];
    if (skipCount is! int ||
        skipCount < 0 ||
        suggestionVisible is! bool ||
        recorded is! bool) {
      invalidCatalogResponse();
    }
    return PlaybackSkipResult(
      playlistItemId: rawItem == null ? null : catalogId(rawItem),
      skipCount: skipCount,
      suggestionVisible: suggestionVisible,
      recorded: recorded,
    );
  }
}
